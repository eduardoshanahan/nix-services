{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.grafanaCompose;
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};
  runtimeSecretEnv = import ../../lib/runtime-secret-env.nix {inherit lib pkgs;};
  serviceName = "grafana";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
  backupScript = pkgs.writeShellScript "grafana-backup" ''
    set -euo pipefail

    src=${lib.escapeShellArg cfg.dataDir}
    dst=${lib.escapeShellArg cfg.backup.targetDir}
    keep_days=${toString cfg.backup.keepDays}

    if [[ ! -d "$src" ]]; then
      echo "grafana-backup: source directory not found: $src" >&2
      exit 1
    fi

    install -d -m 0750 "$dst"

    stamp="$(${pkgs.coreutils}/bin/date -u +%Y%m%dT%H%M%SZ)"
    archive="$dst/grafana-$stamp.tar.zst"

    ${pkgs.gnutar}/bin/tar \
      --use-compress-program="${pkgs.zstd}/bin/zstd -T0 -19" \
      -cf "$archive" \
      -C "$src" .

    ${pkgs.findutils}/bin/find "$dst" -maxdepth 1 -type f -name 'grafana-*.tar.zst' -mtime "+$keep_days" -delete
  '';
  datasourcesYaml =
    lib.concatStringsSep "\n" (
      [
        "apiVersion: 1"
        "datasources:"
        "  - name: Prometheus"
        "    uid: prometheus"
        "    type: prometheus"
        "    access: proxy"
        "    url: ${cfg.provisioning.datasources.prometheus.url}"
        "    isDefault: true"
        "    editable: false"
        "    jsonData:"
        "      timeInterval: 15s"
      ]
      ++ lib.optionals (cfg.provisioning.datasources.loki.url != null) [
        "  - name: Loki"
        "    uid: loki"
        "    type: loki"
        "    access: proxy"
        "    url: ${cfg.provisioning.datasources.loki.url}"
        "    editable: false"
      ]
    )
    + "\n";
  dashboardsProviderYaml = ''
    apiVersion: 1
    providers:
      - name: Homelab
        orgId: 1
        folder: Homelab
        type: file
        disableDeletion: false
        editable: true
        options:
          path: /etc/grafana/provisioning/dashboards
  '';
  starterDashboardJson = builtins.toJSON {
    id = null;
    uid = "homelab-overview";
    title = "Homelab Overview";
    tags = [ "homelab" "starter" ];
    timezone = "browser";
    schemaVersion = 39;
    version = 1;
    refresh = "30s";
    time = {
      from = "now-6h";
      to = "now";
    };
    editable = true;
    panels = [
      {
        id = 1;
        type = "stat";
        title = "Targets Up";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 0;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          justifyMode = "auto";
          orientation = "auto";
          reduceOptions = {
            calcs = [ "lastNotNull" ];
            fields = "";
            values = false;
          };
          textMode = "auto";
        };
        targets = [
          {
            expr = "sum(up)";
            refId = "A";
          }
        ];
      }
      {
        id = 2;
        type = "timeseries";
        title = "HTTP 5xx Rate (Traefik)";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 9;
          w = 18;
          x = 6;
          y = 0;
        };
        targets = [
          {
            expr = "sum(rate(traefik_service_requests_total{code=~\"5..\"}[5m])) by (code)";
            legendFormat = "{{code}}";
            refId = "A";
          }
        ];
      }
      {
        id = 3;
        type = "timeseries";
        title = "CPU Usage % (Nodes)";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 9;
          w = 12;
          x = 0;
          y = 6;
        };
        targets = [
          {
            expr = "100 - (avg by (instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
      }
      {
        id = 4;
        type = "timeseries";
        title = "Memory Available % (Nodes)";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 9;
          w = 12;
          x = 12;
          y = 9;
        };
        targets = [
          {
            expr = "(node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
      }
    ];
  };
  healthcheckScript = pkgs.writeShellScript "grafana-healthcheck" ''
    set -euo pipefail

    service_name=${serviceName}
    container_name=${cfg.containerName}

    if ! systemctl is-active --quiet "$service_name"; then
      echo "grafana-healthcheck: systemd service $service_name is not active" >&2
      exit 1
    fi

    status="$(${dockerBin} inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_name" 2>/dev/null || true)"
    if [ "$status" != "healthy" ]; then
      echo "grafana-healthcheck: container health is '$status' (expected 'healthy')" >&2
      ${dockerBin} ps --filter "name=^/$container_name$" --format 'table {{.Names}}\t{{.Status}}' >&2 || true
      exit 1
    fi
  '';

  waitForHealthy = pkgs.writeShellScript "grafana-wait-healthy" ''
    set -euo pipefail

    container_name=${cfg.containerName}
    timeout_seconds=120
    deadline=$((SECONDS + timeout_seconds))

    while true; do
      status="$(${dockerBin} inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_name" 2>/dev/null || true)"

      case "$status" in
        healthy)
          exit 0
          ;;
        unhealthy)
          echo "grafana: container became unhealthy" >&2
          ${dockerBin} ps --filter "name=^/$container_name$" --format 'table {{.Names}}\t{{.Status}}' >&2 || true
          exit 1
          ;;
        starting|none|"")
          ;;
        *)
          echo "grafana: unexpected health status: $status" >&2
          ;;
      esac

      if [ "$SECONDS" -ge "$deadline" ]; then
        echo "grafana: timed out waiting for a healthy container (''${timeout_seconds}s)" >&2
        ${dockerBin} ps --filter "name=^/$container_name$" --format 'table {{.Names}}\t{{.Status}}' >&2 || true
        exit 1
      fi

      sleep 2
    done
  '';
