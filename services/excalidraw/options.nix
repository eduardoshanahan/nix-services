{lib, ...}: {
  options.services.excalidraw = {
    enable = lib.mkEnableOption "Excalidraw service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "excalidraw";
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

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "excalidraw/excalidraw";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "latest";
        description = "Container image tag.";
      };

      digest = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Optional immutable digest pin (for example `sha256:...`). When set,
          the module uses `repository@digest` form and
          ignores `services.excalidraw.image.tag`.
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

    tls = lib.mkEnableOption "TLS on the Excalidraw Traefik router";

    monitoring = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable periodic service/container health checks via systemd timer.";
      };

      interval = lib.mkOption {
        type = lib.types.str;
        default = "5m";
        description = "How often to run the Excalidraw healthcheck (for example `5m`).";
      };
    };
  };
}
