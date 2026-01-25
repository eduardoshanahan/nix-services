{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.pihole;
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};

  serviceName = "pihole";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
in {
  options.services.pihole = {
    enable = lib.mkEnableOption "Pi-hole DNS sinkhole (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "pihole";
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

    webPasswordFile = runtimeSecrets.mkSecretFileOption {
      description = ''
        Absolute path to a runtime-provisioned file containing the Pi-hole web UI password.

        This value is passed to the container via `FTLCONF_webserver_api_password__FILE`, so the secret is never embedded in Nix or the environment.
      '';
      example = "/run/secrets/pihole-web-password";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "Pi-hole DNS sinkhole (Docker Compose)";

      wantedBy = ["multi-user.target"];
      after = ["docker.service" "network-online.target"];
      wants = ["network-online.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;

        WorkingDirectory = composeDir;

        Environment =
          [
            "PIHOLE_CONTAINER_NAME=${cfg.containerName}"
            "PIHOLE_NETWORK=${cfg.network}"
            "PIHOLE_HOSTNAME=${cfg.hostname}"
            "TZ=${cfg.timezone}"
          ]
          ++ runtimeSecrets.mkSecretFileEnvVar {
            envVar = "FTLCONF_webserver_api_password__FILE";
            secretFile = cfg.webPasswordFile;
            fallback = "/dev/null";
          };

        ExecStartPre = [
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}

