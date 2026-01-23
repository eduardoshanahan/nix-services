# Traefik-First Deployment Plan (Pre-DNS)

> **Operator-validated plan**  
> This document contains both declarative steps (implemented by Codex) and operational validation gates (validated by a human operator).
>
> Codex MUST NOT attempt to automate, infer, or “satisfy” operator-validated checks.

This document defines the **step-by-step implementation plan** for introducing **Traefik** as the first service on ARM64 NixOS boxes, explicitly supporting **deployment and testing before DNS is active**.

This plan is written to be **directly executable by Codex** and establishes the HTTP foundation required for all subsequent services (including Pi-hole).

---

## 0. Goal and Constraints

### Primary goal

- Deploy Traefik as the **first service** on each box
- Make Traefik usable and testable **without relying on DNS**
- Establish a repeatable HTTP routing pattern for all future services

### Constraints

- DNS (Pi-hole) is NOT available yet
- No public domains are assumed
- No secrets may be committed
- Docker Compose MUST be owned and supervised by NixOS

---

## 1. Preconditions (OPERATOR-VALIDATED, MUST be true)

These preconditions are **not enforced by code**.

Codex MUST assume they have been **manually validated by the operator** before proceeding with Traefik implementation.

Before starting Traefik work, the operator MUST confirm:

- [ ] Target host boots successfully into **NixOS (ARM64)**
- [ ] SSH access to the host is available
- [ ] No service is currently binding host ports **80 or 443**
- [ ] Internet connectivity is available for Docker image pulls

### How to validate (informational, not automated)

- **Boot & SSH**: Reboot the host and confirm SSH access
- **Port ownership**: `ss -lntup | grep ':80\|:443'` returns no listeners
- **Connectivity**: `ping -c 3 1.1.1.1`

If any item fails, STOP and resolve it before continuing.

---

## 2. Repository Preparation (Required First Step)

Codex MUST ensure the following structure exists:

```
flake.nix
hosts/
profiles/
services/
  traefik/
secrets/        # empty placeholder
hosts-private/  # empty placeholder
```

No Traefik logic may exist outside `services/traefik/`.

---

## 3. Traefik Service Module

### 3.1 Directory layout

Create the following:

```
services/traefik/
  docker-compose.yml
  traefik.nix
```

---

### 3.2 Traefik design requirements (MANDATORY)

Traefik MUST:

- Run via Docker Compose
- Bind to host ports **80 and 443**
- Expose the Traefik dashboard
- Use the **Docker provider only**
- Use a pinned, multi-arch image compatible with **linux/arm64**

Traefik permanently owns ports 80 and 443.

TLS automation (Let’s Encrypt) MUST NOT be enabled at this stage.

---

## 4. Pre-DNS Routing Strategy (MANDATORY)

Until DNS exists, routing MUST rely on **HTTP Host headers**.

### Client-side testing (not committed)

The operator may add temporary `/etc/hosts` entries on a client machine:

```
<BOX_IP> traefik.local
```

Traefik routers MUST use `Host()` rules for these names.

Codex MUST NOT commit `/etc/hosts` entries.

---

## 5. Docker Compose Rules for Traefik

The Traefik `docker-compose.yml` MUST:

- Contain **no secrets**
- Pin the Traefik image version (no `latest`)
- Expose ports 80 and 443
- Enable the dashboard
- Use conservative logging defaults suitable for ARM64
- Attach Traefik to a dedicated Docker network (e.g. `traefik`)

---

## 6. NixOS Ownership (systemd-managed Compose)

The `traefik.nix` module MUST:

- Enable Docker (directly or via profile)
- Install the Docker Compose plugin
- Ensure required directories exist via `tmpfiles`
- Deploy the compose file to a deterministic runtime location
- Define a systemd unit that:
  - Starts Traefik on boot
  - Restarts on failure
  - Runs **after** `docker.service` and `network-online.target`

Manual `docker compose` commands are forbidden.

---

## 7. Host Integration

Hosts MUST enable Traefik **only by importing the service module**.

Example:

```nix
{
  imports = [
    ../profiles/edge-box.nix
    ../services/traefik/traefik.nix
  ];
}
```

Hosts MUST NOT modify Traefik behavior directly.

---

## 8. Validation Checklist (Traefik Only)

After deployment, the operator MUST validate:

- [ ] Host boots successfully with Traefik enabled
- [ ] Docker starts automatically
- [ ] Traefik container is running
- [ ] Traefik dashboard is reachable via browser (using `/etc/hosts`)
- [ ] Ports 80 and 443 are bound by Traefik only
- [ ] Rebooting the host restarts Traefik automatically

Codex MUST NOT proceed to other services until this checklist passes.

---

## 9. Dependency Rule for Future Services

All future HTTP services (including Pi-hole):

- MUST run **behind Traefik**
- MUST NOT bind to host ports 80 or 443
- MUST rely on Traefik routing for UI/API exposure

This rule is permanent.

---

## 10. Summary: Mandatory Execution Order

1. Operator validates preconditions
2. Repository structure is prepared
3. Traefik service module is implemented
4. Docker Compose is owned by NixOS
5. Host imports Traefik service
6. Operator validates Traefik behavior
7. Only then may additional services be added

Codex MUST NOT skip steps.

