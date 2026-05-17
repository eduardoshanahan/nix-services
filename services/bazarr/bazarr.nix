{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.bazarrCompose;
  serviceName = "bazarr";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
in {
  options.services.bazarrCompose = {
    enable = lib.mkEnableOption "Bazarr service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "bazarr";
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
      default = "/var/lib/bazarr";
      description = "Persistent host path used for Bazarr config/state.";
    };

    tvDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional host path bind-mounted into the container for TV library access.";
    };

    tvMountPath = lib.mkOption {
      type = lib.types.str;
      default = "/tv";
      description = "Container path used for the optional TV library bind mount.";
    };

    moviesDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional host path bind-mounted into the container for movies library access.";
    };

    moviesMountPath = lib.mkOption {
      type = lib.types.str;
      default = "/movies";
      description = "Container path used for the optional movies library bind mount.";
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
        default = "lscr.io/linuxserver/bazarr";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "v1.5.6-ls348";
        description = "Container image tag.";
      };

      allowMutableTag = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Allow mutable tags such as `latest`.";
      };
    };

    tls = lib.mkEnableOption "TLS on the Bazarr Traefik router";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.bazarrCompose.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.bazarrCompose.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.bazarrCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.bazarrCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.bazarrCompose.image.tag must be pinned (not `latest`) unless services.bazarrCompose.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.bazarrCompose.dataDir must be an absolute path.";
      }
      {
        assertion = cfg.tvDir == null || lib.hasPrefix "/" cfg.tvDir;
        message = "services.bazarrCompose.tvDir must be null or an absolute path.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.tvMountPath;
        message = "services.bazarrCompose.tvMountPath must be an absolute path.";
      }
      {
        assertion = cfg.moviesDir == null || lib.hasPrefix "/" cfg.moviesDir;
        message = "services.bazarrCompose.moviesDir must be null or an absolute path.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.moviesMountPath;
        message = "services.bazarrCompose.moviesMountPath must be an absolute path.";
      }
      {
        assertion = cfg.uid >= 0;
        message = "services.bazarrCompose.uid must be non-negative.";
      }
      {
        assertion = cfg.gid >= 0;
        message = "services.bazarrCompose.gid must be non-negative.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "Bazarr (Docker Compose)";
      wantedBy = ["multi-user.target"];
      requires = ["docker.service"];
      after = ["docker.service" "network-online.target" "remote-fs.target"];
      wants = ["network-online.target" "remote-fs.target"];
      unitConfig.RequiresMountsFor =
        [cfg.dataDir]
        ++ lib.optionals (cfg.tvDir != null) [cfg.tvDir]
        ++ lib.optionals (cfg.moviesDir != null) [cfg.moviesDir];
      restartTriggers = [
        config.environment.etc."${serviceName}/docker-compose.yml".source
      ];

      environment = {
        BAZARR_CONTAINER_NAME = cfg.containerName;
        BAZARR_IMAGE_REPOSITORY = cfg.image.repository;
        BAZARR_IMAGE_TAG = cfg.image.tag;
        BAZARR_NETWORK = cfg.network;
        BAZARR_HOST = cfg.hostname;
        BAZARR_ENTRYPOINTS =
          if cfg.tls
          then "websecure"
          else "web";
        BAZARR_TLS =
          if cfg.tls
          then "true"
          else "false";
        BAZARR_DATA_DIR = cfg.dataDir;
        BAZARR_TV_DIR =
          if cfg.tvDir == null
          then ""
          else cfg.tvDir;
        BAZARR_TV_MOUNT_PATH = cfg.tvMountPath;
        BAZARR_MOVIES_DIR =
          if cfg.moviesDir == null
          then ""
          else cfg.moviesDir;
        BAZARR_MOVIES_MOUNT_PATH = cfg.moviesMountPath;
        BAZARR_PUID = toString cfg.uid;
        BAZARR_PGID = toString cfg.gid;
        TZ = cfg.timezone;
      };

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = composeDir;
        TimeoutStartSec = 900;
        Restart = "on-failure";
        RestartSec = 10;

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${lib.escapeShellArg cfg.dataDir} && chown ${toString cfg.uid}:${toString cfg.gid} ${lib.escapeShellArg cfg.dataDir} && chmod 0750 ${lib.escapeShellArg cfg.dataDir}'"
          "${pkgs.runtimeShell} -c 'test -s /etc/ssl/certs/ca-certificates-with-homelab.pem'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"bazarr: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
