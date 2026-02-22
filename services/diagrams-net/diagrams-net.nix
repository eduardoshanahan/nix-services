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
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
  envKeyRegex = "^[A-Za-z_][A-Za-z0-9_]*$";
  labelKeyRegex = "^[A-Za-z0-9][A-Za-z0-9._/-]*$";
  cpuRegex = "^[0-9]+(\\.[0-9]+)?$";
  positiveMemoryRegex = "^[1-9][0-9]*([kKmMgG])?$";
  reservedLabelKeys = [
    "traefik.enable"
    "traefik.docker.network"
    "traefik.http.routers.diagrams-net.rule"
    "traefik.http.services.diagrams-net.loadbalancer.server.port"
    "traefik.http.routers.diagrams-net.entrypoints"
    "traefik.http.routers.diagrams-net.tls"
  ];
  escapeYaml = s:
    lib.replaceStrings ["\\" "\""] ["\\\\" "\\\""] s;
  baseEnv = {
    TZ = cfg.timezone;
  };
  envLines = lib.concatMapStrings (name: let
    value = cfg.extraEnv.${name};
  in
    "          - \"${escapeYaml name}=${escapeYaml value}\"\n") (lib.attrNames cfg.extraEnv);
  labels = {
      "traefik.enable" = "true";
      "traefik.docker.network" = cfg.network;
      "traefik.http.routers.diagrams-net.rule" = "Host(`${cfg.hostname}`)";
      "traefik.http.services.diagrams-net.loadbalancer.server.port" = "8080";
      "traefik.http.routers.diagrams-net.entrypoints" = if cfg.tls then "websecure" else "web";
      "traefik.http.routers.diagrams-net.tls" = if cfg.tls then "true" else "false";
    }
    // cfg.extraLabels;
  labelLines = lib.concatMapStrings (name: let
    value = labels.${name};
  in
    "          - \"${escapeYaml name}=${escapeYaml value}\"\n") (lib.attrNames labels);
  volumeSection = lib.optionalString cfg.persistence.enable ''
        volumes:
          - "${cfg.persistence.hostPath}:${cfg.persistence.containerPath}:rw"
  '';
  composeText = ''
    services:
      diagrams-net:
        image: ${cfg.image.repository}:${cfg.image.tag}
        container_name: ${cfg.containerName}
        restart: unless-stopped
        user: ${if cfg.nonRoot then "${toString cfg.uid}:${toString cfg.gid}" else "0:0"}
        read_only: ${if cfg.readOnlyRootFilesystem then "true" else "false"}
        security_opt:
          - "no-new-privileges:${if cfg.noNewPrivileges then "true" else "false"}"
        cap_drop:
          - ALL
        tmpfs:
          - /tmp:rw,noexec,nosuid,size=64m
        mem_limit: ${cfg.memoryLimit}
        pids_limit: ${toString cfg.pidsLimit}
        cpus: "${cfg.cpus}"
        expose:
          - "8080"

        environment:
          - "TZ=${baseEnv.TZ}"
${envLines}

        healthcheck:
          test: ["CMD-SHELL", "wget --spider -q http://127.0.0.1:8080/ || exit 1"]
          interval: 15s
          timeout: 5s
          retries: 8
          start_period: 20s

        labels:
${labelLines}

${volumeSection}

        networks:
          - traefik

    networks:
      traefik:
        external: true
        name: ${cfg.network}
  '';
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

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "jgraph/drawio";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "29.0.3";
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

    extraEnv = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      example = {
        DRAWIO_BASE_URL = "https://diagramsnet.example.com";
      };
      description = "Additional container environment variables appended to the Compose `environment` list.";
    };

    extraLabels = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      example = {
        "traefik.http.routers.diagrams-net.middlewares" = "default-headers@file";
      };
      description = "Additional Docker labels merged on top of the default Traefik labels.";
    };

    persistence = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Persist diagrams.net data to a host path. Disabled by default to keep
          the service stateless.
        '';
      };

      hostPath = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/diagrams-net";
        description = "Absolute host path mounted into the container when persistence is enabled.";
      };

      containerPath = lib.mkOption {
        type = lib.types.str;
        default = "/data";
        description = "Container path used as the persistence mountpoint.";
      };
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
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.diagramsNet.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.diagramsNet.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = !cfg.enforceTraefikNetwork || cfg.network == "traefik";
        message = "services.diagramsNet.network must be `traefik` when services.diagramsNet.enforceTraefikNetwork = true.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.diagramsNet.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.diagramsNet.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.diagramsNet.image.tag must be pinned (not `latest`) unless services.diagramsNet.image.allowMutableTag = true.";
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
      {
        assertion = builtins.match cpuRegex cfg.cpus != null;
        message = "services.diagramsNet.cpus must be numeric (for example `0.50` or `1.0`).";
      }
      {
        assertion = builtins.match positiveMemoryRegex cfg.memoryLimit != null;
        message = "services.diagramsNet.memoryLimit must use Docker format like `512m`, `1g`, or bytes.";
      }
      {
        assertion = !cfg.persistence.enable || lib.hasPrefix "/" cfg.persistence.hostPath;
        message = "services.diagramsNet.persistence.hostPath must be absolute when persistence is enabled.";
      }
      {
        assertion = !cfg.persistence.enable || lib.hasPrefix "/" cfg.persistence.containerPath;
        message = "services.diagramsNet.persistence.containerPath must be absolute when persistence is enabled.";
      }
      {
        assertion = lib.all (name: builtins.match envKeyRegex name != null) (lib.attrNames cfg.extraEnv);
        message = "services.diagramsNet.extraEnv keys must match `[A-Za-z_][A-Za-z0-9_]*`.";
      }
      {
        assertion = lib.all (name: builtins.match labelKeyRegex name != null) (lib.attrNames cfg.extraLabels);
        message = "services.diagramsNet.extraLabels keys must match `[A-Za-z0-9][A-Za-z0-9._/-]*`.";
      }
      {
        assertion = lib.all (name: !(lib.elem name reservedLabelKeys)) (lib.attrNames cfg.extraLabels);
        message = "services.diagramsNet.extraLabels cannot override reserved Traefik routing labels.";
      }
    ];

    virtualisation.docker.enable = true;

    systemd.tmpfiles.rules =
      lib.optionals cfg.persistence.enable [
        "d ${cfg.persistence.hostPath} 0750 ${if cfg.nonRoot then toString cfg.uid else "root"} ${if cfg.nonRoot then toString cfg.gid else "root"} -"
      ];

    environment.etc."${serviceName}/docker-compose.yml".text = composeText;

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

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"diagrams-net: docker daemon is not ready\" >&2; exit 1'"
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