in {
  options.services.grafanaCompose = {
    enable = lib.mkEnableOption "Grafana service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "grafana";
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

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/grafana";
      description = "Persistent host path used for Grafana data.";
    };

    adminPasswordFile = runtimeSecrets.mkSecretFileOption {
      description = ''
        Absolute path to a runtime-provisioned file containing the Grafana admin password.
      '';
      example = "/run/secrets/grafana-admin-password";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "grafana/grafana";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "11.2.0";
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

    tls = lib.mkEnableOption "TLS on the Grafana Traefik router";

    monitoring = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable periodic service/container health checks via systemd timer.";
      };

      interval = lib.mkOption {
        type = lib.types.str;
        default = "5m";
        description = "How often to run the Grafana healthcheck (for example `5m`).";
      };
    };

    backup = {
      enable = lib.mkEnableOption "periodic Grafana data backups";

      targetDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/backups/grafana";
        description = "Directory where compressed Grafana backup archives are written.";
      };

      schedule = lib.mkOption {
        type = lib.types.str;
        default = "daily";
        description = "Systemd OnCalendar expression for Grafana backups.";
      };

      keepDays = lib.mkOption {
        type = lib.types.ints.positive;
        default = 14;
        description = "How many days of backup archives to keep.";
      };
    };

    provisioning = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable declarative provisioning for Grafana datasources and starter dashboards.";
      };

      datasources = {
        prometheus = {
          url = lib.mkOption {
            type = lib.types.str;
            default = "http://prometheus:9090";
            description = "Prometheus URL used by provisioned Grafana datasource.";
          };
        };

        loki = {
          url = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "http://loki.hhlab.home.arpa:3100";
            description = "Optional Loki URL for a provisioned Grafana datasource.";
          };
        };
      };

      dashboards = {
        enableStarter = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Provision a starter Homelab overview dashboard.";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.grafanaCompose.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.grafanaCompose.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.grafanaCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.grafanaCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.grafanaCompose.image.tag must be pinned (not `latest`) unless services.grafanaCompose.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.grafanaCompose.dataDir must be an absolute path.";
      }
      {
        assertion = cfg.adminPasswordFile != null;
        message = "services.grafanaCompose.adminPasswordFile must be set when enabling Grafana.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.backup.targetDir;
        message = "services.grafanaCompose.backup.targetDir must be an absolute path.";
      }
      {
        assertion = !cfg.backup.enable || (!lib.hasPrefix "${cfg.dataDir}/" cfg.backup.targetDir && cfg.backup.targetDir != cfg.dataDir);
        message = "services.grafanaCompose.backup.targetDir must not be inside services.grafanaCompose.dataDir.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;
    environment.etc."${serviceName}/provisioning/datasources/datasources.yml" = lib.mkIf cfg.provisioning.enable {
      text = datasourcesYaml;
      mode = "0444";
    };
    environment.etc."${serviceName}/provisioning/dashboards/providers.yml" = lib.mkIf cfg.provisioning.enable {
      text = dashboardsProviderYaml;
      mode = "0444";
    };
    environment.etc."${serviceName}/provisioning/dashboards/homelab-overview.json" = lib.mkIf (cfg.provisioning.enable && cfg.provisioning.dashboards.enableStarter) {
      text = starterDashboardJson;
      mode = "0444";
    };

    systemd.services.${serviceName} = {
      description = "Grafana (Docker Compose)";

      wantedBy = ["multi-user.target"];
      requires = ["docker.service"];
      after = ["docker.service" "network-online.target"];
      wants = ["network-online.target"];
      restartTriggers = lib.optionals cfg.provisioning.enable [
        config.environment.etc."${serviceName}/provisioning/datasources/datasources.yml".source
        config.environment.etc."${serviceName}/provisioning/dashboards/providers.yml".source
      ] ++ lib.optionals (cfg.provisioning.enable && cfg.provisioning.dashboards.enableStarter) [
        config.environment.etc."${serviceName}/provisioning/dashboards/homelab-overview.json".source
      ] ++ [
        config.environment.etc."${serviceName}/docker-compose.yml".source
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
          "GRAFANA_CONTAINER_NAME=${cfg.containerName}"
          "GRAFANA_IMAGE_REPOSITORY=${cfg.image.repository}"
          "GRAFANA_IMAGE_TAG=${cfg.image.tag}"
          "GRAFANA_NETWORK=${cfg.network}"
          "GRAFANA_HOSTNAME=${cfg.hostname}"
          "GRAFANA_ENTRYPOINTS=${if cfg.tls then "websecure" else "web"}"
          "GRAFANA_TLS=${if cfg.tls then "true" else "false"}"
          "GRAFANA_DATA_DIR=${cfg.dataDir}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${cfg.dataDir} && chown 472:472 ${cfg.dataDir} && chmod 0750 ${cfg.dataDir}'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
        ] ++ lib.optionals cfg.provisioning.enable [
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/provisioning/datasources/datasources.yml'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/provisioning/dashboards/providers.yml'"
        ] ++ lib.optionals (cfg.provisioning.enable && cfg.provisioning.dashboards.enableStarter) [
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/provisioning/dashboards/homelab-overview.json'"
        ] ++ [
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"grafana: docker daemon is not ready\" >&2; exit 1'"
          (runtimeSecretEnv.mkRuntimeSecretEnvExecStartPre {
            name = serviceName;
            secretFile = cfg.adminPasswordFile;
            envVar = "GF_SECURITY_ADMIN_PASSWORD";
          })
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStartPost = waitForHealthy;
        ExecStop = "${dockerBin} compose down";
      };
    };

    systemd.services."${serviceName}-healthcheck" = lib.mkIf cfg.monitoring.enable {
      description = "Grafana periodic healthcheck";
      after = ["${serviceName}.service"];
      requires = ["${serviceName}.service"];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = healthcheckScript;
      };
    };

    systemd.timers."${serviceName}-healthcheck" = lib.mkIf cfg.monitoring.enable {
      description = "Run Grafana periodic healthcheck";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "2m";
        OnUnitActiveSec = cfg.monitoring.interval;
        Unit = "${serviceName}-healthcheck.service";
      };
    };

    systemd.services."${serviceName}-backup" = lib.mkIf cfg.backup.enable {
      description = "Backup Grafana data";
      after = [ "${serviceName}.service" ];
      requires = [ "${serviceName}.service" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = backupScript;
      };
    };

    systemd.timers."${serviceName}-backup" = lib.mkIf cfg.backup.enable {
      description = "Periodic Grafana backup";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.backup.schedule;
        Persistent = true;
        Unit = "${serviceName}-backup.service";
      };
    };
  };
}
