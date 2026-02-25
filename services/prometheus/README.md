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
- `services.prometheusCompose.scrape.piholeExporterTargets`
- `services.prometheusCompose.scrape.grafanaTargets`
- `services.prometheusCompose.scrape.alertmanagerTargets`
- `services.prometheusCompose.alerting.enable`
- `services.prometheusCompose.alerting.targets`
- `services.prometheusCompose.tls`

## Image pinning strategy

- Default policy is pinned tags only.
- Default image is `prom/prometheus:v2.55.1`.
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
      "rpi-box-01.<homelab-domain>:9100"
      "rpi-box-02.<homelab-domain>:9100"
      "rpi-box-03.<homelab-domain>:9100"
    ];
    synologyNodeTargets = [
      "hhnas4.<homelab-domain>:9100"
    ];
    # If you deploy snmp_exporter for NAS telemetry:
    synologySnmpTargets = [
      "hhnas4.<homelab-domain>"
      "nas2.<homelab-domain>"
    ];
    synologySnmpExporterAddress = "snmp-exporter.<homelab-domain>:9116";
    synologySnmpModule = "synology";
    synologySnmpAuth = "public_v2";
    synologySnmpSystemTargets = [ "nas2.<homelab-domain>" ];
    synologySnmpMemoryTargets = [ "nas2.<homelab-domain>" ];
    synologySnmpStorageTargets = [ "nas2.<homelab-domain>" ];
    synologySnmpNetworkTargets = [ "nas2.<homelab-domain>" ];
    synologySnmpLoadTargets = [ "nas2.<homelab-domain>" ];
    synologySnmpUptimeTargets = [ "nas2.<homelab-domain>" ];
    lokiTargets = [ "loki.<homelab-domain>:3100" ];
    traefikTargets = [
      "rpi-box-01-metrics.<homelab-domain>:8082"
      "rpi-box-02-metrics.<homelab-domain>:8082"
      "rpi-box-03-metrics.<homelab-domain>:8082"
    ];
    promtailTargets = [
      "rpi-box-01.<homelab-domain>:9080"
      "rpi-box-02.<homelab-domain>:9080"
      "rpi-box-03.<homelab-domain>:9080"
    ];
    grafanaTargets = [
      "grafana:3000"
    ];
    piholeExporterTargets = [
      "rpi-box-01-metrics.<homelab-domain>:9617"
    ];
  };

  tls = true;
};
```
