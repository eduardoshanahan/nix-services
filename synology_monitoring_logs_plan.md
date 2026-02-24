# Synology + Pi Fleet Runbook (Monitoring + Logs, Sanitized)

This runbook defines a repository-safe plan for operating a Synology NAS alongside a Raspberry Pi fleet for:

- Monitoring stack (Prometheus, Grafana, Alertmanager, Uptime Kuma)
- Centralized logs (Loki on a separate log node)

This document is intentionally generic and contains no real domains, IPs, credentials, or secrets.

## Scope

This document covers:

- Synology host preparation
- Container layout and deployment order
- Monitoring and logging integration points
- Validation and rollback checkpoints

This document does not cover:

- Hardware bootstrap or NixOS host provisioning
- Public internet exposure design
- Production-grade HA
- Git server deployment (intentionally deferred)

## Naming and Placeholder Policy

Use placeholders and replace them in your private environment:

- `<internal-domain>`: internal DNS zone (example format: `internal.arpa`)
- `<nas-fqdn>`: NAS management FQDN
- `<nas-lan-ip>`: NAS LAN IP
- `<logs-node-fqdn>`: Loki host FQDN
- `<logs-node-lan-ip>`: Loki host LAN IP
- `<service-fqdn>`: service FQDN pattern, such as `grafana.<internal-domain>`

Never commit:

- Real hostnames
- Real IP addresses
- Passwords, tokens, private keys, cert/key material

## Target Layout

### Synology (primary)

Runs in containers:

- Reverse proxy (optional but recommended)
- Prometheus
- Grafana
- Alertmanager
- Uptime Kuma

### Logs node (separate host)

Runs in containers:

- Loki (single-node)

### Pi/NixOS nodes checklist

Run agents:

- node exporter for metrics
- promtail (or equivalent) for log shipping to Loki

## High-Level Checklist

### Synology

- [ ] Verify DSM version supports current Container Manager features.
- [ ] Install/update Container Manager.
- [ ] Enable SSH for operator access.
- [ ] Create container data directories under your NAS volume.
- [ ] Deploy reverse proxy (if used).
- [ ] Deploy monitoring stack.
- [ ] Create internal DNS records in private DNS.
- [ ] Attach TLS certs in a private, non-repository location.

### Logs node

- [ ] Prepare persistent storage.
- [ ] Deploy Loki.
- [ ] Restrict Loki to LAN/internal access.
- [ ] Configure retention policy.

### Pi/NixOS nodes

- [ ] Enable node exporter on each node.
- [ ] Enable promtail shipping to Loki.
- [ ] Add scrape targets to Prometheus.

## Synology Preparation

### 1. Validate platform

- Confirm DSM and Container Manager are healthy.
- Confirm NAS storage volume has enough free space for monitoring.

### 2. Create directory structure

Create a deterministic layout in your private environment, for example:

```text
<nas-docker-root>/
  proxy/
  monitoring/
    prometheus/
    prometheus-data/
    grafana-data/
    alertmanager/
    alertmanager-data/
    uptime-kuma-data/
```

## Reverse Proxy (Optional but Recommended)

Use reverse proxy for internal service URLs and centralized TLS.

### Monitoring files to create privately

- `<nas-docker-root>/proxy/compose.yaml`
- `<nas-docker-root>/proxy/dynamic/tls.yaml`
- `<nas-docker-root>/proxy/certs/<wildcard-cert>.crt`
- `<nas-docker-root>/proxy/certs/<wildcard-cert>.key`

## Monitoring Stack on Synology

### Files to create privately

- `<nas-docker-root>/monitoring/compose.yaml`
- `<nas-docker-root>/monitoring/prometheus/prometheus.yml`
- `<nas-docker-root>/monitoring/prometheus/alert.rules.yml`
- `<nas-docker-root>/monitoring/alertmanager/alertmanager.yml`

### Prometheus scrape pattern

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - /etc/prometheus/alert.rules.yml

