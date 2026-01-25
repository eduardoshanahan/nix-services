# Runtime Secrets Pattern for Stateful Docker Services on NixOS

This document records the architectural conclusions and patterns derived from
the Pi-hole v6 deployment in the NixOS homelab.

The goal is to establish a **reusable, correct, and secure pattern** for running
stateful Docker services that require secrets at startup, without violating
NixOS principles or leaking secrets into the Nix store.

---

## Problem Statement

Many Dockerized services (including Pi-hole v6) have the following constraints:

- Require secrets (passwords, tokens) **at first startup**
- Expect secrets as **plain environment variables**
- Do **not** support `*_FILE` indirection reliably
- Persist internal state in volumes after initialization

At the same time, NixOS imposes important constraints:

- Secrets **must not** be stored in the Nix store
- Secrets **must not** be committed to Git
- Declarative configuration should not rely on manual, one-off steps
- Host-specific concerns (secrets, hardware) must be separated from service logic

---

## Repository Responsibilities

### `nix-pi` (Host / Machine Layer)

Responsible for:

- Hardware configuration
- Base NixOS configuration
- Users, SSH, networking
- Firewall configuration
- **Secret provisioning via `sops-nix`**

Must **not**:

- Define service internals
- Override systemd units for services
- Contain Docker Compose logic

---

### `nix-services` (Service Layer)

Responsible for:

- Docker Compose definitions
- systemd units
- Runtime glue logic
- Service-specific options and contracts

Must **not**:

- Provision secrets
- Depend on `sops-nix`
- Know how secrets are generated or encrypted
- Contain secret values

---

## The Runtime Secrets Pattern

### Core Idea

> **Secrets are provisioned by the host, consumed by services at runtime,
> and never stored in the Nix store.**

This is achieved by generating a **runtime-only environment file** during
`ExecStartPre`, which Docker Compose then consumes.

---

## Pattern Overview

### 1. Host provisions the secret (nix-pi)

```nix
sops.secrets.service-admin-password = {
  sopsFile = ../../../secrets/service.yaml;
  key = "admin-password";
  path = "/run/secrets/service-admin-password";
  owner = "root";
  group = "root";
  mode = "0400";
};
```

The secret exists only at runtime under `/run/secrets`.

---

### 2. Service declares a secret *path* option (nix-services)

```nix
webPasswordFile = lib.mkOption {
  type = lib.types.nullOr lib.types.path;
  default = null;
  description = "Path to a runtime-provisioned secret file.";
};
```

The service **does not know** where the secret comes from.

---

### 3. Enforce correctness early (assertion)

```nix
assertions = [
  {
    assertion = cfg.webPasswordFile != null;
    message = "webPasswordFile must be set when enabling this service.";
  }
];
```

This fails fast at evaluation time if the service is misconfigured.

---

### 4. Generate a runtime env file (systemd `ExecStartPre`)

```sh
secret_file="${cfg.webPasswordFile}"

if [[ -z "$secret_file" || ! -s "$secret_file" ]]; then
  echo "Missing or empty secret file" >&2
  exit 1
fi

password="$(cat "$secret_file")"
password="${password%$'\n'}"

install -d -m 0700 /run/secrets
printf 'SERVICE_ADMIN_PASSWORD="%s"\n' "$password" \
  > /run/secrets/service.env
```

Key properties:

- Runs **after secrets are materialized**
- Writes only to `/run`
- No secrets enter the Nix store
- Deterministic on every start

---

### 5. Docker Compose consumes the env file

```yaml
services:
  app:
    image: example/app
    env_file:
      - /run/secrets/service.env
```

This satisfies services that require plain env vars at startup.

---

## Why This Pattern Works

### Security

- Secrets never appear in:
  - Git
  - Nix store
  - systemd unit files
  - Docker Compose files
- Files are readable only by root
- Secrets are regenerated on every start

---

### Reproducibility

- First boot is deterministic
- Rebuilds do not require manual intervention
- Volume wipes reinitialize correctly
- No “run this once” steps

---

### Architecture

- Clear separation of concerns
- Services are reusable across hosts
- Hosts remain boring and declarative
- No host-specific service overrides

---

## Firewall & Exposure Considerations

- Docker **does not** provide security boundaries
- Host firewall must be enabled explicitly
- Open only required ports declaratively

Example baseline:

```nix
networking.firewall = {
  enable = true;

  allowedTCPPorts = [ 53 80 443 ];
  allowedUDPPorts = [ 53 ];
};
```

Service-level warnings about “dangerous options” must be evaluated **in context
of the firewall**, not in isolation.

---

## When to Use UI vs Declarative Config

**Declarative (must):**
- Secrets
- Ports
- Users
- Process lifecycle
- Networking

**UI acceptable (often better):**
- Service-specific operational toggles
- Runtime policies internal to the service
- Stateful behavior that the service owns

Example: Pi-hole DNS listening mode.

---

## Applicability

This pattern applies directly to:

- Pi-hole v6+
- Grafana admin bootstrap
- Postgres initial users
- Keycloak admin setup
- Any service requiring env-based secrets at init time

---

## Summary

This pattern allows NixOS to manage **processes and secrets** while letting
stateful services manage **their own internal state**, without compromising:

- Security
- Reproducibility
- Maintainability
- Architectural boundaries

It should be considered the **default approach** for Dockerized stateful services
in this homelab.

