{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.lidarrCompose;
  serviceName = "lidarr";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
in {
  options.services.lidarrCompose = {
    enable = lib.mkEnableOption "Lidarr service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "lidarr";
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
      default = "/var/lib/lidarr";
      description = "Persistent host path used for Lidarr config/state.";
    };

    mediaDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional host path bind-mounted into the container for music library access.";
    };

    mediaMountPath = lib.mkOption {
      type = lib.types.str;
      default = "/music";
      description = "Container path used for the optional music library bind mount.";
    };

    downloadsDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional host path bind-mounted into the container for downloader completed files.";
    };

    downloadsMountPath = lib.mkOption {
      type = lib.types.str;
      default = "/downloads";
      description = "Container path used for the optional downloader bind mount.";
    };

    uid = lib.mkOption {
      type = lib.types.int;
      default = 1000;
      description = "UID passed to the container as `PUID`.";
    };

    gid = lib.mkOption {
      type = lib.types.int;
      default = 1000;
      description = "GID passed to the container as `PGID`.";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "lscr.io/linuxserver/lidarr";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "latest";
        description = "Container image tag.";
      };

      allowMutableTag = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Allow mutable tags such as `latest`.";
      };
    };

    tls = lib.mkEnableOption "TLS on the Lidarr Traefik router";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.lidarrCompose.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.lidarrCompose.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.lidarrCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.lidarrCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.lidarrCompose.image.tag must be pinned (not `latest`) unless services.lidarrCompose.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.lidarrCompose.dataDir must be an absolute path.";
      }
      {
        assertion = cfg.mediaDir == null || lib.hasPrefix "/" cfg.mediaDir;
        message = "services.lidarrCompose.mediaDir must be null or an absolute path.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.mediaMountPath;
        message = "services.lidarrCompose.mediaMountPath must be an absolute path.";
      }
      {
        assertion = cfg.downloadsDir == null || lib.hasPrefix "/" cfg.downloadsDir;
        message = "services.lidarrCompose.downloadsDir must be null or an absolute path.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.downloadsMountPath;
        message = "services.lidarrCompose.downloadsMountPath must be an absolute path.";
      }
      {
        assertion = cfg.uid >= 0;
        message = "services.lidarrCompose.uid must be non-negative.";
      }
      {
        assertion = cfg.gid >= 0;
        message = "services.lidarrCompose.gid must be non-negative.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "Lidarr (Docker Compose)";
      wantedBy = ["multi-user.target"];
      requires = ["docker.service"];
      after = ["docker.service" "network-online.target"];
      wants = ["network-online.target"];
      restartTriggers = [
        config.environment.etc."${serviceName}/docker-compose.yml".source
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = composeDir;
        TimeoutStartSec = 900;
        Restart = "on-failure";
        RestartSec = 10;

        Environment = [
          "LIDARR_CONTAINER_NAME=${cfg.containerName}"
          "LIDARR_IMAGE_REPOSITORY=${cfg.image.repository}"
          "LIDARR_IMAGE_TAG=${cfg.image.tag}"
          "LIDARR_NETWORK=${cfg.network}"
          "LIDARR_HOST=${cfg.hostname}"
          "LIDARR_ENTRYPOINTS=${if cfg.tls then "websecure" else "web"}"
          "LIDARR_TLS=${if cfg.tls then "true" else "false"}"
          "LIDARR_DATA_DIR=${cfg.dataDir}"
          "LIDARR_MEDIA_DIR=${if cfg.mediaDir == null then "" else cfg.mediaDir}"
          "LIDARR_MEDIA_MOUNT_PATH=${cfg.mediaMountPath}"
          "LIDARR_DOWNLOADS_DIR=${if cfg.downloadsDir == null then "" else cfg.downloadsDir}"
          "LIDARR_DOWNLOADS_MOUNT_PATH=${cfg.downloadsMountPath}"
          "LIDARR_PUID=${toString cfg.uid}"
          "LIDARR_PGID=${toString cfg.gid}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${lib.escapeShellArg cfg.dataDir} && chown ${toString cfg.uid}:${toString cfg.gid} ${lib.escapeShellArg cfg.dataDir} && chmod 0750 ${lib.escapeShellArg cfg.dataDir}'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"lidarr: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
