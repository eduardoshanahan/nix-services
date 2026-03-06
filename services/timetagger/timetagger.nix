{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.timeTaggerCompose;
  serviceName = "timetagger";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
in {
  options.services.timeTaggerCompose = {
    enable = lib.mkEnableOption "TimeTagger service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "timetagger";
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
      default = "/var/lib/timetagger";
      description = "Persistent host path used for TimeTagger data.";
    };

    logLevel = lib.mkOption {
      type = lib.types.enum [ "debug" "info" "warning" "error" ];
      default = "info";
      description = "Application log level passed via TIMETAGGER_LOG_LEVEL.";
    };

    auth = {
      proxy = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable TimeTagger reverse-proxy authentication mode.";
        };

        header = lib.mkOption {
          type = lib.types.str;
          default = "X-authentik-username";
          description = "HTTP header containing the authenticated username.";
        };

        trusted = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Comma-separated trusted reverse-proxy source IPs/CIDRs.";
          example = "127.0.0.1,172.18.0.0/16";
        };
      };
    };

    authentikForwardAuth = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Traefik forward-auth middleware pointing to Authentik outpost.";
      };

      address = lib.mkOption {
        type = lib.types.str;
        default = "http://authentik-server:9000/outpost.goauthentik.io/auth/traefik";
        description = "Authentik outpost forward-auth endpoint URL.";
      };

      trustForwardHeader = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Set Traefik forwardAuth trustForwardHeader flag.";
      };

      responseHeaders = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "X-authentik-username"
          "X-authentik-email"
          "X-authentik-name"
          "X-authentik-groups"
        ];
        description = "Headers copied by Traefik from Authentik auth response to backend requests.";
      };
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "ghcr.io/almarklein/timetagger";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "latest";
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

    tls = lib.mkEnableOption "TLS on the TimeTagger Traefik router";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.timeTaggerCompose.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.timeTaggerCompose.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.timeTaggerCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.timeTaggerCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.timeTaggerCompose.image.tag must be pinned (not `latest`) unless services.timeTaggerCompose.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.timeTaggerCompose.dataDir must be an absolute path.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.auth.proxy.header != null;
        message = "services.timeTaggerCompose.auth.proxy.header must not contain whitespace.";
      }
      {
        assertion = !cfg.authentikForwardAuth.enable || builtins.match "^[^[:space:]]+$" cfg.authentikForwardAuth.address != null;
        message = "services.timeTaggerCompose.authentikForwardAuth.address must not contain whitespace.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "TimeTagger (Docker Compose)";
      wantedBy = [ "multi-user.target" ];
      requires = [ "docker.service" ];
      after = [ "docker.service" "network-online.target" ];
      wants = [ "network-online.target" ];
      restartTriggers = [
        config.environment.etc."${serviceName}/docker-compose.yml".source
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = composeDir;
        TimeoutStartSec = 180;
        Restart = "on-failure";
        RestartSec = 10;

        Environment = [
          "TIMETAGGER_CONTAINER_NAME=${cfg.containerName}"
          "TIMETAGGER_IMAGE_REPOSITORY=${cfg.image.repository}"
          "TIMETAGGER_IMAGE_TAG=${cfg.image.tag}"
          "TIMETAGGER_NETWORK=${cfg.network}"
          "TIMETAGGER_HOSTNAME=${cfg.hostname}"
          "TIMETAGGER_ENTRYPOINTS=${if cfg.tls then "websecure" else "web"}"
          "TIMETAGGER_TLS=${if cfg.tls then "true" else "false"}"
          "TIMETAGGER_DATA_DIR=${cfg.dataDir}"
          "TIMETAGGER_LOG_LEVEL=${cfg.logLevel}"
          "TIMETAGGER_PROXY_AUTH_ENABLED=${if cfg.auth.proxy.enable then "True" else "False"}"
          "TIMETAGGER_PROXY_AUTH_TRUSTED=${cfg.auth.proxy.trusted}"
          "TIMETAGGER_PROXY_AUTH_HEADER=${cfg.auth.proxy.header}"
          "TIMETAGGER_AUTHENTIK_FORWARD_AUTH_ENABLED=${if cfg.authentikForwardAuth.enable then "true" else "false"}"
          "TIMETAGGER_AUTHENTIK_FORWARD_AUTH_ADDRESS=${cfg.authentikForwardAuth.address}"
          "TIMETAGGER_AUTHENTIK_FORWARD_AUTH_TRUST_FORWARD_HEADER=${if cfg.authentikForwardAuth.trustForwardHeader then "true" else "false"}"
          "TIMETAGGER_AUTHENTIK_FORWARD_AUTH_RESPONSE_HEADERS=${lib.concatStringsSep "," cfg.authentikForwardAuth.responseHeaders}"
          "TIMETAGGER_ROUTER_MIDDLEWARES=${
            if cfg.authentikForwardAuth.enable
            then "timetagger-auth@docker"
            else ""
          }"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${lib.escapeShellArg cfg.dataDir}'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"timetagger: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
