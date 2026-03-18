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

  optionalJobLinesWithMetricsPath = {
    name,
    metricsPath,
    targets,
    dropUpMetric ? false,
  }:
    lib.optionals (targets != []) (
      [
        "  - job_name: \"${name}\""
        "    metrics_path: ${metricsPath}"
        "    static_configs:"
        "      - targets:"
      ]
      ++ (mkTargetLines {
        inherit targets;
        indent = "        ";
      })
      ++ lib.optionals dropUpMetric [
        "    metric_relabel_configs:"
        "      - source_labels: [__name__]"
        "        regex: up"
        "        action: drop"
      ]
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
        name = "mongodb-exporter";
        targets = cfg.scrape.mongodbExporterTargets;
      })
      ++ (optionalJobLines {
        name = "dolt";
        targets = cfg.scrape.doltTargets;
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
      ++ (optionalJobLinesWithMetricsPath {
        name = "authentik";
        metricsPath = cfg.scrape.authentikMetricsPath;
        targets = cfg.scrape.authentikTargets;
        dropUpMetric = true;
      })
      ++ (optionalJobLinesWithMetricsPath {
        name = "vikunja";
        metricsPath = cfg.scrape.vikunjaMetricsPath;
        targets = cfg.scrape.vikunjaTargets;
        dropUpMetric = true;
      })
      ++ (optionalJobLines {
        name = "kube-state-metrics";
        targets = cfg.scrape.kubeStateMetricsTargets;
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
      "      - alert: KubernetesNodeNotReady"
      "        expr: kube_node_status_condition{job=\"kube-state-metrics\",condition=\"Ready\",status=\"true\"} == 0"
      "        for: 10m"
      "        labels:"
      "          severity: critical"
      "        annotations:"
      "          summary: \"Kubernetes node not ready: {{ $labels.node }}\""
      "          description: \"Node {{ $labels.node }} has reported Ready=false for more than 10 minutes.\""
      ""
      "      - alert: KubernetesPodRestarting"
      "        expr: sum by (namespace, pod) (rate(kube_pod_container_status_restarts_total{job=\"kube-state-metrics\"}[15m])) > 0.01"
      "        for: 15m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"Pod restarting repeatedly: {{ $labels.namespace }}/{{ $labels.pod }}\""
      "          description: \"Pod {{ $labels.namespace }}/{{ $labels.pod }} has sustained container restart activity for more than 15 minutes.\""
      ""
      "      - alert: KubernetesDeploymentReplicasUnavailable"
      "        expr: sum by (namespace, deployment) (clamp_min(kube_deployment_spec_replicas{job=\"kube-state-metrics\"} - kube_deployment_status_replicas_available{job=\"kube-state-metrics\"}, 0)) > 0"
      "        for: 15m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"Deployment replicas unavailable: {{ $labels.namespace }}/{{ $labels.deployment }}\""
      "          description: \"Deployment {{ $labels.namespace }}/{{ $labels.deployment }} has unavailable replicas for more than 15 minutes.\""
      ""
      "      - alert: KubernetesWorkloadNotFullyReady"
      "        expr: (sum by (namespace, daemonset) (clamp_min(kube_daemonset_status_desired_number_scheduled{job=\"kube-state-metrics\"} - kube_daemonset_status_number_ready{job=\"kube-state-metrics\"}, 0)) > 0) or (sum by (namespace, statefulset) (clamp_min(kube_statefulset_replicas{job=\"kube-state-metrics\"} - kube_statefulset_status_replicas_ready{job=\"kube-state-metrics\"}, 0)) > 0)"
      "        for: 15m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"Stateful workload not fully ready\""
      "          description: \"A daemonset or statefulset still has a readiness gap after 15 minutes. Labels: namespace={{ $labels.namespace }}, daemonset={{ $labels.daemonset }}, statefulset={{ $labels.statefulset }}.\""
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
      "      - alert: AppServiceHigh5xxRatio"
      "        expr: (100 * (sum by (service) (rate(traefik_service_requests_total{service=~\"authentik@docker|vikunja@docker|timetagger@docker|homepage@docker|ghost-blog@docker|uptime-kuma@docker|n8n@docker|diagrams-net@docker|excalidraw@docker|owntracks-recorder@docker|traggo@docker|dozzle@docker|fossflow@docker|searxng@docker|d2@docker|paperless@docker\",code=~\"5..\"}[5m])) / clamp_min(sum by (service) (rate(traefik_service_requests_total{service=~\"authentik@docker|vikunja@docker|timetagger@docker|homepage@docker|ghost-blog@docker|uptime-kuma@docker|n8n@docker|diagrams-net@docker|excalidraw@docker|owntracks-recorder@docker|traggo@docker|dozzle@docker|fossflow@docker|searxng@docker|d2@docker|paperless@docker\"}[5m])), 0.01))) > 5 and on(service) (sum by (service) (rate(traefik_service_requests_total{service=~\"authentik@docker|vikunja@docker|timetagger@docker|homepage@docker|ghost-blog@docker|uptime-kuma@docker|n8n@docker|diagrams-net@docker|excalidraw@docker|owntracks-recorder@docker|traggo@docker|dozzle@docker|fossflow@docker|searxng@docker|d2@docker|paperless@docker\"}[5m])) > 0.02)"
      "        for: 10m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"High 5xx ratio on {{ $labels.service }}\""
      "          description: \"Service {{ $labels.service }} has sustained 5xx ratio above 5% for more than 10 minutes.\""
      ""
      "      - alert: AppServiceHighLatencyP95"
      "        expr: histogram_quantile(0.95, sum by (service, le) (rate(traefik_service_request_duration_seconds_bucket{service=~\"authentik@docker|vikunja@docker|timetagger@docker|homepage@docker|ghost-blog@docker|uptime-kuma@docker|n8n@docker|diagrams-net@docker|excalidraw@docker|owntracks-recorder@docker|traggo@docker|dozzle@docker|fossflow@docker|searxng@docker|d2@docker|paperless@docker\"}[5m]))) > 2 and on(service) (sum by (service) (rate(traefik_service_requests_total{service=~\"authentik@docker|vikunja@docker|timetagger@docker|homepage@docker|ghost-blog@docker|uptime-kuma@docker|n8n@docker|diagrams-net@docker|excalidraw@docker|owntracks-recorder@docker|traggo@docker|dozzle@docker|fossflow@docker|searxng@docker|d2@docker|paperless@docker\"}[5m])) > 0.02)"
      "        for: 15m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"High p95 latency on {{ $labels.service }}\""
      "          description: \"Service {{ $labels.service }} p95 request latency has been above 2s for more than 15 minutes.\""
      ""
      "      - alert: AppContainerNotSeen"
      "        expr: max by (container_label_com_docker_compose_service) ((time() - container_last_seen{job=\"cadvisor\",container_label_com_docker_compose_service=~\"authentik-server|authentik-worker|vikunja|timetagger|homepage|uptime-kuma|n8n|diagrams-net|excalidraw|owntracks-recorder|traggo|dozzle|fossflow|searxng|d2\"}) < bool 180) == 0"
      "        for: 5m"
      "        labels:"
      "          severity: critical"
      "        annotations:"
      "          summary: \"Application container not seen: {{ $labels.container_label_com_docker_compose_service }}\""
      "          description: \"cAdvisor has not seen container {{ $labels.container_label_com_docker_compose_service }} in the last 3 minutes for more than 5 minutes.\""
      ""
      "      - alert: HomeAssistantHigh5xxRatio"
      "        expr: (100 * ((sum(rate(traefik_service_requests_total{service=\"homeassistant@docker\",code=~\"5..\"}[5m])) or vector(0)) / clamp_min((sum(rate(traefik_service_requests_total{service=\"homeassistant@docker\"}[5m])) or vector(0)), 0.01))) > 5 and (sum(rate(traefik_service_requests_total{service=\"homeassistant@docker\"}[5m])) > 0.02)"
      "        for: 10m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"Home Assistant 5xx ratio elevated\""
      "          description: \"Home Assistant 5xx ratio has remained above 5% for 10 minutes under non-trivial traffic.\""
      ""
      "      - alert: HomeAssistantHighLatencyP95"
      "        expr: histogram_quantile(0.95, sum by (le) (rate(traefik_service_request_duration_seconds_bucket{service=\"homeassistant@docker\"}[5m]))) > 2 and (sum(rate(traefik_service_requests_total{service=\"homeassistant@docker\"}[5m])) > 0.02)"
      "        for: 15m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"Home Assistant p95 latency high\""
      "          description: \"Home Assistant p95 request latency has remained above 2 seconds for 15 minutes.\""
      ""
      "      - alert: HomeAssistantSystemdDown"
      "        expr: max(node_systemd_unit_state{job=\"nodes\",name=\"home-assistant.service\",state=\"active\"}) == 0"
      "        for: 3m"
      "        labels:"
      "          severity: critical"
      "        annotations:"
      "          summary: \"Home Assistant systemd unit inactive\""
      "          description: \"home-assistant.service has been inactive for more than 3 minutes.\""
      ""
      "      - alert: HomeAssistantRecorderRollbackRatioHigh"
      "        expr: (100 * ((rate(pg_stat_database_xact_rollback{job=\"postgres-exporter\",datname=\"homeassistant\"}[10m]) or vector(0)) / clamp_min(((rate(pg_stat_database_xact_commit{job=\"postgres-exporter\",datname=\"homeassistant\"}[10m]) or vector(0)) + (rate(pg_stat_database_xact_rollback{job=\"postgres-exporter\",datname=\"homeassistant\"}[10m]) or vector(0))), 0.01))) > 5 and (((rate(pg_stat_database_xact_commit{job=\"postgres-exporter\",datname=\"homeassistant\"}[10m]) or vector(0)) + (rate(pg_stat_database_xact_rollback{job=\"postgres-exporter\",datname=\"homeassistant\"}[10m]) or vector(0))) > 0.5)"
      "        for: 15m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"Home Assistant recorder rollback ratio high\""
      "          description: \"Recorder DB rollback ratio has remained above 5% for 15 minutes under meaningful transaction load.\""
      ""
      "      - alert: HomeAssistantRecorderConnectionsHigh"
      "        expr: max(pg_stat_database_numbackends{job=\"postgres-exporter\",datname=\"homeassistant\"}) > 40"
      "        for: 15m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"Home Assistant recorder DB connections high\""
      "          description: \"Recorder DB active backend connections have remained above 40 for more than 15 minutes.\""
      ""
      "      - alert: AuthentikMetricsDown"
      "        expr: (max(scrape_samples_scraped{job=\"authentik\"}) or vector(0)) == 0"
      "        for: 5m"
      "        labels:"
      "          severity: critical"
      "        annotations:"
      "          summary: \"Authentik metrics endpoint down\""
      "          description: \"Prometheus cannot scrape Authentik metrics targets for more than 5 minutes.\""
      ""
      "      - alert: VikunjaMetricsDown"
      "        expr: (max(scrape_samples_scraped{job=\"vikunja\"}) or vector(0)) == 0"
      "        for: 5m"
      "        labels:"
      "          severity: critical"
      "        annotations:"
      "          summary: \"Vikunja metrics endpoint down\""
      "          description: \"Prometheus cannot scrape Vikunja metrics targets for more than 5 minutes.\""
      ""
      "      - alert: AuthentikMetricsLowSampleVolume"
      "        expr: ((max(scrape_samples_scraped{job=\"authentik\"}) or vector(0)) > 0) and ((max(scrape_samples_scraped{job=\"authentik\"}) or vector(0)) < 20)"
      "        for: 15m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"Authentik metrics sample volume unexpectedly low\""
      "          description: \"Authentik metrics target is up but scrape sample volume stayed below 20 for more than 15 minutes.\""
      ""
      "      - alert: VikunjaMetricsLowSampleVolume"
      "        expr: ((max(scrape_samples_scraped{job=\"vikunja\"}) or vector(0)) > 0) and ((max(scrape_samples_scraped{job=\"vikunja\"}) or vector(0)) < 20)"
      "        for: 15m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"Vikunja metrics sample volume unexpectedly low\""
      "          description: \"Vikunja metrics target is up but scrape sample volume stayed below 20 for more than 15 minutes.\""
      ""
      "      - alert: AuthentikHighAuthFailureRatio"
      "        expr: (100 * ((sum(rate(django_http_responses_total_by_status_total{job=\"authentik\",status=~\"401|403\"}[5m])) or vector(0)) / clamp_min((sum(rate(django_http_responses_total_by_status_total{job=\"authentik\"}[5m])) or vector(0)), 0.01))) > 20 and (sum(rate(django_http_responses_total_by_status_total{job=\"authentik\"}[5m])) > 0.05)"
      "        for: 10m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"Authentik auth failure ratio elevated\""
      "          description: \"Authentik 401/403 ratio has stayed above 20% for 10 minutes under non-trivial traffic.\""
      ""
      "      - alert: AuthentikTaskQueueBacklog"
      "        expr: sum(max by (actor_name, queue_name, instance) (authentik_tasks_queued{job=\"authentik\"})) > 25"
      "        for: 10m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"Authentik task queue backlog detected\""
      "          description: \"Authentik queued task backlog has stayed above 25 for more than 10 minutes.\""
      ""
      "      - alert: VikunjaHandlerFailures"
      "        expr: (sum(rate(handler_execution_time_seconds_count{job=\"vikunja\",success!=\"true\"}[10m])) or vector(0)) > 0.02"
      "        for: 10m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"Vikunja handler failures detected\""
      "          description: \"Vikunja reports sustained failed handler executions above 0.02/s for 10 minutes.\""
      ""
      "      - alert: VikunjaHandlerLatencyP95High"
      "        expr: histogram_quantile(0.95, sum by (le) (rate(handler_execution_time_seconds_bucket{job=\"vikunja\"}[10m]))) > 1 and (sum(rate(handler_execution_time_seconds_count{job=\"vikunja\"}[10m])) > 0.02)"
      "        for: 15m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"Vikunja handler p95 latency high\""
      "          description: \"Vikunja event handler p95 duration has remained above 1 second for 15 minutes.\""
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
      "        expr: (100 * ((memAvailReal{job=\"synology-snmp-memory\"} + memCached{job=\"synology-snmp-memory\"} + memBuffer{job=\"synology-snmp-memory\"}) / memTotalReal{job=\"synology-snmp-memory\"})) < 10"
      "        for: 10m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"Low Synology reclaimable memory on {{ $labels.instance }}\""
      "          description: \"Synology reclaimable memory (available + cached + buffer) has been below 10% for 10 minutes.\""
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
      "      - alert: MongodbExporterDatabaseDown"
      "        expr: mongodb_up{job=\"mongodb-exporter\"} == 0"
      "        for: 3m"
      "        labels:"
      "          severity: critical"
      "        annotations:"
      "          summary: \"MongoDB exporter DB down on {{ $labels.instance }}\""
      "          description: \"mongodb-exporter can be scraped but DB connectivity is failing (mongodb_up=0) for more than 3 minutes.\""
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
      "      - alert: MongodbExporterDegraded"
      "        expr: up{job=\"mongodb-exporter\"} == 1 and on(instance, job) mongodb_up{job=\"mongodb-exporter\"} == 0"
      "        for: 3m"
      "        labels:"
      "          severity: critical"
      "        annotations:"
      "          summary: \"MongoDB exporter degraded on {{ $labels.instance }}\""
      "          description: \"Exporter is reachable but MongoDB connectivity is failing (up=1, mongodb_up=0) for more than 3 minutes.\""
      ""
      "      - alert: SharedInfraAnyExporterDown"
      "        expr: ((max(up{job=\"postgres-exporter\"} == bool 0) or vector(0)) + (max(up{job=\"redis-exporter\"} == bool 0) or vector(0)) + (max(up{job=\"mysql-exporter\"} == bool 0) or vector(0)) + (max(up{job=\"mongodb-exporter\"} == bool 0) or vector(0))) > 0"
      "        for: 2m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"Shared infra exporter down\""
      "          description: \"At least one shared infra exporter (postgres/redis/mysql/mongodb) is not being scraped for more than 2 minutes.\""
      ""
      "      - alert: SharedInfraAnyDegraded"
      "        expr: (((max(up{job=\"postgres-exporter\"}) or vector(0)) * (max(pg_up{job=\"postgres-exporter\"} == bool 0) or vector(0))) + ((max(up{job=\"redis-exporter\"}) or vector(0)) * (max(redis_up{job=\"redis-exporter\"} == bool 0) or vector(0))) + ((max(up{job=\"mysql-exporter\"}) or vector(0)) * (max(mysql_up{job=\"mysql-exporter\"} == bool 0) or vector(0))) + ((max(up{job=\"mongodb-exporter\"}) or vector(0)) * (max(mongodb_up{job=\"mongodb-exporter\"} == bool 0) or vector(0)))) > 0"
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
      "      - alert: MongodbExporterScrapeDown"
      "        expr: up{job=\"mongodb-exporter\"} == 0"
      "        for: 2m"
      "        labels:"
      "          severity: warning"
      "        annotations:"
      "          summary: \"MongoDB exporter scrape down on {{ $labels.instance }}\""
      "          description: \"Prometheus cannot scrape mongodb-exporter for more than 2 minutes.\""
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
