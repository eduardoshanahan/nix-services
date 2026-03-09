{lib, ...}: {
  options.services.d2Compose = {
    enable = lib.mkEnableOption "D2 web service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "d2";
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
      default = "/var/lib/d2";
      description = "Persistent host path used for D2 project files and generated assets.";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "terrastruct/d2";
        description = "Base image repository providing the d2 CLI binary.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "v0.7.1";
        description = "Base image tag.";
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

    auth = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable HTTP basic auth for the D2 editor endpoints.";
      };

      username = lib.mkOption {
        type = lib.types.str;
        default = "admin";
        description = "HTTP basic auth username when auth is enabled.";
      };

      passwordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Optional absolute path to a runtime password file used for HTTP basic
          auth. When null and auth is enabled, the module generates
          `/var/lib/d2/auth/admin-password` (or `${"\${services.d2Compose.dataDir}"}/auth/admin-password`)
          with `openssl rand` on first start.
        '';
      };
    };

    defaultFile = lib.mkOption {
      type = lib.types.str;
      default = "main.d2";
      description = "Default D2 file loaded by the editor on first visit.";
    };

    tls = lib.mkEnableOption "TLS on the D2 Traefik router";
  };
}
