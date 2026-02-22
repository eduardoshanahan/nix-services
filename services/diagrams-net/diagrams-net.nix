{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.diagramsNet;
  serviceName = "diagrams-net";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  waitForHealthy = pkgs.writeShellScript "diagrams-net-wait-healthy" ''
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
          echo "diagrams-net: container became unhealthy" >&2
          ${dockerBin} ps --filter "name=^/$container_name$" --format 'table {{.Names}}\t{{.Status}}' >&2 || true
          exit 1
          ;;
        starting|none|"")
          ;;
        *)
          echo "diagrams-net: unexpected health status: $status" >&2
          ;;
      esac

      if [ "$SECONDS" -ge "$deadline" ]; then
        echo "diagrams-net: timed out waiting for a healthy container (''${timeout_seconds}s)" >&2
        ${dockerBin} ps --filter "name=^/$container_name$" --format 'table {{.Names}}\t{{.Status}}' >&2 || true
        exit 1
      fi

      sleep 2
    done
  '';
in {
  options.services.diagramsNet = {
    enable = lib.mkEnableOption "diagrams.net service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "diagrams-net";
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

    enforceTraefikNetwork = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Require `services.diagramsNet.network` to stay on `traefik`.";
    };

    nonRoot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run container as non-root UID/GID when true.";
    };

    uid = lib.mkOption {
      type = lib.types.int;
      default = 1000;
      description = "Container runtime UID used when `services.diagramsNet.nonRoot = true`.";
    };

    gid = lib.mkOption {
      type = lib.types.int;
      default = 1000;
      description = "Container runtime GID used when `services.diagramsNet.nonRoot = true`.";
    };

    readOnlyRootFilesystem = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Mount container root filesystem as read-only.";
    };

    noNewPrivileges = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Set Docker security option `no-new-privileges`.";
    };

    memoryLimit = lib.mkOption {
      type = lib.types.str;
      default = "512m";
      description = "Container memory limit passed to Docker Compose.";
    };

    pidsLimit = lib.mkOption {
      type = lib.types.int;
      default = 256;
      description = "Container PID limit passed to Docker Compose.";
    };

    cpus = lib.mkOption {
      type = lib.types.str;
      default = "1.0";
      description = "Container CPU limit passed to Docker Compose.";
    };

    tls = lib.mkEnableOption "TLS on the diagrams.net Traefik router";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.enforceTraefikNetwork || cfg.network == "traefik";
        message = "services.diagramsNet.network must be `traefik` when services.diagramsNet.enforceTraefikNetwork = true.";
      }
      {
        assertion = !cfg.nonRoot || cfg.uid > 0;
        message = "services.diagramsNet.uid must be > 0 when services.diagramsNet.nonRoot = true.";
      }
      {
        assertion = !cfg.nonRoot || cfg.gid > 0;
        message = "services.diagramsNet.gid must be > 0 when services.diagramsNet.nonRoot = true.";
      }
      {
        assertion = cfg.pidsLimit > 0;
        message = "services.diagramsNet.pidsLimit must be > 0.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "diagrams.net (Docker Compose)";

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
        TimeoutStartSec = 180;
        Restart = "on-failure";
        RestartSec = 10;
        WorkingDirectory = composeDir;

        Environment = [
          "DIAGRAMS_NET_CONTAINER_NAME=${cfg.containerName}"
          "DIAGRAMS_NET_HOSTNAME=${cfg.hostname}"
          "DIAGRAMS_NET_NETWORK=${cfg.network}"
          "DIAGRAMS_NET_ENTRYPOINTS=${if cfg.tls then "websecure" else "web"}"
          "DIAGRAMS_NET_TLS=${if cfg.tls then "true" else "false"}"
          "DIAGRAMS_NET_USER=${if cfg.nonRoot then "${toString cfg.uid}:${toString cfg.gid}" else "0:0"}"
          "DIAGRAMS_NET_READ_ONLY=${if cfg.readOnlyRootFilesystem then "true" else "false"}"
          "DIAGRAMS_NET_NO_NEW_PRIVILEGES=${if cfg.noNewPrivileges then "true" else "false"}"
          "DIAGRAMS_NET_MEMORY_LIMIT=${cfg.memoryLimit}"
          "DIAGRAMS_NET_PIDS_LIMIT=${toString cfg.pidsLimit}"
          "DIAGRAMS_NET_CPUS=${cfg.cpus}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"diagrams-net: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStartPost = waitForHealthy;
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
