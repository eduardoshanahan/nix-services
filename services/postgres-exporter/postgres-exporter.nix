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
  commandArgs =
    [
      "--disable-default-metrics"
      "--disable-settings-metrics"
      "--collector.stat_database"
      "--collector.stat_database_conflicts"
      "--collector.stat_user_tables"
      "--collector.stat_activity"
      "--collector.replication_slot"
      "--collector.database_wraparound"
      "--collector.long_running_transactions"
      "--collector.process_idle"
      "--collector.postmaster"
      "--collector.locks"
      "--collector.xlog_location"
      "--collector.stat_statements"
      "--collector.replication"
      "--collector.archive"
      "--collector.bgwriter"
      "--collector.stat_wal_receiver"
      "--collector.statio_user_tables"
    ]
    ++ lib.optional cfg.collectors.wal.enable "--collector.wal"
    ++ lib.optional cfg.collectors.statBgwriter.enable "--collector.stat_bgwriter";
  composeText =
    let
      commandBlock =
        lib.concatStringsSep "\n" (map (arg: "      - ${arg}") commandArgs);
    in ''
      services:
        postgres-exporter:
          image: ''${POSTGRES_EXPORTER_IMAGE_REPOSITORY}:''${POSTGRES_EXPORTER_IMAGE_TAG}
          container_name: ''${POSTGRES_EXPORTER_CONTAINER_NAME}
          restart: unless-stopped

          environment:
            - TZ

          env_file:
            - /run/secrets/postgres-exporter.env

          command:
${commandBlock}

          ports:
            - "''${POSTGRES_EXPORTER_PORT}:9187"

          logging:
            driver: "json-file"
            options:
              max-size: "10m"
              max-file: "5"

          networks:
            - traefik

      networks:
        traefik:
          external: true
          name: ''${POSTGRES_EXPORTER_NETWORK}
    '';
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

    collectors = {
      wal.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the `wal` collector.";
      };

      statBgwriter.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the `stat_bgwriter` collector.";
      };
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

    environment.etc."${serviceName}/docker-compose.yml".text = composeText;

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
