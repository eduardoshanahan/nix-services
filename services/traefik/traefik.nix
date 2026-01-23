{ config, pkgs, ... }:

let
  serviceName = "traefik";
  composeDir = "/etc/${serviceName}";
  networkName = "traefik";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
in
{
  virtualisation.docker.enable = true;

  environment.systemPackages = [
    pkgs.docker-compose
  ];

  systemd.tmpfiles.rules = [
    "d /var/lib/${serviceName} 0755 root root -"
  ];

  environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

  systemd.services.${serviceName} = {
    description = "Traefik ingress (Docker Compose)";

    wantedBy = [ "multi-user.target" ];
    after = [ "docker.service" "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      WorkingDirectory = composeDir;

      ExecStartPre = [
        "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${networkName} >/dev/null 2>&1 || ${dockerBin} network create ${networkName}'"
      ];

      ExecStart = "${dockerBin} compose up";
      ExecStop = "${dockerBin} compose down";

      Restart = "always";
      RestartSec = "5s";
    };
  };
}

