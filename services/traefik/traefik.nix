{ config, lib, pkgs, ... }:

let
  cfg = config.services.traefik;

  serviceName = "traefik";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
in
{
  options.services.traefik = {
    uiHostname = lib.mkOption {
      type = lib.types.str;
      default = "traefik.local";
      description = ''
        Reserved hostname for future operator-validated UI exposure (not used while API/dashboard are disabled).
      '';
    };

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "traefik";
      description = "Docker container name.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/traefik";
      description = "Legacy persistent Traefik state directory path (not used; no `/data` mount is configured).";
    };

    network = lib.mkOption {
      type = lib.types.str;
      default = "traefik";
      description = "External Docker network name used by Traefik and downstream services.";
    };
  };

  config = {
    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "Traefik ingress (Docker Compose)";

      wantedBy = [ "multi-user.target" ];
      after = [ "docker.service" "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;

        WorkingDirectory = composeDir;

        Environment = [
          "TRAEFIK_CONTAINER_NAME=${cfg.containerName}"
          "TRAEFIK_NETWORK=${cfg.network}"
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
