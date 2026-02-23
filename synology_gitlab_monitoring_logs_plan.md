# Synology + Pi Fleet Runbook (Sanitized)

This runbook defines a repository-safe plan for operating a Synology NAS alongside a Raspberry Pi fleet for:

- Self-hosted Git service (GitLab CE)
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
- GitLab CE

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
- [ ] Deploy GitLab CE.
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
- Confirm NAS storage volume has enough free space for GitLab + monitoring.

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
  gitlab/
    config/
    logs/
    data/
```

## Reverse Proxy (Optional but Recommended)

Use reverse proxy for internal service URLs and centralized TLS.

### Monitoring files to create privately

- `<nas-docker-root>/proxy/compose.yaml`
- `<nas-docker-root>/proxy/dynamic/tls.yaml`
- `<nas-docker-root>/proxy/certs/<wildcard-cert>.crt`
- `<nas-docker-root>/proxy/certs/<wildcard-cert>.key`

### Minimal compose pattern

```yaml
services:
  reverse-proxy:
    image: traefik:v3.6.7
    container_name: reverse-proxy
    restart: unless-stopped
    command:
      - --api.dashboard=true
      - --api.insecure=false
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --providers.file.directory=/etc/traefik/dynamic
      - --providers.file.watch=true
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./dynamic:/etc/traefik/dynamic:ro
      - ./certs:/certs:ro
    networks:
      - edge

networks:
  edge:
    name: edge
```

### TLS dynamic config pattern

```yaml
tls:
  certificates:
    - certFile: /certs/<wildcard-cert>.crt
      keyFile: /certs/<wildcard-cert>.key
```

## Monitoring Stack on Synology

### Files to create privately

- `<nas-docker-root>/monitoring/compose.yaml`
- `<nas-docker-root>/monitoring/prometheus/prometheus.yml`
- `<nas-docker-root>/monitoring/prometheus/alert.rules.yml`
- `<nas-docker-root>/monitoring/alertmanager/alertmanager.yml`

### Monitoring compose pattern

```yaml
services:
  prometheus:
    image: prom/prometheus:<pinned-version>
    container_name: prometheus
    restart: unless-stopped
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --storage.tsdb.path=/prometheus
      - --storage.tsdb.retention.time=30d
    volumes:
      - ./prometheus:/etc/prometheus:ro
      - ./prometheus-data:/prometheus
    networks:
      - edge
      - internal

  alertmanager:
    image: prom/alertmanager:<pinned-version>
    container_name: alertmanager
    restart: unless-stopped
    command:
      - --config.file=/etc/alertmanager/alertmanager.yml
      - --storage.path=/alertmanager
    volumes:
      - ./alertmanager:/etc/alertmanager:ro
      - ./alertmanager-data:/alertmanager
    networks:
      - internal

  grafana:
    image: grafana/grafana:<pinned-version>
    container_name: grafana
    restart: unless-stopped
    env_file:
      - ./grafana.env
    volumes:
      - ./grafana-data:/var/lib/grafana
    networks:
      - edge
      - internal

  uptime-kuma:
    image: louislam/uptime-kuma:<pinned-version>
    container_name: uptime-kuma
    restart: unless-stopped
    volumes:
      - ./uptime-kuma-data:/app/data
    networks:
      - edge
      - internal

networks:
  edge:
    external: true
  internal:
    name: internal
```

Notes:

- Keep credentials out of compose; use `env_file` or runtime secret files.
- Use pinned image versions. Avoid `latest`.
- Add reverse-proxy labels in private config only.

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
```

### Basic alert rule pattern

```yaml
groups:
  - name: basic
    rules:
      - alert: InstanceDown
        expr: up == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Instance down"
          description: "{{ $labels.instance }} is unreachable"
```

## GitLab CE on Synology

### Private file

- `<nas-docker-root>/gitlab/compose.yaml`

### GitLab compose pattern

```yaml
services:
  gitlab:
    image: gitlab/gitlab-ce:<pinned-version>
    container_name: gitlab
    restart: unless-stopped
    hostname: <gitlab-fqdn>
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'https://<gitlab-fqdn>'
        gitlab_rails['gitlab_shell_ssh_port'] = 2222
        nginx['listen_port'] = 80
        nginx['listen_https'] = false
    ports:
      - "2222:22"
    volumes:
      - ./config:/etc/gitlab
      - ./logs:/var/log/gitlab
      - ./data:/var/opt/gitlab
    shm_size: "256m"
    networks:
      - edge
      - internal

networks:
  edge:
    external: true
  internal:
    external: true
```

Notes:

- Do not place initial root password in repository files.
- Use private runtime configuration for credentials and SMTP settings.

## Loki on Logs Node

### Private directory layout

```text
<logs-root>/
  compose.yaml
  config/
    config.yaml
  data/
```

### Loki compose pattern

```yaml
services:
  loki:
    image: grafana/loki:<pinned-version>
    container_name: loki
    restart: unless-stopped
    command: ["-config.file=/etc/loki/config.yaml"]
    ports:
      - "3100:3100"
    volumes:
      - ./config:/etc/loki:ro
      - ./data:/loki
```

### Loki config pattern

