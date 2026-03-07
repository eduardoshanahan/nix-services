{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.redisExporterCompose;
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};
  runtimeSecretEnv = import ../../lib/runtime-secret-env.nix {inherit lib pkgs;};
  serviceName = "redis-exporter";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
in {
  options.services.redisExporterCompose = {
    enable = lib.mkEnableOption "Redis Prometheus exporter (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "redis-exporter";
      description = "Docker container name.";
    };

    network = lib.mkOption {
      type = lib.types.str;
      default = "traefik";
      description = "External Docker network name used by Traefik and downstream services.";
    };

    timezone = lib.mkOption {
      type = lib.types.str;
      default = "UTC";
      description = "Timezone passed to the container via `TZ`.";
    };

    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 9121;
      description = "Host TCP port mapped to exporter port 9121.";
    };

    redis = {
      username = lib.mkOption {
        type = lib.types.str;
        default = "default";
        description = "Redis ACL username used by exporter.";
        example = "redis-admin";
      };

      host = lib.mkOption {
        type = lib.types.str;
        description = "Redis hostname reachable from exporter container.";
        example = "redis.internal.example";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 6379;
        description = "Redis TCP port.";
      };

      passwordFile = runtimeSecrets.mkSecretFileOption {
        description = "Absolute path to a runtime-provisioned file containing the Redis password.";
        example = "/run/secrets/redis-password";
      };
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "oliver006/redis_exporter";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "v1.66.0";
        description = "Container image tag.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.redis.passwordFile != null;
        message = "services.redisExporterCompose.redis.passwordFile must be set when enabling redis exporter.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "Redis Prometheus exporter (Docker Compose)";

      wantedBy = ["multi-user.target"];
      after = ["docker.service" "network-online.target"];
      wants = ["network-online.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = composeDir;

        Environment = [
          "REDIS_EXPORTER_CONTAINER_NAME=${cfg.containerName}"
          "REDIS_EXPORTER_NETWORK=${cfg.network}"
          "REDIS_EXPORTER_PORT=${toString cfg.listenPort}"
          "REDIS_EXPORTER_REDIS_ADDR=${cfg.redis.host}:${toString cfg.redis.port}"
          "REDIS_USER=${cfg.redis.username}"
          "REDIS_EXPORTER_IMAGE_REPOSITORY=${cfg.image.repository}"
          "REDIS_EXPORTER_IMAGE_TAG=${cfg.image.tag}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
          (runtimeSecretEnv.mkRuntimeSecretEnvExecStartPre {
            name = serviceName;
            secretFile = cfg.redis.passwordFile;
            envVar = "REDIS_PASSWORD";
          })
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
