{lib, ...}: {
  options.services.vikunjaCompose = {
    enable = lib.mkEnableOption "Vikunja service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "vikunja";
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
      default = "/var/lib/vikunja";
      description = "Persistent host path used for Vikunja attachments and SQLite data.";
    };

    enableRegistration = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow self-service user registration.";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "vikunja/vikunja";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "2.1.0";
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

    tls = lib.mkEnableOption "TLS on the Vikunja Traefik router";
  };
}