```yaml
auth_enabled: false

server:
  http_listen_port: 3100

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

limits_config:
  retention_period: 30d

compactor:
  working_directory: /loki/compactor
  retention_enabled: true
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
- `<gitlab-fqdn>` -> `<nas-lan-ip>`
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
4. Deploy GitLab.
5. Deploy Loki on logs node.
6. Configure Prometheus scrape targets.
7. Configure Grafana datasources (Prometheus + Loki).
8. Validate dashboards, alerts, and Git operations.

## Session Decisions

### 2026-02-23

- Decision: start without Traefik on Synology.
- Rationale: Synology host ports `80/443` are already used by DSM, so initial rollout uses host-local published ports plus DSM reverse proxy later.
- Decision: use `/volume1/docker/homelab` as the Synology base directory for this stack.
- Decision: expose Grafana on LAN port `3000` during bootstrap to simplify operator onboarding; tighten access later behind DSM reverse proxy.
- Decision: after DSM reverse proxy validation, Grafana bind was tightened back to `127.0.0.1:3000` and external access is via `https://grafana.hhlab.home.arpa`.

## Current Implementation State

### Synology scaffold created

The following were created on Synology under `/volume1/docker/homelab`:

- `monitoring/compose.yaml`
- `monitoring/prometheus/prometheus.yml`
- `monitoring/prometheus/alert.rules.yml`
- `monitoring/alertmanager/alertmanager.yml`
- `monitoring/grafana.env`
- `gitlab/compose.yaml`

Compose validation was executed with:

- `docker compose -f /volume1/docker/homelab/monitoring/compose.yaml config`
- `docker compose -f /volume1/docker/homelab/gitlab/compose.yaml config`

Both validations passed.

### Git-tracked template copy

To support future sessions and reproducible handoff, a sanitized template copy is now tracked in this repository under:

- `synology-services/monitoring/compose.yaml`
- `synology-services/monitoring/prometheus/prometheus.yml`
- `synology-services/monitoring/prometheus/alert.rules.yml`
- `synology-services/monitoring/alertmanager/alertmanager.yml`
- `synology-services/monitoring/grafana.env.example`
- `synology-services/gitlab/compose.yaml`

These files are publication-safe templates and must be copied/adapted in private Synology storage before deployment.

### Important pre-start note

- `monitoring/grafana.env` currently contains `GF_SECURITY_ADMIN_PASSWORD=REPLACE_BEFORE_START`.
- Replace this value in Synology private storage before starting the monitoring stack.
- During bootstrap, Grafana may be temporarily published as `3000:3000` for direct LAN browser access.
- After DSM reverse proxy is validated, revert Grafana publish to `127.0.0.1:3000:3000`.

### Observed runtime fixes (2026-02-23)

- Symptom: `prometheus` restart loop with `permission denied` writing `/prometheus/queries.active`.
- Symptom: `grafana` restart loop with `GF_PATHS_DATA='/var/lib/grafana' is not writable`.
- Cause: Synology bind-mounted data directories had incompatible ownership for container users.
- Fix applied on Synology:
  - `chown -R 65534:65534 prometheus-data alertmanager-data`
  - `chown -R 472:472 grafana-data`
  - `chmod -R u+rwX,g+rX,o-rwx prometheus-data alertmanager-data grafana-data`
- Additional finding: `grafana.env` had an empty `GF_SECURITY_ADMIN_PASSWORD`, which is not acceptable for ongoing operation.
- Additional finding: Prometheus container DNS path did not resolve Pi hostnames reliably during bootstrap; scrape targets were temporarily switched to fixed LAN IPs.
- Follow-up: after Synology DNS was pointed to Pi-hole and local DNS entries were created, Prometheus scrape targets were switched back to FQDNs.
- Additional finding: GitLab Omnibus keys in `GITLAB_OMNIBUS_CONFIG` must keep quoted hash keys (for example `gitlab_rails['gitlab_shell_ssh_port']`). Unquoted forms fail startup with `UnknownConfigOptionError`.

### Current status checkpoint (2026-02-23 end-of-session)

- Monitoring stack is running on Synology and healthy:
  - Prometheus ready
  - Grafana health endpoint reports database OK
  - Alertmanager running
  - Uptime Kuma running
- Prometheus scrape targets are all `up` using DNS names:
  - `rpi-box-01.hhlab.home.arpa:9100`
  - `rpi-box-02.hhlab.home.arpa:9100`
  - `rpi-box-03.hhlab.home.arpa:9100`
  - `loki.hhlab.home.arpa:3100`
- Grafana is exposed via DSM reverse proxy at:
  - `https://grafana.hhlab.home.arpa`
- Grafana container bind was tightened to loopback only:
  - `127.0.0.1:3000:3000`
- GitLab container is healthy and login is confirmed.
- GitLab is exposed via DSM reverse proxy at:
  - `https://gitlab.hhlab.home.arpa`

## Validation Checklist

### Monitoring

- [ ] Grafana UI reachable at internal FQDN.
- [ ] Prometheus targets for nodes are `UP`.
- [ ] Alert rules loaded and firing test alert works.
- [ ] Uptime Kuma checks are reporting status.

### GitLab

- [ ] GitLab UI reachable at internal FQDN.
- [ ] SSH clone works on configured SSH port.
- [ ] Repository data persists across restarts.

### Logs

- [ ] Loki reachable from Grafana.
- [ ] Grafana Loki datasource is healthy.
- [ ] Logs from at least one node appear in Explore.

## Rollback Guidance

If an update fails:

- Revert to previous pinned image tag.
- Re-run `docker compose up -d` for the affected stack.
- Restore from last known-good backup if persistence is corrupted.

## Security Baseline

- Do not expose monitoring or Loki publicly.
- Use internal firewall policy to restrict access by source network.
- Keep all credentials in private runtime files (`env_file`, secret mounts, or external secret manager).
- Rotate credentials and certificates on an operator-defined schedule.

## Future Work

- Add authentication middleware for monitoring endpoints.
- Add backup automation for GitLab and Grafana state.
- Add capacity alerts for NAS volume and logs-node volume.
- Add Kubernetes scraping and log ingestion when cluster exists.
