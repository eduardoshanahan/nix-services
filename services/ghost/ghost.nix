{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.ghost;
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};
  runtimeSecretEnv = import ../../lib/runtime-secret-env.nix {inherit lib pkgs;};
  serviceName = "ghost";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
  waitForHealthy = pkgs.writeShellScript "ghost-wait-healthy" ''
    set -euo pipefail

    container_name=${cfg.containerName}
    timeout_seconds=180
    deadline=$((SECONDS + timeout_seconds))

    while true; do
      status="$(${dockerBin} inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_name" 2>/dev/null || true)"

      case "$status" in
        healthy)
          exit 0
          ;;
        unhealthy)
          echo "ghost: container became unhealthy" >&2
          ${dockerBin} ps --filter "name=^/$container_name$" --format 'table {{.Names}}\t{{.Status}}' >&2 || true
          exit 1
          ;;
        starting|none|"")
          ;;
        *)
          echo "ghost: unexpected health status: $status" >&2
          ;;
      esac

      if [ "$SECONDS" -ge "$deadline" ]; then
        echo "ghost: timed out waiting for a healthy container (''${timeout_seconds}s)" >&2
        ${dockerBin} ps --filter "name=^/$container_name$" --format 'table {{.Names}}\t{{.Status}}' >&2 || true
        exit 1
      fi

      sleep 2
    done
  '';
in {
  options.services.ghost = {
    enable = lib.mkEnableOption "Ghost blog service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "ghost";
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
      default = "/var/lib/ghost";
      description = "Persistent host path used for Ghost content.";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "ghost";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "6.19.2";
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

    database = {
      host = lib.mkOption {
        type = lib.types.str;
        description = "MySQL hostname or IP reachable from the Ghost host.";
        example = "hhnas4";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 3306;
        description = "MySQL TCP port.";
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "ghost";
        description = "MySQL database name for Ghost.";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "ghost";
        description = "MySQL username for Ghost.";
      };

      passwordFile = runtimeSecrets.mkSecretFileOption {
        description = ''
          Absolute path to a runtime-provisioned file containing the MySQL password
          for the Ghost database user.
        '';
        example = "/run/secrets/ghost-db-password";
      };
    };

    tls = lib.mkEnableOption "TLS on the Ghost Traefik router";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.ghost.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.ghost.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.ghost.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.ghost.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.ghost.image.tag must be pinned (not `latest`) unless services.ghost.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.ghost.dataDir must be an absolute path.";
      }
      {
        assertion = cfg.database.host != "";
        message = "services.ghost.database.host must be set when enabling Ghost.";
      }
      {
        assertion = cfg.database.passwordFile != null;
        message = "services.ghost.database.passwordFile must be set when enabling Ghost.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "Ghost blog (Docker Compose)";

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
        TimeoutStartSec = 240;
        Restart = "on-failure";
        RestartSec = 10;
        WorkingDirectory = composeDir;

        Environment = [
          "GHOST_CONTAINER_NAME=${cfg.containerName}"
          "GHOST_IMAGE_REPOSITORY=${cfg.image.repository}"
          "GHOST_IMAGE_TAG=${cfg.image.tag}"
          "GHOST_NETWORK=${cfg.network}"
          "GHOST_HOSTNAME=${cfg.hostname}"
          "GHOST_ENTRYPOINTS=${if cfg.tls then "websecure" else "web"}"
          "GHOST_TLS=${if cfg.tls then "true" else "false"}"
          "GHOST_URL=${if cfg.tls then "https" else "http"}://${cfg.hostname}"
          "GHOST_DATA_DIR=${cfg.dataDir}"
          "GHOST_DATABASE_HOST=${cfg.database.host}"
          "GHOST_DATABASE_PORT=${toString cfg.database.port}"
          "GHOST_DATABASE_NAME=${cfg.database.name}"
          "GHOST_DATABASE_USER=${cfg.database.user}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${cfg.dataDir} && chown 1000:1000 ${cfg.dataDir} && chmod 0750 ${cfg.dataDir}'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"ghost: docker daemon is not ready\" >&2; exit 1'"
          (runtimeSecretEnv.mkRuntimeSecretEnvExecStartPre {
            name = serviceName;
            secretFile = cfg.database.passwordFile;
            envVar = "GHOST_DATABASE_PASSWORD";
          })
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
