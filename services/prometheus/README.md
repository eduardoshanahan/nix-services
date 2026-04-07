# Prometheus Service Module

This module deploys Prometheus behind Traefik using a checked-in Docker Compose file.

## Deployment model

- Compose file is versioned at `services/prometheus/docker-compose.yml`.
- NixOS injects runtime environment variables (container name, image/tag, network, hostname, TLS mode, timezone, data path, retention).
- NixOS renders Prometheus config at `/etc/prometheus/prometheus.yml`.
- NixOS renders alert rules file at `/etc/prometheus/alert.rules.yml`.
- systemd runs `docker compose up -d` / `docker compose down`.
- Data persists under `services.prometheusCompose.dataDir` (default `/var/lib/prometheus`).

## Default alert rules

The module ships a baseline `homelab-core` rule group:

- `TargetDown`: any scrape target with `up == 0` for 2 minutes.
- `PrometheusConfigReloadFailed`: config reload failures.
- `NodeHighCpuUsage`: node CPU usage above 85% for 10 minutes.
- `NodeLowMemory`: available memory below 10% for 10 minutes.
- `NodeLowDiskRoot`: root filesystem free space below 15% for 15 minutes.
- `TraefikHigh5xxRate`: sustained Traefik 5xx responses above 0.1/sec for 10 minutes.
- `PostgresExporterDatabaseDown`: `pg_up == 0` for 3 minutes.
- `RedisExporterDatabaseDown`: `redis_up == 0` for 3 minutes.
- `MysqlExporterDatabaseDown`: `mysql_up == 0` for 3 minutes.
- `SmtpRelaySystemdDown`: `smtp-relay.service` inactive for 3 minutes.
- `SmtpRelayContainerNotSeen`: smtp-relay container not seen by cAdvisor in the last 2 minutes for 3 minutes.

## Exposed options

- `services.prometheusCompose.enable`
- `services.prometheusCompose.containerName`
- `services.prometheusCompose.hostname`
- `services.prometheusCompose.timezone`
- `services.prometheusCompose.network`
- `services.prometheusCompose.dataDir`
- `services.prometheusCompose.retentionTime`
- `services.prometheusCompose.image.repository`
- `services.prometheusCompose.image.tag`
- `services.prometheusCompose.image.allowMutableTag`
- `services.prometheusCompose.scrape.nodeTargets`
- `services.prometheusCompose.scrape.synologyNodeTargets`
- `services.prometheusCompose.scrape.synologySnmpTargets`
- `services.prometheusCompose.scrape.synologySnmpExporterAddress`
- `services.prometheusCompose.scrape.synologySnmpModule`
- `services.prometheusCompose.scrape.synologySnmpAuth`
- `services.prometheusCompose.scrape.synologySnmpSystemTargets`
- `services.prometheusCompose.scrape.synologySnmpSystemModule`
- `services.prometheusCompose.scrape.synologySnmpMemoryTargets`
- `services.prometheusCompose.scrape.synologySnmpMemoryModule`
- `services.prometheusCompose.scrape.synologySnmpStorageTargets`
- `services.prometheusCompose.scrape.synologySnmpStorageModule`
- `services.prometheusCompose.scrape.synologySnmpNetworkTargets`
- `services.prometheusCompose.scrape.synologySnmpNetworkModule`
- `services.prometheusCompose.scrape.synologySnmpLoadTargets`
- `services.prometheusCompose.scrape.synologySnmpLoadModule`
- `services.prometheusCompose.scrape.synologySnmpUptimeTargets`
- `services.prometheusCompose.scrape.synologySnmpUptimeModule`
- `services.prometheusCompose.scrape.lokiTargets`
- `services.prometheusCompose.scrape.traefikTargets`
- `services.prometheusCompose.scrape.promtailTargets`
- `services.prometheusCompose.scrape.snmpExporterTargets`
- `services.prometheusCompose.scrape.postgresExporterTargets`
- `services.prometheusCompose.scrape.redisExporterTargets`
- `services.prometheusCompose.scrape.mysqlExporterTargets`
- `services.prometheusCompose.scrape.piholeExporterTargets`
- `services.prometheusCompose.scrape.cadvisorTargets`
- `services.prometheusCompose.scrape.unpollerTargets`
- `services.prometheusCompose.scrape.giteaTargets`
- `services.prometheusCompose.scrape.grafanaTargets`
- `services.prometheusCompose.scrape.kubeApiServerMetricsTargets`
- `services.prometheusCompose.scrape.kubeApiServerMetricsScheme`
- `services.prometheusCompose.scrape.kubeApiServerMetricsPath`
- `services.prometheusCompose.scrape.kubeApiServerMetricsTlsInsecureSkipVerify`
- `services.prometheusCompose.scrape.alertmanagerTargets`
- `services.prometheusCompose.scrape.extraStaticJobs`
- `services.prometheusCompose.alerting.enable`
- `services.prometheusCompose.alerting.targets`
- `services.prometheusCompose.tls`