alerting:
  alertmanagers:
    - static_configs:
        - targets: ["alertmanager:9093"]

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["prometheus:9090"]

  - job_name: "nodes"
    static_configs:
      - targets:
          - "<node-1-fqdn>:9100"
          - "<node-2-fqdn>:9100"
          - "<node-3-fqdn>:9100"

  - job_name: "loki"
    static_configs:
      - targets: ["<logs-node-fqdn>:3100"]
```

## Loki on Logs Node

### Private directory layout

```text
<logs-root>/
  compose.yaml
  config/
    config.yaml
  data/
```

## NixOS Agent Integration (Generic)

### node exporter

Enable node exporter on each node and expose port `9100` internally.

### promtail

Configure promtail (or equivalent) to push logs to:

- `http://<logs-node-lan-ip>:3100/loki/api/v1/push`

Keep this endpoint internal-only.

## DNS and TLS Guidance

### DNS

Create private DNS records in your internal DNS system:

- `<grafana-fqdn>` -> `<nas-lan-ip>`
- `<uptime-fqdn>` -> `<nas-lan-ip>`
- Optional: `<prometheus-fqdn>` -> `<nas-lan-ip>`

### TLS

- Keep certificate files outside this repository.
- Terminate TLS at reverse proxy when possible.
- Keep NAS management plane certificate lifecycle separate from app routing certificates.

## Deployment Order

1. Prepare Synology directories and permissions.
2. Deploy reverse proxy (if used).
3. Deploy monitoring stack.
4. Deploy Loki on logs node.
5. Configure Prometheus scrape targets.
6. Configure Grafana datasources (Prometheus + Loki).
7. Validate dashboards and alerts.

## Session Decisions

### 2026-02-23

- Decision: start without Traefik on Synology.
- Rationale: Synology host ports `80/443` are already used by DSM, so initial rollout uses host-local published ports plus DSM reverse proxy later.
- Decision: use `/volume1/docker/homelab` as the Synology base directory for this stack.
- Decision: expose Grafana on LAN port `3000` during bootstrap to simplify operator onboarding; tighten access later behind DSM reverse proxy.
- Decision: after DSM reverse proxy validation, Grafana bind was tightened back to `127.0.0.1:3000` and external access is via `https://grafana.<homelab-domain>`.

### 2026-02-24

- History note: GitLab was tested on Synology DS918+ and removed because it was too heavy for this host.

## Current Implementation State

### Synology scaffold created

The following were created on Synology under `/volume1/docker/homelab`:

- `monitoring/compose.yaml`
- `monitoring/prometheus/prometheus.yml`
- `monitoring/prometheus/alert.rules.yml`
- `monitoring/alertmanager/alertmanager.yml`
- `monitoring/grafana.env`

### Git-tracked template copy

A sanitized template copy is tracked in this repository under:

- `synology-services/monitoring/compose.yaml`
- `synology-services/monitoring/prometheus/prometheus.yml`
- `synology-services/monitoring/prometheus/alert.rules.yml`
- `synology-services/monitoring/alertmanager/alertmanager.yml`
- `synology-services/monitoring/grafana.env.example`

These files are publication-safe templates and must be copied/adapted in private Synology storage before deployment.

## Validation Checklist

### Monitoring

- [ ] Grafana UI reachable at internal FQDN.
- [ ] Prometheus targets for nodes are `UP`.
- [ ] Alert rules loaded and firing test alert works.
- [ ] Uptime Kuma checks are reporting status.

### Logs

- [ ] Loki reachable from Grafana.
- [ ] Grafana Loki datasource is healthy.
- [ ] Logs from at least one node appear in Explore.

## Rollback Guidance

If an update fails:

- Revert to previous pinned image tag.
- Re-run `docker compose up -d` for the affected stack.

## Security Baseline

- Do not expose monitoring or Loki publicly.
- Use internal firewall policy to restrict access by source network.
- Keep all credentials in private runtime files (`env_file`, secret mounts, or external secret manager).
- Rotate credentials and certificates on an operator-defined schedule.

## Future Work

- Add authentication middleware for monitoring endpoints.
- Add backup automation for monitoring and logs state.
- Add capacity alerts for NAS volume and logs-node volume.
