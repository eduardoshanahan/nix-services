{lib, pkgs, ...}: let
  yamlFormat = pkgs.formats.yaml {};
in {
  options.services.homepageDashboard = {
    enable = lib.mkEnableOption "Homepage dashboard service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "homepage";
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

    extraAllowedHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Additional values appended to `HOMEPAGE_ALLOWED_HOSTS`.
        Use this when Homepage must accept requests for extra host headers.
      '';
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "ghcr.io/gethomepage/homepage";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "v1.12.3";
        description = "Container image tag.";
      };

      digest = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Optional immutable digest pin (for example `sha256:...`). When set,
          the module uses `repository@digest` form and
          ignores `services.homepageDashboard.image.tag`.
        '';
      };

      allowMutableTag = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Allow mutable tags such as `latest` when using tag mode.
          Keep disabled to enforce pinned tags by default.
        '';
      };
    };

    tls = lib.mkEnableOption "TLS on the Homepage Traefik router";

    docker = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Mount the Docker socket read-only and generate a local `docker.yaml`
          entry so Homepage can display container-backed status for local cards.
        '';
      };

      instanceName = lib.mkOption {
        type = lib.types.str;
        default = "local";
        description = "Name of the generated Docker integration entry in `docker.yaml`.";
      };

      socketPath = lib.mkOption {
        type = lib.types.str;
        default = "/var/run/docker.sock";
        description = "Host path to the Docker socket mounted read-only into the container.";
      };
    };

    config = {
      settings = lib.mkOption {
        type = yamlFormat.type;
        default = {};
        description = "Contents of `settings.yaml` as a Nix attrset.";
      };

      services = lib.mkOption {
        type = yamlFormat.type;
        default = [];
        description = "Contents of `services.yaml` as a Nix value.";
      };

      bookmarks = lib.mkOption {
        type = yamlFormat.type;
        default = [];
        description = "Contents of `bookmarks.yaml` as a Nix value.";
      };

      widgets = lib.mkOption {
        type = yamlFormat.type;
        default = [];
        description = "Contents of `widgets.yaml` as a Nix value.";
      };

      docker = lib.mkOption {
        type = yamlFormat.type;
        default = {};
        description = "Additional contents merged into `docker.yaml` as a Nix attrset.";
      };
    };
  };
}
