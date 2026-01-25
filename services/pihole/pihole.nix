{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.pihole;
  runtimeSecrets = import ../../lib/runtime-secrets.nix { inherit lib; };
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

        The file is read at service start and injected into the container as
        `FTLCONF_webserver_api_password` via a runtime-generated env file.
      '';
      example = "/run/secrets/pihole-web-password";
    };

  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.webPasswordFile != null;
        message = "services.pihole.webPasswordFile must be set when enabling Pi-hole.";
      }
    ];
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
          ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"

          (pkgs.writeShellScript "pihole-generate-env" ''
            set -euo pipefail
            umask 0077

            secret_file="${cfg.webPasswordFile}"

            if [[ -z "$secret_file" || ! -s "$secret_file" ]]; then
              echo "pihole: webPasswordFile is not set or empty" >&2
              exit 1
            fi

            password="$(cat "$secret_file")"
            password="''${password%$'\n'}"

            escaped="$password"
            escaped="''${escaped//\\/\\\\}"
            escaped="''${escaped//\"/\\\"}"

            install -d -m 0700 /run/secrets
            printf 'FTLCONF_webserver_api_password="%s"\n' "$escaped" > /run/secrets/pihole.env
          '')
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}

