{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.prowlarrCompose;
  serviceName = "prowlarr";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
  servarrReconcile = import ../../lib/servarr-reconcile.nix {
    inherit lib pkgs dockerBin;
  };
  reconcileScript = servarrReconcile.writeProwlarrApplicationsScript {
    scriptName = "${serviceName}-reconcile-applications";
    containerName = cfg.containerName;
    networkName = cfg.network;
    configXmlPath = "${cfg.dataDir}/config.xml";
    port = 9696;
    apiPath = "/api/v1";
    applications = cfg.applications;
  };
  hasDeclarativeApplications = lib.any (app: app.enable) cfg.applications;
in {
  options.services.prowlarrCompose = {
    enable = lib.mkEnableOption "Prowlarr service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "prowlarr";
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
      default = "/var/lib/prowlarr";
      description = "Persistent host path used for Prowlarr config/state.";
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
        default = "lscr.io/linuxserver/prowlarr";
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

    tls = lib.mkEnableOption "TLS on the Prowlarr Traefik router";

    applications = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule servarrReconcile.prowlarrApplicationSubmodule);
      default = [];
      description = "Declarative application links to reconcile in Prowlarr after startup.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.prowlarrCompose.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.prowlarrCompose.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.prowlarrCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.prowlarrCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.prowlarrCompose.image.tag must be pinned (not `latest`) unless services.prowlarrCompose.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.prowlarrCompose.dataDir must be an absolute path.";
      }
      {
        assertion = cfg.uid >= 0;
        message = "services.prowlarrCompose.uid must be non-negative.";
      }
      {
        assertion = cfg.gid >= 0;
        message = "services.prowlarrCompose.gid must be non-negative.";
      }
      {
        assertion = lib.all (app: (!app.enable) || (builtins.match servarrReconcile.urlRegex app.baseUrl != null)) cfg.applications;
        message = "services.prowlarrCompose.applications.*.baseUrl must be an absolute http(s) URL when enabled.";
      }
      {
        assertion = lib.all (app: (!app.enable) || (builtins.match servarrReconcile.urlRegex app.prowlarrUrl != null)) cfg.applications;
        message = "services.prowlarrCompose.applications.*.prowlarrUrl must be an absolute http(s) URL when enabled.";
      }
      {
        assertion = lib.all (app: (!app.enable) || lib.hasPrefix "/" app.configXmlPath) cfg.applications;
        message = "services.prowlarrCompose.applications.*.configXmlPath must be an absolute path when enabled.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "Prowlarr (Docker Compose)";
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
          "PROWLARR_CONTAINER_NAME=${cfg.containerName}"
          "PROWLARR_IMAGE_REPOSITORY=${cfg.image.repository}"
          "PROWLARR_IMAGE_TAG=${cfg.image.tag}"
          "PROWLARR_NETWORK=${cfg.network}"
          "PROWLARR_HOST=${cfg.hostname}"
          "PROWLARR_ENTRYPOINTS=${if cfg.tls then "websecure" else "web"}"
          "PROWLARR_TLS=${if cfg.tls then "true" else "false"}"
          "PROWLARR_DATA_DIR=${cfg.dataDir}"
          "PROWLARR_PUID=${toString cfg.uid}"
          "PROWLARR_PGID=${toString cfg.gid}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${lib.escapeShellArg cfg.dataDir} && chown ${toString cfg.uid}:${toString cfg.gid} ${lib.escapeShellArg cfg.dataDir} && chmod 0750 ${lib.escapeShellArg cfg.dataDir}'"
          "${pkgs.runtimeShell} -c 'test -s /etc/ssl/certs/ca-certificates-with-homelab.pem'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"prowlarr: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };

    systemd.services."${serviceName}-reconcile" = lib.mkIf hasDeclarativeApplications {
      description = "Reconcile declarative ${serviceName} applications";
      wantedBy = ["${serviceName}.service"];
      requires = ["${serviceName}.service"];
      after = ["${serviceName}.service" "network-online.target"];
      wants = ["network-online.target"];
      partOf = ["${serviceName}.service"];

      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = 300;
        Restart = "on-failure";
        RestartSec = 30;
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 45";
        ExecStart = reconcileScript;
      };
    };
  };
}
