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
      ""
      "      - alert: SynologyHighCpuUsage"
      "        expr: (100 - ssCpuIdle{job=\"synology-snmp-system\"}) > 90"
      "        for: 10m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"High Synology CPU usage on {{ $labels.instance }}\""
      "          description: \"Synology SNMP CPU usage has been above 90% for 10 minutes.\""
      ""
      "      - alert: SynologyLowMemory"
      "        expr: (100 * (memAvailReal{job=\"synology-snmp-memory\"} / memTotalReal{job=\"synology-snmp-memory\"})) < 10"
      "        for: 10m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"Low Synology memory on {{ $labels.instance }}\""
      "          description: \"Synology SNMP available memory has been below 10% for 10 minutes.\""
      ""
      "      - alert: SynologyVolumeAlmostFull"
      "        expr: (100 * (hrStorageUsed{job=\"synology-snmp-storage\",hrStorageDescr=\"/volume1\"} / hrStorageSize{job=\"synology-snmp-storage\",hrStorageDescr=\"/volume1\"})) > 90"
      "        for: 15m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"Synology /volume1 almost full on {{ $labels.instance }}\""
      "          description: \"Synology /volume1 usage has been above 90% for 15 minutes.\""
      ""
      "      - alert: SynologySnmpAnyModuleDown"
      "        expr: sum(up{job=~\"synology-snmp|synology-snmp-system|synology-snmp-memory|synology-snmp-storage|synology-snmp-network|synology-snmp-load|synology-snmp-uptime\"} == bool 0) > 0"
      "        for: 5m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"Synology SNMP module scrape failure\""
      "          description: \"At least one Synology SNMP module scrape target has been down for more than 5 minutes.\""
      ""
      "      - alert: SynologySnmpAllModulesDown"
      "        expr: sum(up{job=~\"synology-snmp|synology-snmp-system|synology-snmp-memory|synology-snmp-storage|synology-snmp-network|synology-snmp-load|synology-snmp-uptime\"}) == 0"
      "        for: 3m"
      "        labels:"
      "          severity: critical"
      "        annotations:"
      "          summary: \"All Synology SNMP module scrapes down\""
      "          description: \"All Synology SNMP module scrape targets have been down for more than 3 minutes.\""
      ""
      "      - alert: PostgresExporterDatabaseDown"
      "        expr: pg_up{job=\"postgres-exporter\"} == 0"
      "        for: 3m"
      "        labels:"
      "          severity: critical"
      "        annotations:"
      "          summary: \"Postgres exporter DB down on {{ $labels.instance }}\""
      "          description: \"postgres-exporter can be scraped but DB connectivity is failing (pg_up=0) for more than 3 minutes.\""
      ""
      "      - alert: RedisExporterDatabaseDown"
      "        expr: redis_up{job=\"redis-exporter\"} == 0"
      "        for: 3m"
      "        labels:"
      "          severity: critical"
      "        annotations:"
      "          summary: \"Redis exporter DB down on {{ $labels.instance }}\""
      "          description: \"redis-exporter can be scraped but DB connectivity is failing (redis_up=0) for more than 3 minutes.\""
      ""
      "      - alert: MysqlExporterDatabaseDown"
      "        expr: mysql_up{job=\"mysql-exporter\"} == 0"
      "        for: 3m"
      "        labels:"
      "          severity: critical"
      "        annotations:"
      "          summary: \"MySQL exporter DB down on {{ $labels.instance }}\""
      "          description: \"mysqld-exporter can be scraped but DB connectivity is failing (mysql_up=0) for more than 3 minutes.\""
      ""
      "      - alert: PostgresExporterDegraded"
      "        expr: up{job=\"postgres-exporter\"} == 1 and on(instance, job) pg_up{job=\"postgres-exporter\"} == 0"
      "        for: 3m"
      "        labels:"
      "          severity: critical"
      "        annotations:"
      "          summary: \"Postgres exporter degraded on {{ $labels.instance }}\""
      "          description: \"Exporter is reachable but PostgreSQL connectivity is failing (up=1, pg_up=0) for more than 3 minutes.\""
      ""
      "      - alert: RedisExporterDegraded"
      "        expr: up{job=\"redis-exporter\"} == 1 and on(instance, job) redis_up{job=\"redis-exporter\"} == 0"
      "        for: 3m"
      "        labels:"
      "          severity: critical"
      "        annotations:"
      "          summary: \"Redis exporter degraded on {{ $labels.instance }}\""
      "          description: \"Exporter is reachable but Redis connectivity is failing (up=1, redis_up=0) for more than 3 minutes.\""
      ""
      "      - alert: MysqlExporterDegraded"
      "        expr: up{job=\"mysql-exporter\"} == 1 and on(instance, job) mysql_up{job=\"mysql-exporter\"} == 0"
      "        for: 3m"
      "        labels:"
      "          severity: critical"
      "        annotations:"
      "          summary: \"MySQL exporter degraded on {{ $labels.instance }}\""
      "          description: \"Exporter is reachable but MySQL connectivity is failing (up=1, mysql_up=0) for more than 3 minutes.\""
      ""
      "      - alert: SharedInfraAnyExporterDown"
      "        expr: ((max(up{job=\"postgres-exporter\"} == bool 0) or vector(0)) + (max(up{job=\"redis-exporter\"} == bool 0) or vector(0)) + (max(up{job=\"mysql-exporter\"} == bool 0) or vector(0))) > 0"
      "        for: 2m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"Shared infra exporter down\""
      "          description: \"At least one shared infra exporter (postgres/redis/mysql) is not being scraped for more than 2 minutes.\""
      ""
      "      - alert: SharedInfraAnyDegraded"
      "        expr: (((max(up{job=\"postgres-exporter\"}) or vector(0)) * (max(pg_up{job=\"postgres-exporter\"} == bool 0) or vector(0))) + ((max(up{job=\"redis-exporter\"}) or vector(0)) * (max(redis_up{job=\"redis-exporter\"} == bool 0) or vector(0))) + ((max(up{job=\"mysql-exporter\"}) or vector(0)) * (max(mysql_up{job=\"mysql-exporter\"} == bool 0) or vector(0)))) > 0"
      "        for: 3m"
      "        labels:"
      "          severity: critical"
      "        annotations:"
      "          summary: \"Shared infra degraded\""
      "          description: \"At least one shared infra backend is degraded (exporter reachable but backend connectivity failing) for more than 3 minutes.\""
      ""
      "      - alert: PostgresExporterScrapeDown"
      "        expr: up{job=\"postgres-exporter\"} == 0"
      "        for: 2m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"Postgres exporter scrape down on {{ $labels.instance }}\""
      "          description: \"Prometheus cannot scrape postgres-exporter for more than 2 minutes.\""
      ""
      "      - alert: RedisExporterScrapeDown"
      "        expr: up{job=\"redis-exporter\"} == 0"
      "        for: 2m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"Redis exporter scrape down on {{ $labels.instance }}\""
      "          description: \"Prometheus cannot scrape redis-exporter for more than 2 minutes.\""
      ""
      "      - alert: MysqlExporterScrapeDown"
      "        expr: up{job=\"mysql-exporter\"} == 0"
      "        for: 2m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"MySQL exporter scrape down on {{ $labels.instance }}\""
      "          description: \"Prometheus cannot scrape mysqld-exporter for more than 2 minutes.\""
      ""
      "      - alert: SmtpRelaySystemdDown"
      "        expr: (max(node_systemd_unit_state{job=\"nodes\",name=\"smtp-relay.service\",state=\"active\"}) or vector(0)) == 0"
      "        for: 3m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"SMTP relay systemd unit inactive\""
      "          description: \"smtp-relay.service is not active for more than 3 minutes.\""
      ""
      "      - alert: SmtpRelayContainerNotSeen"
      "        expr: (max((time() - container_last_seen{job=\"cadvisor\",container_label_com_docker_compose_service=\"smtp-relay\"}) < bool 120) or vector(0)) == 0"
      "        for: 3m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"SMTP relay container not seen recently\""
      "          description: \"cAdvisor has not seen the smtp-relay container in the last 2 minutes for more than 3 minutes.\""
      ""
      "      - alert: GithubProfileExporterDown"
      "        expr: (max(github_profile_up{job=\"github-profile\"}) or vector(0)) == 0"
      "        for: 10m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"GitHub profile exporter down\""
      "          description: \"github-profile exporter has been down or missing for more than 10 minutes.\""
      ""
      "      - alert: GithubProfileDataStale"
      "        expr: ((max(github_profile_up{job=\"github-profile\"}) or vector(0)) == 1) and ((time() - max(github_profile_last_fetch_unixtime{job=\"github-profile\"})) > 7200)"
      "        for: 30m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"GitHub profile data is stale\""
      "          description: \"github-profile metrics have not refreshed in more than 2 hours while exporter remains up.\""
      ""
      "      - alert: GithubProfileCommitStatsStuckPending"
      "        expr: ((max(github_profile_up{job=\"github-profile\"}) or vector(0)) == 1) and (max(github_profile_commit_repos_pending{job=\"github-profile\"}) > 0) and (max(github_profile_commit_repos_ready{job=\"github-profile\"}) == 0)"
      "        for: 6h"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"GitHub commit stats remain pending\""
      "          description: \"GitHub contributor stats stayed pending (0 repos ready) for more than 6 hours.\""
    ]
    + "\n";
in {
  inherit prometheusConfigText alertRulesText;
}
