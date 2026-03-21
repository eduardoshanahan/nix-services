{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.calibreWebAutomatedCompose;
  serviceName = "calibre-web-automated";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
in {
  options.services.calibreWebAutomatedCompose = {
    enable = lib.mkEnableOption "Calibre-Web-Automated service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "calibre-web-automated";
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
      default = "/var/lib/calibre-web-automated";
      description = "Persistent host path used for Calibre-Web-Automated config/state.";
    };

    libraryDir = lib.mkOption {
      type = lib.types.str;
      description = "Host path bind-mounted into the container as the Calibre library.";
    };

    libraryMountPath = lib.mkOption {
      type = lib.types.str;
      default = "/calibre-library";
      description = "Container path used for the Calibre library bind mount.";
    };

    ingestDir = lib.mkOption {
      type = lib.types.str;
      description = "Host path bind-mounted into the container as the ingest/watch folder.";
    };

    ingestMountPath = lib.mkOption {
      type = lib.types.str;
      default = "/cwa-book-ingest";
      description = "Container path used for the ingest/watch folder bind mount.";
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

    networkShareMode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable network-share-safe mode for libraries stored on NFS/SMB.";
    };

    trustedProxyCount = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = "Number of reverse proxies in front of the app.";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "crocodilestick/calibre-web-automated";
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

    tls = lib.mkEnableOption "TLS on the Calibre-Web-Automated Traefik router";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.calibreWebAutomatedCompose.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.calibreWebAutomatedCompose.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.calibreWebAutomatedCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.calibreWebAutomatedCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.calibreWebAutomatedCompose.image.tag must be pinned (not `latest`) unless services.calibreWebAutomatedCompose.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.calibreWebAutomatedCompose.dataDir must be an absolute path.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.libraryDir;
        message = "services.calibreWebAutomatedCompose.libraryDir must be an absolute path.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.libraryMountPath;
        message = "services.calibreWebAutomatedCompose.libraryMountPath must be an absolute path.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.ingestDir;
        message = "services.calibreWebAutomatedCompose.ingestDir must be an absolute path.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.ingestMountPath;
        message = "services.calibreWebAutomatedCompose.ingestMountPath must be an absolute path.";
      }
      {
        assertion = cfg.uid >= 0;
        message = "services.calibreWebAutomatedCompose.uid must be non-negative.";
      }
      {
        assertion = cfg.gid >= 0;
        message = "services.calibreWebAutomatedCompose.gid must be non-negative.";
      }
      {
        assertion = cfg.trustedProxyCount >= 0;
        message = "services.calibreWebAutomatedCompose.trustedProxyCount must be non-negative.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "Calibre-Web-Automated (Docker Compose)";
      wantedBy = ["multi-user.target"];
      requires = ["docker.service"];
      after = ["docker.service" "network-online.target" "remote-fs.target"];
      wants = ["network-online.target" "remote-fs.target"];
      unitConfig.RequiresMountsFor = [
        cfg.dataDir
        cfg.libraryDir
        cfg.ingestDir
      ];
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
          "CALIBRE_WEB_AUTOMATED_CONTAINER_NAME=${cfg.containerName}"
          "CALIBRE_WEB_AUTOMATED_IMAGE_REPOSITORY=${cfg.image.repository}"
          "CALIBRE_WEB_AUTOMATED_IMAGE_TAG=${cfg.image.tag}"
          "CALIBRE_WEB_AUTOMATED_NETWORK=${cfg.network}"
          "CALIBRE_WEB_AUTOMATED_HOST=${cfg.hostname}"
          "CALIBRE_WEB_AUTOMATED_ENTRYPOINTS=${if cfg.tls then "websecure" else "web"}"
          "CALIBRE_WEB_AUTOMATED_TLS=${if cfg.tls then "true" else "false"}"
          "CALIBRE_WEB_AUTOMATED_DATA_DIR=${cfg.dataDir}"
          "CALIBRE_WEB_AUTOMATED_LIBRARY_DIR=${cfg.libraryDir}"
          "CALIBRE_WEB_AUTOMATED_LIBRARY_MOUNT_PATH=${cfg.libraryMountPath}"
          "CALIBRE_WEB_AUTOMATED_INGEST_DIR=${cfg.ingestDir}"
          "CALIBRE_WEB_AUTOMATED_INGEST_MOUNT_PATH=${cfg.ingestMountPath}"
          "CALIBRE_WEB_AUTOMATED_PUID=${toString cfg.uid}"
          "CALIBRE_WEB_AUTOMATED_PGID=${toString cfg.gid}"
          "CALIBRE_WEB_AUTOMATED_NETWORK_SHARE_MODE=${if cfg.networkShareMode then "true" else "false"}"
          "CALIBRE_WEB_AUTOMATED_TRUSTED_PROXY_COUNT=${toString cfg.trustedProxyCount}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${lib.escapeShellArg cfg.dataDir} ${lib.escapeShellArg cfg.libraryDir} ${lib.escapeShellArg cfg.ingestDir} && touch ${lib.escapeShellArg "${cfg.dataDir}/epub-fixer.log"} && chown ${toString cfg.uid}:${toString cfg.gid} ${lib.escapeShellArg cfg.dataDir} ${lib.escapeShellArg "${cfg.dataDir}/epub-fixer.log"} && chmod 0750 ${lib.escapeShellArg cfg.dataDir} && chmod 0644 ${lib.escapeShellArg "${cfg.dataDir}/epub-fixer.log"}'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"calibre-web-automated: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
