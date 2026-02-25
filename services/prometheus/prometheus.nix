{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.prometheusCompose;
  serviceName = "prometheus";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";

  mkTargetLines = {
    targets,
    indent,
  }:
    map (target: "${indent}- \"${target}\"") targets;

  optionalJobLines = {
    name,
    targets,
  }:
    lib.optionals (targets != []) (
      [
        "  - job_name: \"${name}\""
        "    static_configs:"
        "      - targets:"
      ]
      ++ (mkTargetLines {
        inherit targets;
        indent = "        ";
      })
      ++ [""]
    );

  synologySnmpJobLines =
    lib.optionals (cfg.scrape.synologySnmpTargets != [] && cfg.scrape.synologySnmpExporterAddress != null) (
      [
        "  - job_name: \"synology-snmp\""
        "    metrics_path: /snmp"
        "    params:"
        "      module: [\"${cfg.scrape.synologySnmpModule}\"]"
        "      auth: [\"${cfg.scrape.synologySnmpAuth}\"]"
        "    static_configs:"
        "      - targets:"
      ]
      ++ (mkTargetLines {
        targets = cfg.scrape.synologySnmpTargets;
        indent = "        ";
      })
      ++ [
        "    relabel_configs:"
        "      - source_labels: [__address__]"
        "        target_label: __param_target"
        "      - source_labels: [__param_target]"
        "        target_label: instance"
        "      - target_label: __address__"
        "        replacement: ${cfg.scrape.synologySnmpExporterAddress}"
        ""
      ]
    );

  mkSnmpJobLines = {
    jobName,
    module,
    auth,
    targets,
  }:
    lib.optionals (targets != [] && cfg.scrape.synologySnmpExporterAddress != null) (
      [
        "  - job_name: \"${jobName}\""
        "    metrics_path: /snmp"
        "    params:"
        "      module: [\"${module}\"]"
        "      auth: [\"${auth}\"]"
        "    static_configs:"
        "      - targets:"
      ]
      ++ (mkTargetLines {
        inherit targets;
        indent = "        ";
      })
      ++ [
        "    relabel_configs:"
        "      - source_labels: [__address__]"
        "        target_label: __param_target"
        "      - source_labels: [__param_target]"
        "        target_label: instance"
        "      - target_label: __address__"
        "        replacement: ${cfg.scrape.synologySnmpExporterAddress}"
        ""
      ]
    );

  alertingLines = targets:
    lib.optionals (targets != []) (
      [
        "alerting:"
        "  alertmanagers:"
        "    - static_configs:"
        "        - targets:"
      ]
      ++ (mkTargetLines {
        inherit targets;
        indent = "          ";
      })
      ++ [""]
    );

  prometheusConfigText =
    lib.concatStringsSep "\n" (
      [
        "global:"
        "  scrape_interval: 15s"
        "  evaluation_interval: 15s"
        ""
        "rule_files:"
        "  - /etc/prometheus/alert.rules.yml"
        ""
      ]
      ++ lib.optionals cfg.alerting.enable (alertingLines cfg.alerting.targets)
      ++ [
        "scrape_configs:"
        "  - job_name: \"prometheus\""
        "    static_configs:"
        "      - targets: [\"127.0.0.1:9090\"]"
        ""
      ]
      ++ (optionalJobLines {
        name = "nodes";
        targets = cfg.scrape.nodeTargets;
      })
      ++ (optionalJobLines {
        name = "synology-nodes";
        targets = cfg.scrape.synologyNodeTargets;
      })
      ++ (if cfg.scrape.synologySnmpExporterAddress != null then synologySnmpJobLines else (optionalJobLines {
        name = "synology-snmp";
        targets = cfg.scrape.synologySnmpTargets;
      }))
      ++ (mkSnmpJobLines {
        jobName = "synology-snmp-system";
        module = cfg.scrape.synologySnmpSystemModule;
        auth = cfg.scrape.synologySnmpAuth;
        targets = cfg.scrape.synologySnmpSystemTargets;
      })
      ++ (mkSnmpJobLines {
        jobName = "synology-snmp-memory";
        module = cfg.scrape.synologySnmpMemoryModule;
        auth = cfg.scrape.synologySnmpAuth;
        targets = cfg.scrape.synologySnmpMemoryTargets;
      })
      ++ (mkSnmpJobLines {
        jobName = "synology-snmp-storage";
        module = cfg.scrape.synologySnmpStorageModule;
        auth = cfg.scrape.synologySnmpAuth;
        targets = cfg.scrape.synologySnmpStorageTargets;
      })
      ++ (mkSnmpJobLines {
        jobName = "synology-snmp-network";
        module = cfg.scrape.synologySnmpNetworkModule;
        auth = cfg.scrape.synologySnmpAuth;
        targets = cfg.scrape.synologySnmpNetworkTargets;
      })
      ++ (mkSnmpJobLines {
        jobName = "synology-snmp-load";
        module = cfg.scrape.synologySnmpLoadModule;
        auth = cfg.scrape.synologySnmpAuth;
        targets = cfg.scrape.synologySnmpLoadTargets;
      })
      ++ (mkSnmpJobLines {
        jobName = "synology-snmp-uptime";
        module = cfg.scrape.synologySnmpUptimeModule;
        auth = cfg.scrape.synologySnmpAuth;
        targets = cfg.scrape.synologySnmpUptimeTargets;
      })
      ++ (optionalJobLines {
        name = "loki";
        targets = cfg.scrape.lokiTargets;
      })
      ++ (optionalJobLines {
        name = "traefik";
        targets = cfg.scrape.traefikTargets;
      })
      ++ (optionalJobLines {
        name = "promtail";
        targets = cfg.scrape.promtailTargets;
      })
      ++ (optionalJobLines {
        name = "grafana";
        targets = cfg.scrape.grafanaTargets;
      })
      ++ (optionalJobLines {
        name = "pihole-exporter";
        targets = cfg.scrape.piholeExporterTargets;
      })
      ++ (optionalJobLines {
        name = "alertmanager";
        targets = cfg.scrape.alertmanagerTargets;
      })
    )
    + "\n";

  alertRulesText =
    lib.concatStringsSep "\n" [
      "groups:"
      "  - name: homelab-core"
      "    rules:"
      "      - alert: TargetDown"
      "        expr: up == 0"
      "        for: 2m"
      "        labels:"
      "          severity: critical"
      "        annotations:"
      "          summary: \"Target down ({{ $labels.job }})\""
      "          description: \"Scrape target {{ $labels.instance }} has been down for more than 2 minutes.\""
      ""
      "      - alert: PrometheusConfigReloadFailed"
      "        expr: prometheus_config_last_reload_successful == 0"
      "        for: 5m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"Prometheus config reload failed\""
      "          description: \"Prometheus failed to reload its configuration on {{ $labels.instance }}.\""
      ""
      "      - alert: NodeHighCpuUsage"
      "        expr: (100 - (avg by (instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)) > 85"
      "        for: 10m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"High CPU usage on {{ $labels.instance }}\""
      "          description: \"CPU usage has been above 85% for 10 minutes.\""
      ""
      "      - alert: NodeLowMemory"
      "        expr: ((node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100) < 10"
      "        for: 10m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"Low memory on {{ $labels.instance }}\""
      "          description: \"Available memory is below 10% for 10 minutes.\""
      ""
      "      - alert: NodeLowDiskRoot"
      "        expr: ((node_filesystem_avail_bytes{mountpoint=\"/\",fstype!~\"tmpfs|overlay\"} / node_filesystem_size_bytes{mountpoint=\"/\",fstype!~\"tmpfs|overlay\"}) * 100) < 15"
      "        for: 15m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"Low root disk space on {{ $labels.instance }}\""
      "          description: \"Root filesystem free space is below 15% for 15 minutes.\""
      ""
      "      - alert: TraefikHigh5xxRate"
      "        expr: sum by (instance) (rate(traefik_service_requests_total{code=~\"5..\"}[5m])) > 0.1"
      "        for: 10m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"Traefik high 5xx rate on {{ $labels.instance }}\""
      "          description: \"Traefik is returning more than 0.1 5xx responses/second for 10 minutes.\""
    ]
    + "\n";
in {
  options.services.prometheusCompose = {
    enable = lib.mkEnableOption "Prometheus service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "prometheus";
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
      default = "/var/lib/prometheus";
      description = "Persistent host path used for Prometheus TSDB data.";
    };

    retentionTime = lib.mkOption {
      type = lib.types.str;
      default = "30d";
      description = "Prometheus TSDB retention time (for example `30d`).";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "prom/prometheus";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "v2.55.1";
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

    scrape = {
      nodeTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = [ "rpi-box-01.hhlab.home.arpa:9100" "rpi-box-02.hhlab.home.arpa:9100" ];
        description = "Node exporter targets (`host:port`).";
      };

      synologyNodeTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = [ "hhnas4.hhlab.home.arpa:9100" ];
        description = ''
          Synology NAS node-exporter targets (`host:port`), scraped under job
          `synology-nodes`.
        '';
      };

      synologySnmpTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = [ "hhnas4.hhlab.home.arpa" "nas2.hhlab.home.arpa" ];
        description = ''
          Synology SNMP device targets (`host` or `host:port`), scraped under
          job `synology-snmp`.
        '';
      };

      synologySnmpExporterAddress = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "snmp-exporter.hhlab.home.arpa:9116";
        description = ''
          SNMP exporter endpoint (`host:port`) used to scrape
          `services.prometheusCompose.scrape.synologySnmpTargets` via `/snmp`.
          When null, targets are scraped directly as generic Prometheus
          endpoints for backward compatibility.
        '';
      };

      synologySnmpModule = lib.mkOption {
        type = lib.types.str;
        default = "synology";
        example = "synology";
        description = "SNMP exporter module used for Synology SNMP scrape requests.";
      };

      synologySnmpAuth = lib.mkOption {
        type = lib.types.str;
        default = "public_v2";
        example = "public_v2";
        description = "SNMP exporter auth profile used for Synology SNMP scrape requests.";
      };

      synologySnmpSystemTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = [ "nas2.hhlab.home.arpa" ];
        description = ''
          Synology SNMP targets scraped under job `synology-snmp-system` for
          CPU/system metrics (for example `ssCpuIdle`).
        '';
      };

      synologySnmpSystemModule = lib.mkOption {
        type = lib.types.str;
        default = "ucd_system_stats";
        example = "ucd_system_stats";
        description = "SNMP exporter module used for `synology-snmp-system`.";
      };

      synologySnmpMemoryTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = [ "nas2.hhlab.home.arpa" ];
        description = ''
          Synology SNMP targets scraped under job `synology-snmp-memory` for
          memory metrics (for example `memTotalReal`, `memAvailReal`).
        '';
      };

      synologySnmpMemoryModule = lib.mkOption {
        type = lib.types.str;
        default = "ucd_memory";
        example = "ucd_memory";
        description = "SNMP exporter module used for `synology-snmp-memory`.";
      };

      synologySnmpStorageTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = [ "nas2.hhlab.home.arpa" ];
        description = ''
          Synology SNMP targets scraped under job `synology-snmp-storage` for
          filesystem metrics (for example `hrStorageUsed`, `hrStorageSize`).
        '';
      };

      synologySnmpStorageModule = lib.mkOption {
        type = lib.types.str;
        default = "hrStorage";
        example = "hrStorage";
        description = "SNMP exporter module used for `synology-snmp-storage`.";
      };

      synologySnmpNetworkTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = [ "nas2.hhlab.home.arpa" ];
        description = ''
          Synology SNMP targets scraped under job `synology-snmp-network` for
          interface throughput metrics (for example `ifHCInOctets`).
        '';
      };

      synologySnmpNetworkModule = lib.mkOption {
        type = lib.types.str;
        default = "if_mib";
        example = "if_mib";
        description = "SNMP exporter module used for `synology-snmp-network`.";
      };

      synologySnmpLoadTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = [ "nas2.hhlab.home.arpa" ];
        description = ''
          Synology SNMP targets scraped under job `synology-snmp-load` for load
          average metrics (for example `laLoadFloat`).
        '';
      };

      synologySnmpLoadModule = lib.mkOption {
        type = lib.types.str;
        default = "ucd_la_table";
        example = "ucd_la_table";
        description = "SNMP exporter module used for `synology-snmp-load`.";
      };

      synologySnmpUptimeTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = [ "nas2.hhlab.home.arpa" ];
        description = ''
          Synology SNMP targets scraped under job `synology-snmp-uptime` for
          uptime metrics (for example `hrSystemUptime`).
        '';
      };

      synologySnmpUptimeModule = lib.mkOption {
        type = lib.types.str;
        default = "hrSystem";
        example = "hrSystem";
        description = "SNMP exporter module used for `synology-snmp-uptime`.";
      };

      lokiTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = [ "loki.hhlab.home.arpa:3100" ];
        description = "Loki targets (`host:port`) to scrape.";
      };

      traefikTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = [ "rpi-box-01-metrics.hhlab.home.arpa:8082" "rpi-box-02-metrics.hhlab.home.arpa:8082" ];
        description = "Traefik metrics targets (`host:port`) to scrape.";
      };

      promtailTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = [ "rpi-box-01.hhlab.home.arpa:9080" "rpi-box-02.hhlab.home.arpa:9080" ];
        description = "Promtail targets (`host:port`) to scrape.";
      };

      piholeExporterTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = [ "rpi-box-01-metrics.hhlab.home.arpa:9617" ];
        description = "Pi-hole exporter targets (`host:port`) to scrape.";
      };

      grafanaTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = [ "grafana:3000" ];
        description = "Grafana metrics targets (`host:port`) to scrape.";
      };

      alertmanagerTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "alertmanager:9093" ];
        description = "Alertmanager targets (`host:port`) to scrape.";
      };
    };

    alerting = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Alertmanager integration in Prometheus config.";
      };

      targets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "alertmanager:9093" ];
        description = "Alertmanager targets (`host:port`) used under `alerting.alertmanagers`.";
      };
    };

    tls = lib.mkEnableOption "TLS on the Prometheus Traefik router";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.prometheusCompose.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.prometheusCompose.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.prometheusCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.prometheusCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.prometheusCompose.image.tag must be pinned (not `latest`) unless services.prometheusCompose.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.prometheusCompose.dataDir must be an absolute path.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    environment.etc."${serviceName}/prometheus.yml".text = prometheusConfigText;

    environment.etc."${serviceName}/alert.rules.yml".text = alertRulesText;

    systemd.services.${serviceName} = {
      description = "Prometheus (Docker Compose)";

      wantedBy = ["multi-user.target"];
      requires = ["docker.service"];
      after = ["docker.service" "network-online.target"];
      wants = ["network-online.target"];
      restartTriggers = [
        config.environment.etc."${serviceName}/docker-compose.yml".source
        config.environment.etc."${serviceName}/prometheus.yml".source
        config.environment.etc."${serviceName}/alert.rules.yml".source
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
          "PROMETHEUS_CONTAINER_NAME=${cfg.containerName}"
          "PROMETHEUS_IMAGE_REPOSITORY=${cfg.image.repository}"
          "PROMETHEUS_IMAGE_TAG=${cfg.image.tag}"
          "PROMETHEUS_NETWORK=${cfg.network}"
          "PROMETHEUS_HOSTNAME=${cfg.hostname}"
          "PROMETHEUS_ENTRYPOINTS=${if cfg.tls then "websecure" else "web"}"
          "PROMETHEUS_TLS=${if cfg.tls then "true" else "false"}"
          "PROMETHEUS_DATA_DIR=${cfg.dataDir}"
          "PROMETHEUS_RETENTION_TIME=${cfg.retentionTime}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${cfg.dataDir} && chown 65534:65534 ${cfg.dataDir} && chmod 0750 ${cfg.dataDir}'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/prometheus.yml'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/alert.rules.yml'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"prometheus: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
