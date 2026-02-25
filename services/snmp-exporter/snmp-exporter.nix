{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.snmpExporterCompose;
  serviceName = "snmp-exporter";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  portType = lib.types.ints.between 1 65535;
in {
  options.services.snmpExporterCompose = {
    enable = lib.mkEnableOption "Prometheus SNMP exporter (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "snmp-exporter";
      description = "Docker container name.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Host listen address for SNMP exporter metrics endpoint.";
      example = "127.0.0.1";
    };

    listenPort = lib.mkOption {
      type = portType;
      default = 9116;
      description = "Host TCP port mapped to exporter port 9116.";
    };

    logLevel = lib.mkOption {
      type = lib.types.enum [ "debug" "info" "warn" "error" ];
      default = "info";
      description = "Exporter log level.";
    };

    snmpV2Community = lib.mkOption {
      type = lib.types.str;
      default = "public";
      description = ''
        SNMP v1/v2c community written into exporter auth profiles
        `public_v1` and `public_v2`.
      '';
      example = "7fjeuibngymx";
    };

    configFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/snmp-exporter/snmp.yml";
      description = "Writable host path for rendered SNMP exporter config file.";
      example = "/var/lib/snmp-exporter/snmp.yml";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "prom/snmp-exporter";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "v0.29.0";
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
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.snmpExporterCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.snmpExporterCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.snmpExporterCompose.image.tag must be pinned (not `latest`) unless services.snmpExporterCompose.image.allowMutableTag = true.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.snmpV2Community != null;
        message = "services.snmpExporterCompose.snmpV2Community must not contain whitespace.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.configFile;
        message = "services.snmpExporterCompose.configFile must be an absolute path.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "Prometheus SNMP exporter (Docker Compose)";
      wantedBy = [ "multi-user.target" ];
      after = [ "docker.service" "network-online.target" ];
      wants = [ "network-online.target" ];
      restartTriggers = [
        config.environment.etc."${serviceName}/docker-compose.yml".source
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = composeDir;
        TimeoutStartSec = 180;

        Environment = [
          "SNMP_EXPORTER_CONTAINER_NAME=${cfg.containerName}"
          "SNMP_EXPORTER_LISTEN_ADDRESS=${cfg.listenAddress}"
          "SNMP_EXPORTER_LISTEN_PORT=${toString cfg.listenPort}"
          "SNMP_EXPORTER_LOG_LEVEL=${cfg.logLevel}"
          "SNMP_EXPORTER_CONFIG_FILE=${cfg.configFile}"
          "SNMP_EXPORTER_IMAGE_REPOSITORY=${cfg.image.repository}"
          "SNMP_EXPORTER_IMAGE_TAG=${cfg.image.tag}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"snmp-exporter: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c 'mkdir -p \"$(dirname ${cfg.configFile})\"'"
          "${pkgs.runtimeShell} -c '${dockerBin} run --rm --entrypoint cat ${cfg.image.repository}:${cfg.image.tag} /etc/snmp_exporter/snmp.yml > ${cfg.configFile}.tmp'"
          "${pkgs.runtimeShell} -c '${pkgs.gnused}/bin/sed -i \"s/community: public/community: ${cfg.snmpV2Community}/g\" ${cfg.configFile}.tmp && mv ${cfg.configFile}.tmp ${cfg.configFile}'"
          "${pkgs.runtimeShell} -c 'test -s ${cfg.configFile}'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
