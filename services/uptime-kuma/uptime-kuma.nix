{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.uptimeKuma;
  serviceName = "uptime-kuma";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";

  waitForHealthy = pkgs.writeShellScript "uptime-kuma-wait-healthy" ''
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
          echo "uptime-kuma: container became unhealthy" >&2
          ${dockerBin} ps --filter "name=^/$container_name$" --format 'table {{.Names}}\t{{.Status}}' >&2 || true
          exit 1
          ;;
        starting|none|"")
          ;;
        *)
          echo "uptime-kuma: unexpected health status: $status" >&2
          ;;
      esac

      if [ "$SECONDS" -ge "$deadline" ]; then
        echo "uptime-kuma: timed out waiting for a healthy container (''${timeout_seconds}s)" >&2
        ${dockerBin} ps --filter "name=^/$container_name$" --format 'table {{.Names}}\t{{.Status}}' >&2 || true
        exit 1
      fi

      sleep 2
    done
  '';
in {
  options.services.uptimeKuma = {
    enable = lib.mkEnableOption "Uptime Kuma service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "uptime-kuma";
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
      default = "/var/lib/uptime-kuma";
      description = "Persistent host path used for Uptime Kuma data.";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "louislam/uptime-kuma";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "2.1.3";
        description = "Container image tag.";
      };

      allowMutableTag = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Allow mutable tags such as `latest`. Keep disabled to enforce pinned
          image tags by default.
        '';
      };
    };

    tls = lib.mkEnableOption "TLS on the Uptime Kuma Traefik router";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.uptimeKuma.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.uptimeKuma.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.uptimeKuma.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.uptimeKuma.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.uptimeKuma.image.tag must be pinned (not `latest`) unless services.uptimeKuma.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.uptimeKuma.dataDir must be an absolute path.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "Uptime Kuma (Docker Compose)";

      wantedBy = ["multi-user.target"];
      requires = ["docker.service"];
      after = ["docker.service" "network-online.target"];
      wants = ["network-online.target"];
      restartTriggers = [
        config.environment.etc."${serviceName}/docker-compose.yml".source
      ];
      startLimitBurst = 3;
      startLimitIntervalSec = 300;

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = 600;
        Restart = "on-failure";
        RestartSec = 10;
        WorkingDirectory = composeDir;

        Environment = [
          "UPTIME_KUMA_CONTAINER_NAME=${cfg.containerName}"
          "UPTIME_KUMA_IMAGE_REPOSITORY=${cfg.image.repository}"
          "UPTIME_KUMA_IMAGE_TAG=${cfg.image.tag}"
          "UPTIME_KUMA_NETWORK=${cfg.network}"
          "UPTIME_KUMA_HOSTNAME=${cfg.hostname}"
          "UPTIME_KUMA_ENTRYPOINTS=${if cfg.tls then "websecure" else "web"}"
          "UPTIME_KUMA_TLS=${if cfg.tls then "true" else "false"}"
          "UPTIME_KUMA_DATA_DIR=${cfg.dataDir}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${cfg.dataDir} && chown 1000:1000 ${cfg.dataDir} && chmod 0750 ${cfg.dataDir}'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"uptime-kuma: docker daemon is not ready\" >&2; exit 1'"
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
