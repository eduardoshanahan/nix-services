{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.fossflowCompose;
  serviceName = "fossflow";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
  digestRegex = "^sha256:[0-9a-f]{64}$";
  imageRef =
    if cfg.image.digest == null
    then "${cfg.image.repository}:${cfg.image.tag}"
    else "${cfg.image.repository}@${cfg.image.digest}";
  waitForHealthy = pkgs.writeShellScript "fossflow-wait-healthy" ''
    set -euo pipefail

    container_name=${cfg.containerName}
    timeout_seconds=120
    deadline=$((SECONDS + timeout_seconds))

    while true; do
      status="$(${dockerBin} inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_name" 2>/dev/null || true)"

      case "$status" in
        healthy)
          exit 0
          ;;
        unhealthy)
          echo "fossflow: container became unhealthy" >&2
          ${dockerBin} ps --filter "name=^/$container_name$" --format 'table {{.Names}}\t{{.Status}}' >&2 || true
          exit 1
          ;;
        starting|none|"")
          ;;
        *)
          echo "fossflow: unexpected health status: $status" >&2
          ;;
      esac

      if [ "$SECONDS" -ge "$deadline" ]; then
        echo "fossflow: timed out waiting for a healthy container (''${timeout_seconds}s)" >&2
        ${dockerBin} ps --filter "name=^/$container_name$" --format 'table {{.Names}}\t{{.Status}}' >&2 || true
        exit 1
      fi

      sleep 2
    done
  '';
in {
  options.services.fossflowCompose = {
    enable = lib.mkEnableOption "FossFLOW service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "fossflow";
      description = "Docker container name.";
    };

    hostname = lib.mkOption {
      type = lib.types.str;
      description = "Hostname used for the Traefik router `Host()` rule.";
    };

    timezone = lib.mkOption {
      type = lib.types.str;
      default = "UTC";
      description = "Timezone passed to the container via `TZ`.";
    };

    network = lib.mkOption {
      type = lib.types.str;
      default = "traefik";
      description = "External Docker network name used by Traefik and downstream services.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/fossflow";
      description = "Persistent host path used for FossFLOW diagrams.";
    };

    storagePath = lib.mkOption {
      type = lib.types.str;
      default = "/data/diagrams";
      description = "Path used inside the container for persisted diagrams.";
    };

    enableServerStorage = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable FossFLOW backend diagram storage.";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "stnsmith/fossflow";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "latest";
        description = "Container image tag.";
      };

      digest = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "sha256:a344fb844e931d65a74f8d00ded7c869f3070e346b288d4b8fe0437188468027";
        description = ''
          Optional immutable digest pin (for example `sha256:...`). When set,
          the module uses `repository@digest` form and
          ignores `services.fossflowCompose.image.tag`.
        '';
      };

      allowMutableTag = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Allow mutable tags such as `latest` when using tag mode.
          Keep disabled to enforce pinned tags by default.
        '';
      };
    };

    tls = lib.mkEnableOption "TLS on the FossFLOW Traefik router";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.fossflowCompose.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.fossflowCompose.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.fossflowCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.fossflowCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.digest == null || builtins.match digestRegex cfg.image.digest != null;
        message = "services.fossflowCompose.image.digest must match `sha256:<64 lowercase hex characters>` when set.";
      }
      {
        assertion = cfg.image.digest != null || cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.fossflowCompose.image.tag must be pinned (not `latest`) unless services.fossflowCompose.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.fossflowCompose.dataDir must be an absolute path.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.storagePath;
        message = "services.fossflowCompose.storagePath must be an absolute path.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "FossFLOW (Docker Compose)";
      wantedBy = [ "multi-user.target" ];
      requires = [ "docker.service" ];
      after = [ "docker.service" "network-online.target" ];
      wants = [ "network-online.target" ];
      restartTriggers = [
        config.environment.etc."${serviceName}/docker-compose.yml".source
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = composeDir;
        TimeoutStartSec = 180;
        Restart = "on-failure";
        RestartSec = 10;

        Environment = [
          "FOSSFLOW_CONTAINER_NAME=${cfg.containerName}"
          "FOSSFLOW_IMAGE=${imageRef}"
          "FOSSFLOW_NETWORK=${cfg.network}"
          "FOSSFLOW_HOSTNAME=${cfg.hostname}"
          "FOSSFLOW_ENTRYPOINTS=${if cfg.tls then "websecure" else "web"}"
          "FOSSFLOW_TLS=${if cfg.tls then "true" else "false"}"
          "FOSSFLOW_DATA_DIR=${cfg.dataDir}"
          "FOSSFLOW_STORAGE_PATH=${cfg.storagePath}"
          "FOSSFLOW_ENABLE_SERVER_STORAGE=${if cfg.enableServerStorage then "true" else "false"}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${lib.escapeShellArg cfg.dataDir}'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"fossflow: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStartPost = waitForHealthy;
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
