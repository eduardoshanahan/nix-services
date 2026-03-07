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
- Optional periodic backups can be enabled via `services.grafanaCompose.backup.*`.

## Exposed options

- `services.grafanaCompose.enable`
- `services.grafanaCompose.containerName`
- `services.grafanaCompose.hostname`
- `services.grafanaCompose.timezone`
- `services.grafanaCompose.network`
- `services.grafanaCompose.dataDir`
- `services.grafanaCompose.adminPasswordFile`
- `services.grafanaCompose.database.type` (`sqlite` or `postgres`)
- `services.grafanaCompose.database.postgres.host`
- `services.grafanaCompose.database.postgres.port`
- `services.grafanaCompose.database.postgres.name`
- `services.grafanaCompose.database.postgres.user`
- `services.grafanaCompose.database.postgres.passwordFile`
- `services.grafanaCompose.database.postgres.sslMode`
- `services.grafanaCompose.image.repository`
- `services.grafanaCompose.image.tag`
- `services.grafanaCompose.image.allowMutableTag`
- `services.grafanaCompose.tls`
- `services.grafanaCompose.monitoring.enable`
- `services.grafanaCompose.monitoring.interval`
- `services.grafanaCompose.backup.enable`
- `services.grafanaCompose.backup.targetDir`
- `services.grafanaCompose.backup.schedule`
- `services.grafanaCompose.backup.keepDays`
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

  backup = {
    enable = true;
    targetDir = "/var/backups/grafana";
    schedule = "daily";
    keepDays = 14;
  };

  provisioning = {
    enable = true;
    datasources = {
      prometheus.url = "http://prometheus:9090";
      loki.url = "http://loki.internal.example:3100";
    };
    dashboards.enableStarter = true;
  };
};
```

## Provisioned Dashboards

With `services.grafanaCompose.provisioning.dashboards.enableStarter = true`, the module provisions:

- `Homelab Overview`
- `Nodes Detail`
- `Container Fleet`
- `DNS & Edge`
- `NAS Detail`
- `Shared Infra`
- `Monitoring Control Plane`
- `Edge Service Reliability`
- `Alerting Triage`
- `SMTP Relay Operations`
- `Service SLI`
- `Pi-hole Operations`
- `UniFi Overview`
- `NAS File Activity` (only when Loki datasource is configured)
- `Logs Pipeline` (only when Loki datasource is configured)

`Shared Infra` includes:

- Postgres / Redis / MySQL exporter connectivity and core runtime panels.
- Shared-infra DB condition counters (healthy `0` -> `OK`, non-zero -> issue).
- Compact aggregate summary cards:
  - `Any Exporter Down`
  - `Any Shared DB Degraded`
- SMTP relay runtime and condition panels (container seen + systemd active).

`Monitoring Control Plane` includes:

- Dedicated core monitoring stack health cards (`prometheus`, `alertmanager`,
  `grafana`, `loki`, `snmp-exporter`, `unpoller`).
- Target-up count cards for core jobs (`nodes`, `traefik`, `promtail`,
  `cadvisor`, `pihole-exporter`) and shared DB exporters.
- Aggregate state cards for:
  - `Core Jobs Down Count`
  - `Core Alerts Firing`
- A trend panel (`Core Target Up by Job`) to spot target churn by job group.

`Edge Service Reliability` includes:

- Traefik edge request/5xx summary cards and service-count cards.
- Top services by request rate, 5xx rate, and 5xx percentage.
- Response-code distribution and status-class traffic trend panels.
- Coverage for routed services even when those services do not expose
  dedicated Prometheus exporters.

`Alerting Triage` includes:

- Immediate alert-state cards (`firing`, `pending`, `critical`, `warning`).
- Alert breakdowns by alert name, severity, and instance.
- Target-down rollups by scrape job.
- Alert pipeline health panels:
  - Alertmanager notifications sent/failed rate.
  - Prometheus rule evaluations/failures rate.

`SMTP Relay Operations` includes:

- Runtime health cards for relay systemd and container presence.
- SMTP relay alert-state cards and alert-by-name panel.
- Runtime usage/throughput panels from cAdvisor:
  - CPU
  - memory working set
  - RX/TX network throughput
- Condition trend panels aligned with existing SMTP relay alerts.

`Service SLI` includes:

- Global SLI cards from Traefik telemetry:
  - request rate
  - success %
  - 5xx %
  - p95 latency
- Per-service ranking panels for:
  - request rate
  - 5xx %
  - p95 latency
  - success %
- Global trend panels for success/error percentages and status-class request
  rates.

`Pi-hole Operations` includes:

- Pi-hole status and target-up cards.
- DNS traffic/coverage cards (`queries today`, `ads blocked %`).
- Query behavior panels:
  - request rate by instance
  - cached vs forwarded queries
  - unique clients/domains
- Upstream resolver quality panels:
  - response time by destination
  - response variance by destination

`Logs Pipeline` includes:

- Promtail shipping health (`sent`, `dropped`, `retries`, push duration p95).
- Loki ingest health (`received` vs `discarded` lines).
- Gitea log signal panels from Loki:
  - total log volume
  - error-like log rate
  - raw logs panel for direct triage.

## Healthcheck units

- Service: `grafana-healthcheck.service`
- Timer: `grafana-healthcheck.timer`

## Backup units

- Service: `grafana-backup.service`
- Timer: `grafana-backup.timer`

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
