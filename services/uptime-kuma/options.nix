{lib, ...}: {
  options.services.uptimeKuma = {
    enable = lib.mkEnableOption "Uptime Kuma service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "uptime-kuma";
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
      default = "/var/lib/uptime-kuma";
      description = "Persistent host path used for Uptime Kuma data.";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "louislam/uptime-kuma";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "2.2.1";
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

    tls = lib.mkEnableOption "TLS on the Uptime Kuma Traefik router";

    database = {
      type = lib.mkOption {
        type = lib.types.enum [ "sqlite" "mariadb" ];
        default = "sqlite";
        description = "Uptime Kuma database backend.";
      };

      mariadb = {
        host = lib.mkOption {
          type = lib.types.str;
          default = "db.internal.example";
          description = "MariaDB/MySQL host when `database.type = \"mariadb\"`.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 3306;
          description = "MariaDB/MySQL port when `database.type = \"mariadb\"`.";
        };

        name = lib.mkOption {
          type = lib.types.str;
          default = "uptime_kuma";
          description = "MariaDB/MySQL database name when `database.type = \"mariadb\"`.";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = "uptime_kuma";
          description = "MariaDB/MySQL username when `database.type = \"mariadb\"`.";
        };

        passwordFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "File containing the MariaDB/MySQL password on one line.";
        };
      };
    };
  };
}
