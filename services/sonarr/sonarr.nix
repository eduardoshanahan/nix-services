{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.sonarrCompose;
  serviceName = "sonarr";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
in {
  options.services.sonarrCompose = {
    enable = lib.mkEnableOption "Sonarr service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "sonarr";
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
      default = "/var/lib/sonarr";
      description = "Persistent host path used for Sonarr config/state.";
    };

    mediaDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional host path bind-mounted into the container for TV library access.";
    };

    mediaMountPath = lib.mkOption {
      type = lib.types.str;
      default = "/tv";
      description = "Container path used for the optional TV library bind mount.";
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
        default = "lscr.io/linuxserver/sonarr";
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

    tls = lib.mkEnableOption "TLS on the Sonarr Traefik router";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.sonarrCompose.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.sonarrCompose.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.sonarrCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.sonarrCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.sonarrCompose.image.tag must be pinned (not `latest`) unless services.sonarrCompose.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.sonarrCompose.dataDir must be an absolute path.";
      }
      {
        assertion = cfg.mediaDir == null || lib.hasPrefix "/" cfg.mediaDir;
        message = "services.sonarrCompose.mediaDir must be null or an absolute path.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.mediaMountPath;
        message = "services.sonarrCompose.mediaMountPath must be an absolute path.";
      }
      {
        assertion = cfg.downloadsDir == null || lib.hasPrefix "/" cfg.downloadsDir;
        message = "services.sonarrCompose.downloadsDir must be null or an absolute path.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.downloadsMountPath;
        message = "services.sonarrCompose.downloadsMountPath must be an absolute path.";
      }
      {
        assertion = cfg.uid >= 0;
        message = "services.sonarrCompose.uid must be non-negative.";
      }
      {
        assertion = cfg.gid >= 0;
        message = "services.sonarrCompose.gid must be non-negative.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "Sonarr (Docker Compose)";
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
          "SONARR_CONTAINER_NAME=${cfg.containerName}"
          "SONARR_IMAGE_REPOSITORY=${cfg.image.repository}"
          "SONARR_IMAGE_TAG=${cfg.image.tag}"
          "SONARR_NETWORK=${cfg.network}"
          "SONARR_HOST=${cfg.hostname}"
          "SONARR_ENTRYPOINTS=${if cfg.tls then "websecure" else "web"}"
          "SONARR_TLS=${if cfg.tls then "true" else "false"}"
          "SONARR_DATA_DIR=${cfg.dataDir}"
          "SONARR_MEDIA_DIR=${if cfg.mediaDir == null then "" else cfg.mediaDir}"
          "SONARR_MEDIA_MOUNT_PATH=${cfg.mediaMountPath}"
          "SONARR_DOWNLOADS_DIR=${if cfg.downloadsDir == null then "" else cfg.downloadsDir}"
          "SONARR_DOWNLOADS_MOUNT_PATH=${cfg.downloadsMountPath}"
          "SONARR_PUID=${toString cfg.uid}"
          "SONARR_PGID=${toString cfg.gid}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${lib.escapeShellArg cfg.dataDir} && chown ${toString cfg.uid}:${toString cfg.gid} ${lib.escapeShellArg cfg.dataDir} && chmod 0750 ${lib.escapeShellArg cfg.dataDir}'"
          "${pkgs.runtimeShell} -c 'test -s /etc/ssl/certs/ca-certificates-with-homelab.pem'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"sonarr: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
