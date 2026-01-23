# Monitoring & Metrics Plan (Prometheus + Traefik)

> **Operator-validated plan**  
> This document contains both declarative steps (implemented by Codex) and operational validation gates (validated by a human operator).
>
> Codex MUST NOT attempt to automate, infer, or “satisfy” operator-validated checks.

This document defines the **monitoring and metrics architecture** for the homelab, based on **Prometheus** scraping metrics from **Traefik** and selected services.

It builds on:
- *Traefik-First Deployment Plan (Pre-DNS, Operator-Validated)*
- *TLS Enablement Plan (Post-DNS, Traefik)*
- *Standard Service Template (NixOS + Docker Compose)*

---

## 0. Goals and Scope

### Goals

- Provide visibility into system and service health
- Collect metrics from Traefik as the primary ingress
- Establish a reusable monitoring pattern for future services
- Keep monitoring **internal-only** and low-overhead

### Non-goals

- Alertmanager setup
- Long-term metrics retention
- External / cloud monitoring

---

## 1. Architectural Overview

### Monitoring roles

- **Prometheus**: metrics collection and storage
- **Traefik**: primary ingress and metrics source
- **Services**: optional metrics endpoints (future)

### Deployment model

- Prometheus runs as a **Docker Compose–managed service**
- Traefik exposes metrics internally
- No monitoring ports are exposed publicly

---

## 2. Preconditions (OPERATOR-VALIDATED, MUST be true)

These preconditions are **not enforced by code**.

Codex MUST assume they have been **manually validated by the operator** before proceeding.

The operator MUST confirm:

- [ ] Traefik is deployed and stable
- [ ] DNS is active and stable (via Pi-hole)
- [ ] TLS is enabled or intentionally deferred
- [ ] No monitoring services are currently deployed

### How to validate (informational, not automated)

- Traefik dashboard loads without errors
- Services are reachable via Traefik
- Host reboot does not break Traefik

If any item fails, STOP and fix it before continuing.

---

## 3. Traefik Metrics Enablement

### 3.1 Metrics strategy (MANDATORY)

Traefik metrics MUST:

- Use the **Prometheus metrics backend**
- Be exposed on an **internal-only entrypoint**
- NOT be exposed via the public Traefik routers

---

### 3.2 Traefik configuration changes

Codex MUST extend Traefik configuration to:

- Enable Prometheus metrics
- Bind metrics to a dedicated internal port (e.g. `:8082`)
- Disable insecure metrics exposure

Conceptual example (no secrets):

```yaml
metrics:
  prometheus:
    entryPoint: metrics
```

Actual port numbers are implementation details and MUST NOT conflict with other services.

---

## 4. Prometheus Service Deployment

### 4.1 Repository structure

Create a new service using the standard template:

```
services/
  prometheus/
    docker-compose.yml
    service.nix
```

---

### 4.2 Prometheus deployment rules

Prometheus MUST:

- Run behind Docker Compose
- Use a pinned, multi-arch image (ARM64 compatible)
- Store data in persistent volumes
- Scrape Traefik metrics over the Docker network

Prometheus UI MAY be exposed via Traefik for internal access.

---

### 4.3 Prometheus configuration handling

Prometheus configuration files:

- MUST be version-controlled
- MUST NOT contain secrets
- MAY reference scrape targets by service name

Example scrape target:

```yaml
- job_name: "traefik"
  static_configs:
    - targets: ["traefik:8082"]
```

---

## 5. Networking and Security Rules

### 5.1 Network isolation

- Prometheus and Traefik MUST share a Docker network
- Metrics ports MUST NOT be published to the host

---

### 5.2 Access control

- Metrics endpoints are **internal-only**
- No authentication is required initially
- External access is forbidden

---

## 6. Validation Checklist (OPERATOR-VALIDATED)

The operator MUST validate:

- [ ] Prometheus container is running
- [ ] Prometheus UI is reachable (if exposed)
- [ ] Traefik metrics appear in Prometheus
- [ ] No metrics ports are exposed on the host
- [ ] Metrics survive host reboot

Codex MUST NOT proceed until validation passes.

---

## 7. Failure Modes and Guardrails

### 7.1 Missing metrics

If Traefik metrics do not appear:

- Verify metrics entrypoint is enabled
- Confirm Prometheus scrape target matches Traefik service name
- Check Docker network connectivity

---

### 7.2 Resource pressure

If Prometheus causes high CPU or memory usage:

- Reduce scrape frequency
- Limit retention period
- Reduce enabled metrics

---

## 8. Future Extensions (Out of Scope)

- Alertmanager integration
- Grafana dashboards
- Node exporter / host metrics
- Service-level SLOs

Each requires a separate plan.

---

## 9. Summary: Mandatory Execution Order

1. Operator validates Traefik and DNS stability
2. Enable Traefik Prometheus metrics
3. Deploy Prometheus service via standard template
4. Configure Prometheus to scrape Traefik
5. Operator validates metrics visibility

Codex MUST NOT skip steps.

