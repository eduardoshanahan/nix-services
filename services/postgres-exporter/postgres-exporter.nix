{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.postgresExporterCompose;
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};
  runtimeSecretEnv = import ../../lib/runtime-secret-env.nix {inherit lib pkgs;};
  serviceName = "postgres-exporter";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
in {
  options.services.postgresExporterCompose = {
    enable = lib.mkEnableOption "PostgreSQL Prometheus exporter (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "postgres-exporter";
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
      default = 9187;
      description = "Host TCP port mapped to exporter port 9187.";
    };

    dataSourceNameFile = runtimeSecrets.mkSecretFileOption {
      description = ''
        Absolute path to a runtime-provisioned file containing the PostgreSQL
        DSN used by postgres-exporter (for example
        `postgresql://user:pass@postgres.internal.example:5433/db?sslmode=disable`).
      '';
      example = "/run/secrets/postgres-exporter-dsn";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "quay.io/prometheuscommunity/postgres-exporter";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "v0.16.0";
        description = "Container image tag.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.dataSourceNameFile != null;
        message = "services.postgresExporterCompose.dataSourceNameFile must be set when enabling postgres exporter.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "PostgreSQL Prometheus exporter (Docker Compose)";

      wantedBy = ["multi-user.target"];
      after = ["docker.service" "network-online.target"];
      wants = ["network-online.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = composeDir;

        Environment = [
          "POSTGRES_EXPORTER_CONTAINER_NAME=${cfg.containerName}"
          "POSTGRES_EXPORTER_NETWORK=${cfg.network}"
          "POSTGRES_EXPORTER_PORT=${toString cfg.listenPort}"
          "POSTGRES_EXPORTER_IMAGE_REPOSITORY=${cfg.image.repository}"
          "POSTGRES_EXPORTER_IMAGE_TAG=${cfg.image.tag}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
          (runtimeSecretEnv.mkRuntimeSecretEnvExecStartPre {
            name = serviceName;
            secretFile = cfg.dataSourceNameFile;
            envVar = "DATA_SOURCE_NAME";
          })
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
