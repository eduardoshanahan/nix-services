{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.mongodbExporterCompose;
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};
  runtimeSecretEnv = import ../../lib/runtime-secret-env.nix {inherit lib pkgs;};
  serviceName = "mongodb-exporter";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
in {
  options.services.mongodbExporterCompose = {
    enable = lib.mkEnableOption "MongoDB Prometheus exporter (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "mongodb-exporter";
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
      default = 9216;
      description = "Host TCP port mapped to exporter port 9216.";
    };

    mongoUriFile = runtimeSecrets.mkSecretFileOption {
      description = ''
        Absolute path to a runtime-provisioned file containing the MongoDB URI
        used by mongodb-exporter, for example
        `mongodb://user:pass@mongo.internal.example:27017/admin?authSource=admin`.
      '';
      example = "/run/secrets/mongodb-exporter-uri";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "percona/mongodb_exporter";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "0.43.1";
        description = "Container image tag.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.mongoUriFile != null;
        message = "services.mongodbExporterCompose.mongoUriFile must be set when enabling mongodb exporter.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "MongoDB Prometheus exporter (Docker Compose)";

      wantedBy = ["multi-user.target"];
      after = ["docker.service" "network-online.target"];
      wants = ["network-online.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = composeDir;

        Environment = [
          "MONGODB_EXPORTER_CONTAINER_NAME=${cfg.containerName}"
          "MONGODB_EXPORTER_NETWORK=${cfg.network}"
          "MONGODB_EXPORTER_PORT=${toString cfg.listenPort}"
          "MONGODB_EXPORTER_IMAGE_REPOSITORY=${cfg.image.repository}"
          "MONGODB_EXPORTER_IMAGE_TAG=${cfg.image.tag}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
          (runtimeSecretEnv.mkRuntimeSecretEnvExecStartPre {
            name = serviceName;
            secretFile = cfg.mongoUriFile;
            envVar = "MONGODB_URI";
          })
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
