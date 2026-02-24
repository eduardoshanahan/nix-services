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
- `services.prometheusCompose.scrape.lokiTargets`
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
      "rpi-box-01.hhlab.home.arpa:9100"
      "rpi-box-02.hhlab.home.arpa:9100"
      "rpi-box-03.hhlab.home.arpa:9100"
    ];
    lokiTargets = [ "loki.hhlab.home.arpa:3100" ];
  };

  tls = true;
};
```
