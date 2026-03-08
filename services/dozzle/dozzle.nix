{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.dozzleCompose;
  serviceName = "dozzle";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
in {
  options.services.dozzleCompose = {
    enable = lib.mkEnableOption "Dozzle service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "dozzle";
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
      default = "/var/lib/dozzle";
      description = "Persistent host path used for Dozzle data.";
    };

    socketPath = lib.mkOption {
      type = lib.types.str;
      default = "/var/run/docker.sock";
      description = "Host Docker socket path bind-mounted read-only.";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "amir20/dozzle";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "latest";
        description = "Container image tag.";
      };

      allowMutableTag = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Allow mutable tags such as `latest`.";
      };
    };

    tls = lib.mkEnableOption "TLS on the Dozzle Traefik router";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.dozzleCompose.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.dozzleCompose.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.dozzleCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.dozzleCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.dozzleCompose.image.tag must be pinned (not `latest`) unless services.dozzleCompose.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.dozzleCompose.dataDir must be an absolute path.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.socketPath;
        message = "services.dozzleCompose.socketPath must be an absolute path.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "Dozzle (Docker Compose)";
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
          "DOZZLE_CONTAINER_NAME=${cfg.containerName}"
          "DOZZLE_IMAGE_REPOSITORY=${cfg.image.repository}"
          "DOZZLE_IMAGE_TAG=${cfg.image.tag}"
          "DOZZLE_NETWORK=${cfg.network}"
          "DOZZLE_HOSTNAME=${cfg.hostname}"
          "DOZZLE_ENTRYPOINTS=${if cfg.tls then "websecure" else "web"}"
          "DOZZLE_TLS=${if cfg.tls then "true" else "false"}"
          "DOZZLE_DATA_DIR=${cfg.dataDir}"
          "DOZZLE_SOCKET_PATH=${cfg.socketPath}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${lib.escapeShellArg cfg.dataDir}'"
          "${pkgs.runtimeShell} -c 'test -S ${cfg.socketPath}'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"dozzle: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
