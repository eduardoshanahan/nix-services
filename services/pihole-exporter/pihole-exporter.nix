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
  };
}
