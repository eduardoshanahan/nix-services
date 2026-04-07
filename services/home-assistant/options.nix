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
        default = "2026.4.1";
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

    reverseProxy = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Configure Home Assistant reverse-proxy trust settings in `configuration.yaml`.";
      };

      useXForwardedFor = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Set Home Assistant `http.use_x_forwarded_for`.";
      };

      trustedProxies = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = [ "172.18.0.0/16" ];
        description = "List of trusted reverse proxy CIDRs/IPs for Home Assistant `http.trusted_proxies`.";
      };
    };

    recorder.dbUrlFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/secrets/homeassistant-recorder-db-url";
      description = ''
        Optional file containing a single-line SQLAlchemy database URL for Home Assistant recorder.
        When set, the module injects a managed `recorder.db_url` block in `configuration.yaml`
        using `!env_var HOME_ASSISTANT_RECORDER_DB_URL` and provides that env var at runtime.
      '';
    };
  };
}
