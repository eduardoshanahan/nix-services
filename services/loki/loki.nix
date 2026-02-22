{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.lokiCompose;
  serviceName = "loki";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  portType = lib.types.ints.between 1 65535;
in {
  options.services.lokiCompose = {
    enable = lib.mkEnableOption "Loki log aggregation service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "loki";
      description = "Docker container name.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/loki";
      description = "Persistent host path used for Loki data.";
    };

    httpPort = lib.mkOption {
      type = portType;
      default = 3100;
      description = "Host TCP port published for Loki HTTP API.";
    };

    retentionPeriod = lib.mkOption {
      type = lib.types.str;
      default = "30d";
      description = "Loki retention period.";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "grafana/loki";
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
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.lokiCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.lokiCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.lokiCompose.image.tag must be pinned (not `latest`) unless services.lokiCompose.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.lokiCompose.dataDir must be an absolute path.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    environment.etc."${serviceName}/config.yaml".text = ''
      auth_enabled: false

      server:
        http_listen_port: 3100

      common:
        path_prefix: /loki
        storage:
          filesystem:
            chunks_directory: /loki/chunks
            rules_directory: /loki/rules
        replication_factor: 1
        ring:
          kvstore:
            store: inmemory

      schema_config:
        configs:
          - from: 2024-01-01
            store: tsdb
            object_store: filesystem
            schema: v13
            index:
              prefix: index_
              period: 24h

      limits_config:
        retention_period: ${cfg.retentionPeriod}

      compactor:
        working_directory: /loki/compactor
        retention_enabled: true
        delete_request_store: filesystem
    '';

    systemd.services.${serviceName} = {
      description = "Loki log aggregation service (Docker Compose)";

      wantedBy = ["multi-user.target"];
      after = ["docker.service" "network-online.target"];
      wants = ["network-online.target"];
      restartTriggers = [
        config.environment.etc."${serviceName}/docker-compose.yml".source
        config.environment.etc."${serviceName}/config.yaml".source
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
          "LOKI_CONTAINER_NAME=${cfg.containerName}"
          "LOKI_IMAGE_REPOSITORY=${cfg.image.repository}"
          "LOKI_IMAGE_TAG=${cfg.image.tag}"
          "LOKI_HTTP_PORT=${toString cfg.httpPort}"
          "LOKI_DATA_DIR=${cfg.dataDir}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${cfg.dataDir} && chown 10001:10001 ${cfg.dataDir} && chmod 0750 ${cfg.dataDir}'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/config.yaml'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"loki: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
