{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.promtailCompose;
  serviceName = "promtail";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  portType = lib.types.ints.between 1 65535;
  syslogScrapeConfig = lib.optionalString cfg.syslog.enable (
    lib.concatStringsSep "\n" [
      "  - job_name: syslog-receiver"
      "    syslog:"
      "      listen_address: ${cfg.syslog.listenAddress}"
      "      idle_timeout: 60s"
      "      label_structured_data: true"
      "      labels:"
      "        job: ${cfg.syslog.jobLabel}"
      "    relabel_configs:"
      "      - source_labels: ['__syslog_message_hostname']"
      "        target_label: host"
    ]
  );
in {
  options.services.promtailCompose = {
    enable = lib.mkEnableOption "Promtail log shipper (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "promtail";
      description = "Docker container name.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/promtail";
      description = "Persistent host path used for Promtail positions data.";
    };

    lokiPushUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Loki push endpoint URL (`/loki/api/v1/push`).";
      example = "http://loki.hhlab.home.arpa:3100/loki/api/v1/push";
    };

    httpPort = lib.mkOption {
      type = portType;
      default = 9080;
      description = "Promtail local HTTP listen port (health/metrics).";
    };

    journalMaxAge = lib.mkOption {
      type = lib.types.str;
      default = "12h";
      description = "Maximum age for journald entries scraped by Promtail.";
    };

    syslog = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable a Promtail syslog receiver for external log senders (for example DSM).";
      };

      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0:1514";
        example = "0.0.0.0:1514";
        description = "Listen address for Promtail syslog receiver (`host:port`).";
      };

      jobLabel = lib.mkOption {
        type = lib.types.str;
        default = "synology-file-activity";
        description = "Value used for the Loki `job` label on syslog-ingested logs.";
      };
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "grafana/promtail";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "3.1.1";
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
        assertion = cfg.lokiPushUrl != null;
        message = "services.promtailCompose.lokiPushUrl must be set when enabling Promtail.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.promtailCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.promtailCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.promtailCompose.image.tag must be pinned (not `latest`) unless services.promtailCompose.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.promtailCompose.dataDir must be an absolute path.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    environment.etc."${serviceName}/config.yml".text = ''
      server:
        http_listen_port: ${toString cfg.httpPort}
        grpc_listen_port: 0

      positions:
        filename: /var/lib/promtail/positions.yaml

      clients:
        - url: ${cfg.lokiPushUrl}

      scrape_configs:
        - job_name: journal
          journal:
            max_age: ${cfg.journalMaxAge}
            path: /run/log/journal
            labels:
              job: systemd-journal
          relabel_configs:
            - source_labels: ['__journal__hostname']
              target_label: host
      ${syslogScrapeConfig}
    '';

    systemd.services.${serviceName} = {
      description = "Promtail log shipper (Docker Compose)";

      wantedBy = [ "multi-user.target" ];
      after = [ "docker.service" "network-online.target" ];
      wants = [ "network-online.target" ];
      restartTriggers = [
        config.environment.etc."${serviceName}/docker-compose.yml".source
        config.environment.etc."${serviceName}/config.yml".source
      ];
      startLimitBurst = 3;
      startLimitIntervalSec = 300;

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = 180;
        Restart = "on-failure";
        RestartSec = 10;
        WorkingDirectory = composeDir;

        Environment = [
          "PROMTAIL_CONTAINER_NAME=${cfg.containerName}"
          "PROMTAIL_IMAGE_REPOSITORY=${cfg.image.repository}"
          "PROMTAIL_IMAGE_TAG=${cfg.image.tag}"
          "PROMTAIL_DATA_DIR=${cfg.dataDir}"
          "PROMTAIL_HTTP_PORT=${toString cfg.httpPort}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${cfg.dataDir} && chmod 0750 ${cfg.dataDir}'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/config.yml'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"promtail: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
