{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.mysqlExporterCompose;
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};
  runtimeSecretEnv = import ../../lib/runtime-secret-env.nix {inherit lib pkgs;};
  serviceName = "mysql-exporter";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
in {
  options.services.mysqlExporterCompose = {
    enable = lib.mkEnableOption "MySQL Prometheus exporter (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "mysql-exporter";
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
      default = 9104;
      description = "Host TCP port mapped to exporter port 9104.";
    };

    dataSourceNameFile = runtimeSecrets.mkSecretFileOption {
      description = ''
        Absolute path to a runtime-provisioned file containing the MySQL DSN
        used by mysqld-exporter (for example
        `user:pass@(mysql.internal.example:3306)/`).
      '';
      example = "/run/secrets/mysql-exporter-dsn";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "prom/mysqld-exporter";
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
        message = "services.mysqlExporterCompose.dataSourceNameFile must be set when enabling mysql exporter.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "MySQL Prometheus exporter (Docker Compose)";

      wantedBy = ["multi-user.target"];
      after = ["docker.service" "network-online.target"];
      wants = ["network-online.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = composeDir;

        Environment = [
          "MYSQL_EXPORTER_CONTAINER_NAME=${cfg.containerName}"
          "MYSQL_EXPORTER_NETWORK=${cfg.network}"
          "MYSQL_EXPORTER_PORT=${toString cfg.listenPort}"
          "MYSQL_EXPORTER_IMAGE_REPOSITORY=${cfg.image.repository}"
          "MYSQL_EXPORTER_IMAGE_TAG=${cfg.image.tag}"
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
