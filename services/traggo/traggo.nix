{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.traggoCompose;
  runtimeSecretEnv = import ../../lib/runtime-secret-env.nix {inherit lib pkgs;};
  serviceName = "traggo";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
in {
  options.services.traggoCompose = {
    enable = lib.mkEnableOption "Traggo service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "traggo";
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
      default = "/var/lib/traggo";
      description = "Persistent host path used for Traggo data.";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "traggo/server";
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

    tls = lib.mkEnableOption "TLS on the Traggo Traefik router";

    admin = {
      username = lib.mkOption {
        type = lib.types.str;
        default = "admin";
        description = "Initial admin username for Traggo bootstrap.";
      };

      passwordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to a single-line file with the initial admin password.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.traggoCompose.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.traggoCompose.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.traggoCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.traggoCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.traggoCompose.image.tag must be pinned (not `latest`) unless services.traggoCompose.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.traggoCompose.dataDir must be an absolute path.";
      }
      {
        assertion = cfg.admin.passwordFile != null;
        message = "services.traggoCompose.admin.passwordFile must be set.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "Traggo (Docker Compose)";
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
          "TRAGGO_CONTAINER_NAME=${cfg.containerName}"
          "TRAGGO_IMAGE_REPOSITORY=${cfg.image.repository}"
          "TRAGGO_IMAGE_TAG=${cfg.image.tag}"
          "TRAGGO_NETWORK=${cfg.network}"
          "TRAGGO_HOSTNAME=${cfg.hostname}"
          "TRAGGO_ENTRYPOINTS=${if cfg.tls then "websecure" else "web"}"
          "TRAGGO_TLS=${if cfg.tls then "true" else "false"}"
          "TRAGGO_DATA_DIR=${cfg.dataDir}"
          "TRAGGO_DEFAULT_USER_NAME=${cfg.admin.username}"
          "TRAGGO_ADMIN_ENV_FILE=/run/secrets/${serviceName}.env"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${lib.escapeShellArg cfg.dataDir}'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          (runtimeSecretEnv.mkRuntimeSecretEnvExecStartPre {
            name = serviceName;
            secretFile = cfg.admin.passwordFile;
            envVar = "TRAGGO_DEFAULT_USER_PASS";
          })
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"traggo: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
