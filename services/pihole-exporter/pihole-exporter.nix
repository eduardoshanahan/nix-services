{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.piholeExporter;
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};
  runtimeSecretEnv = import ../../lib/runtime-secret-env.nix {inherit lib pkgs;};

  serviceName = "pihole-exporter";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  healthcheckScript = pkgs.writeShellScript "pihole-exporter-healthcheck" ''
    set -euo pipefail

    probe_url="http://127.0.0.1:${toString cfg.listenPort}/metrics"

    # Retry once before restart to avoid reacting to single transient failures.
    if ${pkgs.curl}/bin/curl -fsS --max-time 8 "$probe_url" >/dev/null; then
      exit 0
    fi

    sleep 2
    if ${pkgs.curl}/bin/curl -fsS --max-time 8 "$probe_url" >/dev/null; then
      exit 0
    fi

    echo "pihole-exporter healthcheck failed twice, restarting ${serviceName}.service" >&2
    ${pkgs.systemd}/bin/systemctl restart ${serviceName}.service
  '';
in {
  options.services.piholeExporter = {
    enable = lib.mkEnableOption "Pi-hole Prometheus exporter (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "pihole-exporter";
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

    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 9617;
      description = "Host TCP port mapped to exporter port 9617.";
    };

    pihole = {
      hostname = lib.mkOption {
        type = lib.types.str;
        default = "pihole";
        description = "Pi-hole host reachable from exporter container (for example `pihole`).";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 80;
        description = "Pi-hole HTTP port.";
      };

      protocol = lib.mkOption {
        type = lib.types.enum [ "http" "https" ];
        default = "http";
        description = "Pi-hole protocol used by exporter.";
      };

      passwordFile = runtimeSecrets.mkSecretFileOption {
        description = ''
          Absolute path to a runtime-provisioned file containing the Pi-hole web password.
        '';
        example = "/run/secrets/pihole-web-password";
      };
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "ekofr/pihole-exporter";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "v1.2.0";
        description = "Container image tag.";
      };
    };

    monitoring = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable periodic local /metrics health checks with auto-restart on repeated failures.";
      };

      interval = lib.mkOption {
        type = lib.types.str;
        default = "2m";
        description = "How often to run the exporter healthcheck (for example `2m`).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.pihole.passwordFile != null;
        message = "services.piholeExporter.pihole.passwordFile must be set when enabling Pi-hole exporter.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "Pi-hole Prometheus exporter (Docker Compose)";

      wantedBy = ["multi-user.target"];
      after = ["docker.service" "network-online.target"];
      wants = ["network-online.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = composeDir;

        Environment = [
          "PIHOLE_EXPORTER_CONTAINER_NAME=${cfg.containerName}"
          "PIHOLE_EXPORTER_NETWORK=${cfg.network}"
          "PIHOLE_EXPORTER_PORT=${toString cfg.listenPort}"
          "PIHOLE_EXPORTER_PIHOLE_HOSTNAME=${cfg.pihole.hostname}"
          "PIHOLE_EXPORTER_PIHOLE_PORT=${toString cfg.pihole.port}"
          "PIHOLE_EXPORTER_PIHOLE_PROTOCOL=${cfg.pihole.protocol}"
          "PIHOLE_EXPORTER_IMAGE_REPOSITORY=${cfg.image.repository}"
          "PIHOLE_EXPORTER_IMAGE_TAG=${cfg.image.tag}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
          (runtimeSecretEnv.mkRuntimeSecretEnvExecStartPre {
            name = serviceName;
            secretFile = cfg.pihole.passwordFile;
            envVar = "PIHOLE_PASSWORD";
          })
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };

    systemd.services."${serviceName}-healthcheck" = lib.mkIf cfg.monitoring.enable {
      description = "Pi-hole exporter periodic healthcheck";
      after = ["${serviceName}.service"];
      requires = ["${serviceName}.service"];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = healthcheckScript;
      };
    };

    systemd.timers."${serviceName}-healthcheck" = lib.mkIf cfg.monitoring.enable {
      description = "Run Pi-hole exporter periodic healthcheck";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "2m";
        OnUnitActiveSec = cfg.monitoring.interval;
        Unit = "${serviceName}-healthcheck.service";
      };
    };
  };
}
