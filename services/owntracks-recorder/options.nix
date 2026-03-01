{lib, ...}: {
  options.services.owntracksRecorder = {
    enable = lib.mkEnableOption "OwnTracks Recorder service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "owntracks-recorder";
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
      default = "/var/lib/owntracks-recorder";
      description = "Persistent host path used for OwnTracks Recorder data.";
    };

    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 8083;
      description = "Internal HTTP listen port used by OwnTracks Recorder.";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "owntracks/recorder";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "1.0.1";
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

    tls = lib.mkEnableOption "TLS on the OwnTracks Recorder Traefik router";
  };
}
