{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.lazylibrarianCompose;
  serviceName = "lazylibrarian";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
in {
  options.services.lazylibrarianCompose = {
    enable = lib.mkEnableOption "LazyLibrarian service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "lazylibrarian";
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
      default = "/var/lib/lazylibrarian";
      description = "Persistent host path used for LazyLibrarian config/state.";
    };

    downloadsDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional host path bind-mounted into the container for downloader completed files.";
    };

    downloadsMountPath = lib.mkOption {
      type = lib.types.str;
      default = "/downloads";
      description = "Container path used for the downloader bind mount.";
    };

    booksDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional host path bind-mounted into the container for LazyLibrarian's own library/staging area.";
    };

    booksMountPath = lib.mkOption {
      type = lib.types.str;
      default = "/books";
      description = "Container path used for the LazyLibrarian library/staging bind mount.";
    };

    cwaIngestDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional host path bind-mounted into the container for Calibre-Web-Automated ingest handoff.";
    };

    cwaIngestMountPath = lib.mkOption {
      type = lib.types.str;
      default = "/cwa-book-ingest";
      description = "Container path used for the Calibre-Web-Automated ingest bind mount.";
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
        default = "lscr.io/linuxserver/lazylibrarian";
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

    tls = lib.mkEnableOption "TLS on the LazyLibrarian Traefik router";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.lazylibrarianCompose.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.lazylibrarianCompose.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.lazylibrarianCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.lazylibrarianCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.lazylibrarianCompose.image.tag must be pinned (not `latest`) unless services.lazylibrarianCompose.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.lazylibrarianCompose.dataDir must be an absolute path.";
      }
      {
        assertion = cfg.downloadsDir == null || lib.hasPrefix "/" cfg.downloadsDir;
        message = "services.lazylibrarianCompose.downloadsDir must be null or an absolute path.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.downloadsMountPath;
        message = "services.lazylibrarianCompose.downloadsMountPath must be an absolute path.";
      }
      {
        assertion = cfg.booksDir == null || lib.hasPrefix "/" cfg.booksDir;
        message = "services.lazylibrarianCompose.booksDir must be null or an absolute path.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.booksMountPath;
        message = "services.lazylibrarianCompose.booksMountPath must be an absolute path.";
      }
      {
        assertion = cfg.cwaIngestDir == null || lib.hasPrefix "/" cfg.cwaIngestDir;
        message = "services.lazylibrarianCompose.cwaIngestDir must be null or an absolute path.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.cwaIngestMountPath;
        message = "services.lazylibrarianCompose.cwaIngestMountPath must be an absolute path.";
      }
      {
        assertion = cfg.uid >= 0;
        message = "services.lazylibrarianCompose.uid must be non-negative.";
      }
      {
        assertion = cfg.gid >= 0;
        message = "services.lazylibrarianCompose.gid must be non-negative.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "LazyLibrarian (Docker Compose)";
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
          "LAZYLIBRARIAN_CONTAINER_NAME=${cfg.containerName}"
          "LAZYLIBRARIAN_IMAGE_REPOSITORY=${cfg.image.repository}"
          "LAZYLIBRARIAN_IMAGE_TAG=${cfg.image.tag}"
          "LAZYLIBRARIAN_NETWORK=${cfg.network}"
          "LAZYLIBRARIAN_HOST=${cfg.hostname}"
          "LAZYLIBRARIAN_ENTRYPOINTS=${if cfg.tls then "websecure" else "web"}"
          "LAZYLIBRARIAN_TLS=${if cfg.tls then "true" else "false"}"
          "LAZYLIBRARIAN_DATA_DIR=${cfg.dataDir}"
          "LAZYLIBRARIAN_DOWNLOADS_DIR=${if cfg.downloadsDir == null then "" else cfg.downloadsDir}"
          "LAZYLIBRARIAN_DOWNLOADS_MOUNT_PATH=${cfg.downloadsMountPath}"
          "LAZYLIBRARIAN_BOOKS_DIR=${if cfg.booksDir == null then "" else cfg.booksDir}"
          "LAZYLIBRARIAN_BOOKS_MOUNT_PATH=${cfg.booksMountPath}"
          "LAZYLIBRARIAN_CWA_INGEST_DIR=${if cfg.cwaIngestDir == null then "" else cfg.cwaIngestDir}"
          "LAZYLIBRARIAN_CWA_INGEST_MOUNT_PATH=${cfg.cwaIngestMountPath}"
          "LAZYLIBRARIAN_PUID=${toString cfg.uid}"
          "LAZYLIBRARIAN_PGID=${toString cfg.gid}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${lib.escapeShellArg cfg.dataDir}${lib.optionalString (cfg.downloadsDir != null) " ${lib.escapeShellArg cfg.downloadsDir}"}${lib.optionalString (cfg.booksDir != null) " ${lib.escapeShellArg cfg.booksDir}"}${lib.optionalString (cfg.cwaIngestDir != null) " ${lib.escapeShellArg cfg.cwaIngestDir}"} && chown ${toString cfg.uid}:${toString cfg.gid} ${lib.escapeShellArg cfg.dataDir} && chmod 0750 ${lib.escapeShellArg cfg.dataDir}${lib.optionalString (cfg.booksDir != null) " && chmod 0775 ${lib.escapeShellArg cfg.booksDir}"}${lib.optionalString (cfg.cwaIngestDir != null) " && chmod 0775 ${lib.escapeShellArg cfg.cwaIngestDir}"}'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"lazylibrarian: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
