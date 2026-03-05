{lib, ...}: {
  options.services.homeAssistant = {
    enable = lib.mkEnableOption "Home Assistant service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "home-assistant";
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
      default = "/var/lib/home-assistant";
      description = "Host path for Home Assistant persistent config/state (`/config` in container).";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "ghcr.io/home-assistant/home-assistant";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "2026.3.0";
        description = "Container image tag.";
      };

      allowMutableTag = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Allow mutable tags such as `latest`.
          Keep disabled to enforce pinned tags by default.
        '';
      };
    };

    tls = lib.mkEnableOption "TLS on the Home Assistant Traefik router";
  };
}
