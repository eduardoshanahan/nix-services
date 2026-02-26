{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.unpollerCompose;
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};

  serviceName = "unpoller";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
in {
  options.services.unpollerCompose = {
    enable = lib.mkEnableOption "UniFi Poller (unpoller) exporter service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "unpoller";
      description = "Docker container name.";
    };

    network = lib.mkOption {
      type = lib.types.str;
      default = "traefik";
      description = "External Docker network name used by Traefik and downstream services.";
    };

    timezone = lib.mkOption {
      type = lib.types.str;
      default = "UTC";
      description = "Timezone passed to the container via `TZ`.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Host listen address for the exported Prometheus metrics endpoint.";
      example = "127.0.0.1";
    };

    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 9130;
      description = "Host TCP port mapped to exporter port 9130.";
    };

    controller = {
      url = lib.mkOption {
        type = lib.types.str;
        description = "UniFi controller URL (for example `https://ucg-max.<homelab-domain>`).";
      };

      verifySsl = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether unpoller verifies the UniFi controller TLS certificate.";
      };
    };

    secretFile = runtimeSecrets.mkSecretFileOption {
      description = ''
        Absolute path to a runtime-provisioned env file consumed by unpoller.

        The file must include:
        - `UP_UNIFI_CONTROLLER_0_USER=<username>`
        - `UP_UNIFI_CONTROLLER_0_PASS=<password>`
      '';
      example = "/run/secrets/unpoller.env";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "ghcr.io/unpoller/unpoller";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "v2.16.0";
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
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.unpollerCompose.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.unpollerCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.unpollerCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.unpollerCompose.image.tag must be pinned (not `latest`) unless services.unpollerCompose.image.allowMutableTag = true.";
      }
      {
        assertion = cfg.secretFile != null;
        message = "services.unpollerCompose.secretFile must be set when enabling unpoller.";
      }
      {
        assertion = lib.hasPrefix "http://" cfg.controller.url || lib.hasPrefix "https://" cfg.controller.url;
        message = "services.unpollerCompose.controller.url must start with http:// or https://.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "UniFi Poller (unpoller) exporter (Docker Compose)";

      wantedBy = ["multi-user.target"];
      after = ["docker.service" "network-online.target"];
      wants = ["network-online.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = composeDir;

        Environment = [
          "UNPOLLER_CONTAINER_NAME=${cfg.containerName}"
          "UNPOLLER_NETWORK=${cfg.network}"
          "UNPOLLER_LISTEN_ADDRESS=${cfg.listenAddress}"
          "UNPOLLER_LISTEN_PORT=${toString cfg.listenPort}"
          "UNPOLLER_CONTROLLER_URL=${cfg.controller.url}"
          "UNPOLLER_CONTROLLER_VERIFY_SSL=${if cfg.controller.verifySsl then "true" else "false"}"
          "UNPOLLER_IMAGE_REPOSITORY=${cfg.image.repository}"
          "UNPOLLER_IMAGE_TAG=${cfg.image.tag}"
          "UNPOLLER_ENV_FILE=${toString cfg.secretFile}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'test -s ${toString cfg.secretFile}'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"unpoller: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
