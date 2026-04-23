{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.pihole;
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};
  runtimeSecretEnv = import ../../lib/runtime-secret-env.nix {inherit lib pkgs;};
  serviceName = "pihole";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  routeRecoveryScript = pkgs.writeShellScript "pihole-route-recovery" ''
    set -euo pipefail

    route_url="${if cfg.tls then "https" else "http"}://127.0.0.1/admin/"
    curl_opts=(${lib.optionalString cfg.tls "-k"} -sS -o /dev/null -w "%{http_code}" -H "Host: ${cfg.hostname}")

    # Give the recreated container a short window to finish exposing the admin route.
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
      code="$(${pkgs.curl}/bin/curl "''${curl_opts[@]}" "$route_url" || true)"
      if [ "$code" != "404" ] && [ -n "$code" ]; then
        exit 0
      fi
      /run/current-system/sw/bin/sleep 1
    done

    if ! /run/current-system/sw/bin/systemctl cat traefik.service >/dev/null 2>&1; then
      exit 0
    fi

    /run/current-system/sw/bin/systemctl restart traefik.service

    for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
      code="$(${pkgs.curl}/bin/curl "''${curl_opts[@]}" "$route_url" || true)"
      if [ "$code" != "404" ] && [ -n "$code" ]; then
        exit 0
      fi
      /run/current-system/sw/bin/sleep 1
    done

    echo "pihole: Traefik route for ${cfg.hostname} still returned 404 after a Traefik restart" >&2
    exit 1
  '';
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

    shmSize = lib.mkOption {
      type = lib.types.str;
      default = "256m";
      description = ''
        Shared memory size passed to the Pi-hole container.

        Pi-hole FTL can exhaust Docker's default `/dev/shm` allocation on busy
        resolvers, causing healthcheck and DNS timeouts.
      '';
    };

    webPasswordFile = runtimeSecrets.mkSecretFileOption {
      description = ''
        Absolute path to a runtime-provisioned file containing the Pi-hole web UI password.

        The file is read at service start and injected into the container as
        `FTLCONF_webserver_api_password` via a runtime-generated env file.
      '';
      example = "/run/secrets/pihole-web-password";
    };

    tls = lib.mkEnableOption "TLS on the Pi-hole Traefik router";
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
      restartTriggers = [
        config.environment.etc."${serviceName}/docker-compose.yml".source
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;

        WorkingDirectory = composeDir;

        Environment = [
          "PIHOLE_CONTAINER_NAME=${cfg.containerName}"
          "PIHOLE_NETWORK=${cfg.network}"
          "PIHOLE_HOSTNAME=${cfg.hostname}"
          "PIHOLE_ENTRYPOINTS=${if cfg.tls then "websecure" else "web"}"
          "PIHOLE_TLS=${if cfg.tls then "true" else "false"}"
          "PIHOLE_SHM_SIZE=${cfg.shmSize}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"

          (runtimeSecretEnv.mkRuntimeSecretEnvExecStartPre {
            name = serviceName;
            secretFile = cfg.webPasswordFile;
            envVar = "FTLCONF_webserver_api_password";
          })
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStartPost = routeRecoveryScript;
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
