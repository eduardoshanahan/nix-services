# Change Management & Upgrade Plan

> **Operator-validated plan**  
> This document defines how changes and upgrades are introduced safely into the system.
>
> Codex MUST NOT automate, infer, or execute operator-validated steps.

This plan governs **NixOS rebuilds**, **Docker image upgrades**, and **service configuration changes** across Raspberry Pi ARM64 boxes.

It builds on:
- *Architecture & Implementation Guidelines*
- *Standard Service Template (NixOS + Docker Compose)*
- *Backup & Restore Plan (Volumes + Pi-hole State)*
- *Disaster Recovery Drill Checklist (Safe Restore Testing)*

---

## 0. Goals and Principles

### Goals

- Introduce changes predictably and reversibly
- Avoid unnecessary downtime
- Detect breakage early
- Keep the system reproducible at all times

### Core principles

- **Small changes over big changes**
- **One dimension of change at a time**
- **Rollback is mandatory**
- **Production safety beats speed**

---

## 1. Change Classification

All changes MUST be classified before execution.

### 1.1 Configuration-only changes

Examples:
- NixOS module edits
- Traefik routing rules
- Service enable/disable

Risk level: **Low**

---

### 1.2 Service version changes

Examples:
- Docker image version bumps
- Traefik minor upgrades
- Pi-hole container updates

Risk level: **Medium**

---

### 1.3 System upgrades

Examples:
- NixOS channel upgrades
- Kernel changes
- Docker engine upgrades

Risk level: **High**

High-risk changes require additional safeguards.

---

## 2. General Change Rules (MANDATORY)

For *all* changes:

- [ ] Latest backups exist and are verified
- [ ] Change is committed to Git before deployment
- [ ] Change scope is documented (what/why)
- [ ] Only one change type is applied at a time

Codex MUST NOT combine unrelated changes.

---

## 3. Change Application Order

When multiple boxes exist, changes MUST be applied in this order:

1. Non-critical box
2. Secondary Pi-hole box
3. Primary Pi-hole box

This limits blast radius.

---

## 4. NixOS Rebuild Workflow

### 4.1 Preparation

Before running a rebuild:

- Ensure SSH access is stable
- Ensure Traefik and Pi-hole are healthy
- Confirm backups are current

---

### 4.2 Execution

Recommended command pattern:

```sh
nixos-rebuild switch --flake .#<host>
```

Rules:
- Rebuilds are executed manually
- No unattended upgrades

---

### 4.3 Rollback

If a rebuild causes issues:

- Roll back immediately:

```sh
nixos-rebuild switch --rollback
```

Rollback MUST restore previous working state.

---

## 5. Docker Image Upgrade Process

### 5.1 Upgrade rules

- Image versions MUST be pinned
- Only one service upgraded at a time
- No `latest` tags

---

### 5.2 Upgrade steps

1. Update image tag in `docker-compose.yml`
2. Commit change
3. Deploy via NixOS rebuild
4. Observe service behavior

---

### 5.3 Rollback

If a container misbehaves:

- Revert the image version
- Rebuild

No data migration occurs without explicit planning.

---

## 6. Traefik-Specific Changes

Traefik changes are **high-impact**.

Rules:

- Apply Traefik changes alone
- Validate routing and dashboard immediately
- Do not combine with other upgrades

---

## 7. NixOS Channel Upgrades

### 7.1 Strategy

- Prefer **stable channels**
- Upgrade infrequently
- Read release notes first

---

### 7.2 Execution order

1. Upgrade one non-critical box
2. Observe for at least 24 hours
3. Proceed to remaining boxes

---

## 8. Validation Checklist (OPERATOR-VALIDATED)

After any change, the operator MUST validate:

- [ ] Host boots successfully
- [ ] Traefik is running
- [ ] Pi-hole UI reachable
- [ ] DNS resolution works
- [ ] Metrics still flow to Prometheus

Failure to validate requires rollback.

---

## 9. Emergency Changes

In emergencies:

- Stabilize service first
- Document changes after
- Follow up with cleanup commits

Emergency changes must be minimized.

---

## 10. Documentation and Audit Trail

For every change:

- Commit messages MUST explain intent
- Keep change history in Git
- Avoid undocumented hotfixes

Git is the system of record.

---

## 11. Summary

- Classify every change
- Apply changes gradually
- Always keep rollback available
- Never upgrade blindly

This plan ensures long-term stability while still allowing evolution.

