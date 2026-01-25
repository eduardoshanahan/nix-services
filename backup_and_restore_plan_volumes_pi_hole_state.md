# Backup & Restore Plan (Volumes + Pi-hole State)

> **Operator-validated plan**  
> This document contains both declarative steps (implemented by Codex) and operational validation gates (validated by a human operator).
>
> Codex MUST NOT attempt to automate, infer, or “satisfy” operator-validated checks.

This document defines the **backup and restore strategy** for stateful services deployed via Docker Compose on NixOS, with special focus on **Pi-hole state** and other persistent volumes.

It builds on:

- *Standard Service Template (NixOS + Docker Compose)*
- *Pi-hole Deployment Plan (Traefik + No-DNS → DNS Transition)*
- *Monitoring & Metrics Plan (Prometheus + Traefik)*

---

## 0. Goals and Non-Goals

### Goals

- Protect against SD card failure or corruption
- Enable fast recovery of Pi-hole configuration and data
- Provide a repeatable, low-complexity backup process
- Keep backups **host-external** whenever possible

### Non-goals

- Real-time replication
- Cross-site disaster recovery
- Encrypted offsite backups (may be added later)

---

## 1. Backup Scope Definition

### 1.1 What MUST be backed up

The following data is considered **critical state**:

- Docker volumes for Pi-hole:
  - `/etc/pihole`
  - `/etc/dnsmasq.d`
- Persistent volumes for other services (as applicable)
- Prometheus data directory (optional but recommended)

Only **persistent volumes** are backed up.

---

### 1.2 What MUST NOT be backed up

The following MUST NOT be included in backups:

- `/nix/store`
- NixOS system configuration (already in Git)
- Docker images (re-pullable)
- Runtime caches or temporary files

---

## 2. Backup Strategy (MANDATORY)

### 2.1 Backup model

- Backups are **file-level**, not image-level
- Backups are taken **from the host**, not from inside containers
- Backups target:
  - External disk
  - NAS
  - Or another trusted host

The exact destination is operator-defined.

---

### 2.2 Tooling

The following tools are acceptable:

- `rsync`
- `borg`
- `restic`

Codex MUST NOT assume one specific tool unless instructed.

---

## 3. Backup Implementation Pattern

### 3.1 Volume location

All services MUST store persistent data under deterministic paths, e.g.:

```text
/var/lib/<service-name>/
```

This is enforced by the Standard Service Template.

---

### 3.2 Backup target layout (example)

Example backup structure:

```text
backups/
  host-a/
    pihole/
    prometheus/
  host-b/
    pihole/
```

Hostnames are generic and non-identifying.

---

### 3.3 Consistency considerations

For Pi-hole:

- Short service interruptions are acceptable
- Backups MAY be taken while the container is running
- For maximum safety, the operator MAY stop Pi-hole briefly

Codex MUST NOT automate service shutdown.

---

## 4. Backup Schedule (OPERATOR-DEFINED)

Recommended baseline:

- Daily backups for Pi-hole state
- Weekly backups for Prometheus data

Scheduling (cron, systemd timers) is operator-defined and not committed.

---

## 5. Restore Strategy

### 5.1 Restore prerequisites

Before restoring, the operator MUST ensure:

- Host boots successfully into NixOS
- Docker and Traefik are deployed
- Target service module is enabled
- Containers are **stopped**

---

### 5.2 Restore procedure (Pi-hole)

High-level restore steps:

1. Stop the Pi-hole service (via systemd)
2. Restore backed-up directories to:
   - `/var/lib/pihole/`
3. Verify file ownership and permissions
4. Start the Pi-hole service
5. Validate UI and DNS behavior

Codex MUST NOT automate restore actions.

---

### 5.3 Restore validation

After restore, the operator MUST validate:

- [ ] Pi-hole UI loads correctly
- [ ] Blocklists and settings are present
- [ ] DNS queries succeed
- [ ] No errors appear in Pi-hole logs

---

## 6. Failure Modes and Guardrails

### 6.1 Partial restores

If restore results in inconsistent state:

- Stop the service
- Re-restore from the last known-good backup
- Avoid mixing backups from different points in time

---

### 6.2 SD card replacement scenario

If an SD card fails completely:

1. Flash a fresh NixOS image
2. Deploy services via the repo
3. Restore volumes from backup
4. Validate services

This is the expected recovery path.

---

## 7. Security Considerations

- Backups may contain sensitive DNS data
- Backup storage SHOULD be access-controlled
- Encryption at rest is RECOMMENDED but not mandatory at this stage

No secrets are committed to the repository.

---

## 8. Summary: Mandatory Execution Order

1. Operator defines backup destination and tool
2. Operator performs regular backups of `/var/lib/<service>`
3. On failure, operator redeploys host via NixOS
4. Operator restores service data
5. Operator validates service behavior

Codex MUST NOT skip steps or automate operator actions.
