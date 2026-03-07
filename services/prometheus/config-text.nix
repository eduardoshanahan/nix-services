{
  lib,
  cfg,
}: let
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

  synologySnmpJobLines = lib.optionals (cfg.scrape.synologySnmpTargets != [] && cfg.scrape.synologySnmpExporterAddress != null) (
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
      ++ (
        if cfg.scrape.synologySnmpExporterAddress != null
        then synologySnmpJobLines
        else
          (optionalJobLines {
            name = "synology-snmp";
            targets = cfg.scrape.synologySnmpTargets;
          })
      )
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
        name = "snmp-exporter";
        targets = cfg.scrape.snmpExporterTargets;
      })
      ++ (optionalJobLines {
        name = "postgres-exporter";
        targets = cfg.scrape.postgresExporterTargets;
      })
      ++ (optionalJobLines {
        name = "redis-exporter";
        targets = cfg.scrape.redisExporterTargets;
      })
      ++ (optionalJobLines {
        name = "mysql-exporter";
        targets = cfg.scrape.mysqlExporterTargets;
      })
      ++ (optionalJobLines {
        name = "grafana";
        targets = cfg.scrape.grafanaTargets;
      })
      ++ lib.optionals (cfg.scrape.piholeExporterTargets != []) (
        [
          "  - job_name: \"pihole-exporter\""
          "    scrape_interval: ${cfg.scrape.piholeExporterScrapeInterval}"
          "    scrape_timeout: ${cfg.scrape.piholeExporterScrapeTimeout}"
          "    static_configs:"
          "      - targets:"
        ]
        ++ (mkTargetLines {
          targets = cfg.scrape.piholeExporterTargets;
          indent = "        ";
        })
        ++ [""]
      )
      ++ (optionalJobLines {
        name = "cadvisor";
        targets = cfg.scrape.cadvisorTargets;
      })
      ++ (optionalJobLines {
        name = "unpoller";
        targets = cfg.scrape.unpollerTargets;
      })
      ++ (optionalJobLines {
        name = "gitea";
        targets = cfg.scrape.giteaTargets;
      })
      ++ (optionalJobLines {
        name = "github-profile";
        targets = cfg.scrape.githubProfileTargets;
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
      "        expr: up{job!=\"pihole-exporter\"} == 0"
      "        for: 2m"
      "        labels:"
      "          severity: critical"
      "        annotations:"
      "          summary: \"Target down ({{ $labels.job }})\""
      "          description: \"Scrape target {{ $labels.instance }} has been down for more than 2 minutes.\""
      ""
      "      - alert: PiHoleExporterTargetDown"
      "        expr: up{job=\"pihole-exporter\"} == 0"
      "        for: 10m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"Pi-hole exporter target down\""
      "          description: \"Pi-hole exporter target {{ $labels.instance }} has been down for more than 10 minutes.\""
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
  inherit prometheusConfigText alertRulesText;
}
