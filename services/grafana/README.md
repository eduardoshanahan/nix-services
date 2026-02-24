# Grafana Service Module

This module deploys Grafana behind Traefik using a checked-in Docker Compose file.

## Deployment model

- Compose file is versioned at `services/grafana/docker-compose.yml`.
- NixOS injects runtime environment variables (container name, image/tag, network, hostname, TLS mode, timezone, data path).
- Grafana admin password is injected at runtime from `services.grafanaCompose.adminPasswordFile` into `/run/secrets/grafana.env`.
- Grafana provisioning files are generated declaratively under `/etc/grafana/provisioning` (datasources + dashboard provider + optional starter dashboard).
- Grafana self-metrics are enabled (`/metrics`) for Prometheus scraping.
- systemd runs `docker compose up -d` / `docker compose down` and waits for container health after startup.
- Data persists under `services.grafanaCompose.dataDir` (default `/var/lib/grafana`).
- A periodic systemd timer can monitor service and container health.

## Exposed options

- `services.grafanaCompose.enable`
- `services.grafanaCompose.containerName`
- `services.grafanaCompose.hostname`
- `services.grafanaCompose.timezone`
- `services.grafanaCompose.network`
- `services.grafanaCompose.dataDir`
- `services.grafanaCompose.adminPasswordFile`
- `services.grafanaCompose.image.repository`
- `services.grafanaCompose.image.tag`
- `services.grafanaCompose.image.allowMutableTag`
- `services.grafanaCompose.tls`
- `services.grafanaCompose.monitoring.enable`
- `services.grafanaCompose.monitoring.interval`
- `services.grafanaCompose.provisioning.enable`
- `services.grafanaCompose.provisioning.datasources.prometheus.url`
- `services.grafanaCompose.provisioning.datasources.loki.url`
- `services.grafanaCompose.provisioning.dashboards.enableStarter`

## Image pinning strategy

- Default policy is pinned tags only.
- Default image is `grafana/grafana:11.2.0`.
- Mutable tags like `latest` are blocked unless
  `services.grafanaCompose.image.allowMutableTag = true`.

## Example

```nix
services.grafanaCompose = {
  enable = true;
  hostname = "grafana.${config.lab.domain}";
  dataDir = "/var/lib/grafana";
  adminPasswordFile = "/run/secrets/grafana-admin-password";
  tls = true;

  monitoring = {
    enable = true;
    interval = "5m";
  };

  provisioning = {
    enable = true;
    datasources = {
      prometheus.url = "http://prometheus:9090";
      loki.url = "http://loki.hhlab.home.arpa:3100";
    };
    dashboards.enableStarter = true;
  };
};
```

## Healthcheck units

- Service: `grafana-healthcheck.service`
- Timer: `grafana-healthcheck.timer`

## Admin Password Behavior

- `GF_SECURITY_ADMIN_PASSWORD` is used for initial admin creation on first startup
  (fresh `/var/lib/grafana`).
- On an existing Grafana database, changing the secret file does not
  automatically rotate the admin password.
- To rotate without recreating data, reset it explicitly:

```bash
pw="$(docker exec grafana printenv GF_SECURITY_ADMIN_PASSWORD)"
docker exec grafana grafana cli admin reset-admin-password "$pw"
```
