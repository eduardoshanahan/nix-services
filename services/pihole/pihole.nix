{ config, lib, pkgs, ... }:

let
  cfg = config.services.pihole;

  serviceName = "pihole";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";

  uiHostname =
    if cfg.uiHostname != null then cfg.uiHostname else "pihole-${cfg.role}.local";

  containerName =
    if cfg.containerName != null then cfg.containerName else "pihole-${cfg.role}";

  composeFiles =
    [ "-f docker-compose.yml" ]
    ++ lib.optionals cfg.publishDnsPorts [ "-f docker-compose.dns.yml" ];

  composeFileArgs = lib.concatStringsSep " " composeFiles;

  dnsPortsOverride = pkgs.writeText "pihole-docker-compose.dns.yml" ''
    version: "3.9"

    services:
      pihole:
        ports:
          - "53:53/tcp"
          - "53:53/udp"
  '';
in
{
  options.services.pihole = {
    role = lib.mkOption {
      type = lib.types.enum [ "primary" "secondary" ];
      default = "primary";
      description = "Non-secret role tag used to derive defaults such as UI hostname and container name.";
    };

    uiHostname = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        UI hostname used by the Traefik router rule.

        Pre-DNS access: add an `/etc/hosts` entry on your client pointing this name at the target box IP,
        then browse to `http://<uiHostname>/` (Traefik `web` entrypoint).
      '';
    };

    containerName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Docker container name (defaults to `pihole-<role>`).";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/pihole";
      description = ''
        Persistent state directory on the host.

        Expected contents:
        - `<dataDir>/etc-pihole` -> `/etc/pihole`
        - `<dataDir>/etc-dnsmasq.d` -> `/etc/dnsmasq.d`
      '';
    };

    envFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/secrets/pihole.env";
      description = ''
        External env file path (not in this repo) consumed by Docker Compose.

        Secrets MUST be provided via this file or a private overlay; do not commit credentials.
      '';
    };

    traefikNetwork = lib.mkOption {
      type = lib.types.str;
      default = "traefik";
      description = "External Docker network name shared with Traefik.";
    };

    publishDnsPorts = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to publish Pi-hole DNS on host port 53 (TCP/UDP).

        This MUST remain `false` during the pre-DNS UI validation phase. DNS cutover is manual and documented only.
      '';
    };
  };

  config = {
    virtualisation.docker.enable = true;

    environment.systemPackages = [
      pkgs.docker-compose
    ];

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root -"
      "d ${cfg.dataDir}/etc-pihole 0755 root root -"
      "d ${cfg.dataDir}/etc-dnsmasq.d 0755 root root -"
    ];

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;
    environment.etc."${serviceName}/docker-compose.dns.yml".source = dnsPortsOverride;

    systemd.services.${serviceName} = {
      description = "Pi-hole (Docker Compose, behind Traefik)";

      wantedBy = [ "multi-user.target" ];
      after = [ "docker.service" "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        WorkingDirectory = composeDir;

        Environment = [
          "PIHOLE_CONTAINER_NAME=${containerName}"
          "PIHOLE_UI_HOSTNAME=${uiHostname}"
          "PIHOLE_DATA_DIR=${cfg.dataDir}"
          "PIHOLE_ENV_FILE=${cfg.envFile}"
          "PIHOLE_TRAEFIK_NETWORK=${cfg.traefikNetwork}"
          "TZ=${config.time.timeZone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.traefikNetwork} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.traefikNetwork}'"
        ];

        ExecStart = "${dockerBin} compose ${composeFileArgs} up";
        ExecStop = "${dockerBin} compose ${composeFileArgs} down";

        Restart = "always";
        RestartSec = "5s";
      };
    };
  };
}
