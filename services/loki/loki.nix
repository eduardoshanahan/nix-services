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
  backupScript = pkgs.writeShellScript "loki-backup" ''
    set -euo pipefail

    src=${lib.escapeShellArg cfg.dataDir}
    dst=${lib.escapeShellArg cfg.backup.targetDir}
    keep_days=${toString cfg.backup.keepDays}

    if [[ ! -d "$src" ]]; then
      echo "loki-backup: source directory not found: $src" >&2
      exit 1
    fi

    install -d -m 0750 "$dst"

    stamp="$(${pkgs.coreutils}/bin/date -u +%Y%m%dT%H%M%SZ)"
    archive="$dst/loki-$stamp.tar.zst"

    ${pkgs.gnutar}/bin/tar \
      --use-compress-program="${pkgs.zstd}/bin/zstd -T0 -19" \
      -cf "$archive" \
      -C "$src" .

    ${pkgs.findutils}/bin/find "$dst" -maxdepth 1 -type f -name 'loki-*.tar.zst' -mtime "+$keep_days" -delete
  '';
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

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = ''
        Host IP address used for the published Loki port binding.
        Set this to a LAN IP (for example `192.168.1.10`) to avoid broad exposure.
      '';
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

    backup = {
      enable = lib.mkEnableOption "periodic Loki data backups";

      targetDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/backups/loki";
        description = "Directory where compressed Loki backup archives are written.";
      };

      schedule = lib.mkOption {
        type = lib.types.str;
        default = "daily";
        description = "Systemd OnCalendar expression for Loki backups.";
      };

      keepDays = lib.mkOption {
        type = lib.types.ints.positive;
        default = 14;
        description = "How many days of backup archives to keep.";
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
      {
        assertion = lib.hasPrefix "/" cfg.backup.targetDir;
        message = "services.lokiCompose.backup.targetDir must be an absolute path.";
      }
      {
        assertion = !cfg.backup.enable || (!lib.hasPrefix "${cfg.dataDir}/" cfg.backup.targetDir && cfg.backup.targetDir != cfg.dataDir);
        message = "services.lokiCompose.backup.targetDir must not be inside services.lokiCompose.dataDir.";
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
          "LOKI_LISTEN_ADDRESS=${cfg.listenAddress}"
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

    systemd.services."${serviceName}-backup" = lib.mkIf cfg.backup.enable {
      description = "Backup Loki data";
      after = [ "${serviceName}.service" ];
      requires = [ "${serviceName}.service" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = backupScript;
      };
    };

    systemd.timers."${serviceName}-backup" = lib.mkIf cfg.backup.enable {
      description = "Periodic Loki backup";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.backup.schedule;
        Persistent = true;
        Unit = "${serviceName}-backup.service";
      };
    };
  };
}
