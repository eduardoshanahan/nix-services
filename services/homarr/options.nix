{lib, ...}: {
  options.services.homarr = {
    enable = lib.mkEnableOption "Homarr dashboard service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "homarr";
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
      default = "/var/lib/homarr";
      description = "Host path for Homarr persistent app data (`/appdata` in container).";
    };

    secretEncryptionKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/secrets/homarr-secret-encryption-key";
      description = ''
        Path to a single-line file containing Homarr `SECRET_ENCRYPTION_KEY`.
        Upstream expects a 64-character hex string.
      '';
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "ghcr.io/homarr-labs/homarr";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "v1.59.1";
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

    tls = lib.mkEnableOption "TLS on the Homarr Traefik router";

    docker = {
      hostnames = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = [ "rpi-box-02.internal.example" "hhnas4.internal.example" ];
        description = ''
          Optional Docker API hostnames passed to Homarr via `DOCKER_HOSTNAMES`.
          Use this with Docker socket proxies or remote Docker API endpoints.
        '';
      };

      ports = lib.mkOption {
        type = lib.types.listOf lib.types.port;
        default = [];
        example = [ 2375 2375 ];
        description = ''
          Optional Docker API ports passed to Homarr via `DOCKER_PORTS`.
          Must align positionally with `services.homarr.docker.hostnames`.
        '';
      };
    };
  };
}
