{lib, ...}: let
  portType = lib.types.ints.between 1 65535;
in {
  options.services.lokiCompose = {
    enable = lib.mkEnableOption "Loki log aggregation service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "loki";
      description = "Docker container name.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/loki";
      description = "Persistent host path used for Loki data.";
    };

    httpPort = lib.mkOption {
      type = portType;
      default = 3100;
      description = "Host TCP port published for Loki HTTP API.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = ''
        Host IP address used for the published Loki port binding.
        Set this to a LAN IP (for example `10.0.0.10`) to avoid broad exposure.
      '';
    };

    retentionPeriod = lib.mkOption {
      type = lib.types.str;
      default = "30d";
      description = "Loki retention period.";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "grafana/loki";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "3.1.1";
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

    backup = {
      enable = lib.mkEnableOption "periodic Loki data backups";

      targetDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/backups/loki";
        description = "Directory where compressed Loki backup archives are written.";
      };

      schedule = lib.mkOption {
        type = lib.types.str;
        default = "daily";
        description = "Systemd OnCalendar expression for Loki backups.";
      };

      keepDays = lib.mkOption {
        type = lib.types.ints.positive;
        default = 14;
        description = "How many days of backup archives to keep.";
      };
    };
  };
}
