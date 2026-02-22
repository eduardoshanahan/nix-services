{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.diagramsNet;
  serviceName = "diagrams-net";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
in {
  options.services.diagramsNet = {
    enable = lib.mkEnableOption "diagrams.net service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "diagrams-net";
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

    tls = lib.mkEnableOption "TLS on the diagrams.net Traefik router";
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "diagrams.net (Docker Compose)";

      wantedBy = ["multi-user.target"];
      after = ["docker.service" "network-online.target"];
      wants = ["network-online.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = composeDir;

        Environment = [
          "DIAGRAMS_NET_CONTAINER_NAME=${cfg.containerName}"
          "DIAGRAMS_NET_HOSTNAME=${cfg.hostname}"
          "DIAGRAMS_NET_NETWORK=${cfg.network}"
          "DIAGRAMS_NET_ENTRYPOINTS=${if cfg.tls then "websecure" else "web"}"
          "DIAGRAMS_NET_TLS=${if cfg.tls then "true" else "false"}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