## Image pinning strategy

- Default policy is pinned tags only.
- Default image is `prom/prometheus:v3.11.0`.
- Mutable tags like `latest` are blocked unless
  `services.prometheusCompose.image.allowMutableTag = true`.

## Example

```nix
services.prometheusCompose = {
  enable = true;
  hostname = "prometheus.${config.lab.domain}";
  dataDir = "/srv/prometheus/data";
  retentionTime = "30d";

  scrape = {
    nodeTargets = [
      "node-a.internal.example:9100"
      "node-b.internal.example:9100"
      "node-c.internal.example:9100"
    ];
    synologyNodeTargets = [
      "nas-a.internal.example:9100"
    ];
    # If you deploy snmp_exporter for NAS telemetry:
    synologySnmpTargets = [
      "nas-a.internal.example"
      "nas-b.internal.example"
    ];
    synologySnmpExporterAddress = "snmp-exporter.internal.example:9116";
    synologySnmpModule = "synology";
    synologySnmpAuth = "public_v2";
    synologySnmpSystemTargets = [ "nas-b.internal.example" ];
    synologySnmpMemoryTargets = [ "nas-b.internal.example" ];
    synologySnmpStorageTargets = [ "nas-b.internal.example" ];
    synologySnmpNetworkTargets = [ "nas-b.internal.example" ];
    synologySnmpLoadTargets = [ "nas-b.internal.example" ];
    synologySnmpUptimeTargets = [ "nas-b.internal.example" ];
    lokiTargets = [ "loki.internal.example:3100" ];
    traefikTargets = [
      "node-a-metrics.internal.example:8082"
      "node-b-metrics.internal.example:8082"
      "node-c-metrics.internal.example:8082"
    ];
    promtailTargets = [
      "node-a.internal.example:9080"
      "node-b.internal.example:9080"
      "node-c.internal.example:9080"
    ];
    snmpExporterTargets = [
      "snmp-exporter.internal.example:9116"
    ];
    postgresExporterTargets = [
      "postgres-exporter.internal.example:9187"
    ];
    redisExporterTargets = [
      "redis-exporter.internal.example:9121"
    ];
    mysqlExporterTargets = [
      "mysql-exporter.internal.example:9104"
    ];
    grafanaTargets = [
      "grafana:3000"
    ];
    piholeExporterTargets = [
      "dns-node.internal.example:9617"
    ];
    cadvisorTargets = [
      "pihole-exporter.internal.example:8081"
    ];
    unpollerTargets = [
      "unpoller.internal.example:9130"
    ];
    giteaTargets = [
      "forge.internal.example:3000"
    ];
    extraStaticJobs = [
      {
        jobName = "minio";
        targets = [ "minio.internal.example:443" ];
        scheme = "https";
        metricsPath = "/minio/v2/metrics/cluster";
      }
    ];
  };

  tls = true;
};
```
