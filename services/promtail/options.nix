{lib, ...}: let
  portType = lib.types.ints.between 1 65535;
in {
  options.services.promtailCompose = {
    enable = lib.mkEnableOption "Promtail log shipper (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "promtail";
      description = "Docker container name.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/promtail";
      description = "Persistent host path used for Promtail positions data.";
    };

    lokiPushUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Loki push endpoint URL (`/loki/api/v1/push`).";
      example = "http://loki.internal.example:3100/loki/api/v1/push";
    };

    httpPort = lib.mkOption {
      type = portType;
      default = 9080;
      description = "Promtail local HTTP listen port (health/metrics).";
    };

    journalMaxAge = lib.mkOption {
      type = lib.types.str;
      default = "12h";
      description = "Maximum age for journald entries scraped by Promtail.";
    };

    syslog = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable a Promtail syslog receiver for external log senders (for example DSM).";
      };

      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0:1514";
        example = "0.0.0.0:1514";
        description = "Listen address for Promtail syslog receiver (`host:port`).";
      };

      jobLabel = lib.mkOption {
        type = lib.types.str;
        default = "synology-file-activity";
        description = "Value used for the Loki `job` label on syslog-ingested logs.";
      };
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "grafana/promtail";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "3.6.10";
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
  };
}
