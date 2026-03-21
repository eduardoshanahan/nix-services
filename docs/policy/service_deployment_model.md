# Service Deployment Model

This document defines **how services from `nix-services` are deployed onto physical hosts**.

It is intentionally **short, explicit, and restrictive**.

This model is **authoritative** and MUST be followed by both humans and Codex.

---

## 0. Purpose

The purpose of this document is to clearly answer one question:

> **How does a service defined in `nix-services` become active on a specific box?**

This document defines **policy**, not mechanics.

---

## 1. Repository Responsibilities (Hard Boundary)

### `nix-services`

This repository:

- Defines **what services exist**
- Defines **how services run** (Docker Compose + systemd)
- Defines **service-level options and requirements**
- Defines **operational policy** (TLS, monitoring, backups, upgrades)

This repository MUST NOT:

- Define hardware
- Define base OS images
- Define Raspberry Pi specifics
- Decide which physical box runs a service

---

### `nix-pi`

This repository:

- Defines **physical hosts**
- Defines **hardware and boot configuration**
- Defines **which services are enabled on which host**

All service deployment decisions occur here.

---

## 2. Deployment Mechanism (MANDATORY)

### 2.1 Import-based deployment

Services are deployed by **importing service modules** into host configurations.

Example (in `nix-pi`):

```nix
{
  imports = [
    nix-services.services.traefik
    nix-services.services.pihole
  ];
}
```

Rules:

- Imports are explicit
- No dynamic service discovery
- No conditional auto-enablement

---

### 2.2 Hosts as thin selectors

Hosts MUST:

- Select which services are enabled
- Provide only minimal, non-secret inputs

Hosts MUST NOT:

- Modify service internals
- Override Docker Compose definitions
- Contain service logic

---

## 3. Service Design Constraints

To support this deployment model, services MUST:

- Be fully self-contained
- Be reusable across hosts
- Have no hardcoded hostnames, IPs, or domains
- Expose configuration only via module options

Services MUST NOT:

- Detect host identity implicitly
- Branch behavior based on hostname
- Depend on hardware-specific assumptions

---

## 4. Roles and Variants (Optional, Restricted)

If role differentiation is required (e.g. primary vs secondary Pi-hole):

- Roles MUST be:
  - Explicit
  - Non-secret
  - Minimal

Example:

```nix
{
  services.pihole.role = "primary";
}
```

Roles MAY influence:

- Container naming
- UI hostnames
- Logging labels

Roles MUST NOT influence:

- Security boundaries
- Secrets
- Core runtime behavior

---

## 5. Enabling and Disabling Services

### 5.1 Enabling a service

To enable a service on a host:

1. Import the service module
2. Rebuild the host

No additional steps are allowed.

---

### 5.2 Disabling a service

To disable a service:

1. Remove the import
2. Rebuild the host

Data cleanup (volumes) is a **separate, operator-controlled action**.

---

## 6. Forbidden Patterns (Explicit)

The following are forbidden:

- Deploying services directly from `nix-services`
- Running `docker compose` manually on hosts
- Hardcoding host lists inside services
- Cross-host service dependencies
- Multi-host changes in a single commit

---

## 7. Change Control

Changes to deployment (which services run where):

- Are classified as **configuration-only changes**
- Must follow the *Change Management & Upgrade Plan*
- Must be applied incrementally (one host at a time)

---

## 8. Summary

- Services are defined in `nix-services`
- Hosts live in `nix-pi`
- Deployment happens via explicit imports
- Hosts are selectors, not implementers
- No automation decides placement

This model is intentionally simple and restrictive.
