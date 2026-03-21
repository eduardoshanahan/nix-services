# Architecture & Implementation Guidelines

This document defines the **mandatory architectural model** for this
repository and provides concrete implementation guidance for shared service
modules and their public documentation.

---

## 1. Architectural Model (Authoritative)

This repository is the **shared service layer** in a multi-repository homelab
architecture.

The core rules are:

- ✅ **Consumer repos choose placement** (they decide what runs where)
- ✅ **Services are reusable modules** (they define how things run)
- ✅ **Public docs stay host-agnostic**
- ✅ **Docker Compose is owned and orchestrated by NixOS**

Imperative Docker usage and host-owned service internals are not allowed here.

---

## 2. Separation of Responsibilities

### 2.1 Consumer Repositories

Consumer repositories such as `nix-pi` describe **identity and intent**, not
shared service implementation details.

Consumer repos:

- import service modules from `nix-services`
- set minimal host-specific values (hostname, role, private paths)
- MUST NOT copy shared service logic into host files
- MUST own hardware, bootstrap, and secret provisioning

---

### 2.2 Host-Owned Common Layers

Cross-cutting host concerns belong in the owning consumer repo, not here.

Examples:

- Base OS configuration
- Docker enablement
- Common users and SSH settings
- Logging, time sync, firewall defaults

These layers may enable prerequisites for services, but they MUST NOT redefine
shared service behavior from this repository.

---

### 2.3 Services

Services are the **unit of reuse** in this repository.

Each service:

- Lives in its own module (e.g. `services/pihole.nix`)
- Encapsulates all logic for running that application
- Can be imported by any host

Services MAY:

- Define Docker Compose stacks
- Create systemd units
- Manage volumes and networks

Services MUST NOT:

- Assume a specific host
- Hardcode secrets
- Hardcode hostnames, IPs, or domains

---

## 3. Docker Compose Ownership Model

Docker and Docker Compose are treated as **runtime tools**, but they are **controlled declaratively by NixOS**.

### 3.1 Forbidden Patterns

Codex MUST NOT:

- SSH into a host and run `docker compose up`
- Require manual Docker commands for persistence
- Rely on undocumented runtime state

Imperative Docker usage is forbidden.

---

### 3.2 Required Pattern

Docker Compose stacks MUST be:

- Defined in the repository
- Started and supervised via systemd
- Restarted automatically on boot or failure

Typical flow:

1. NixOS installs Docker
2. NixOS installs Docker Compose plugin
3. NixOS deploys Compose files
4. NixOS manages lifecycle via systemd

---

## 4. Docker Compose File Rules

Docker Compose files:

- MUST live under the corresponding service directory
- MUST be static or template-generated
- MUST NOT contain secrets
- MAY reference external env files or secret paths

Allowed example:

```yaml
env_file:
  - /run/secrets/app.env
```

Forbidden example:

```yaml
environment:
  PASSWORD=changeme
```

---

## 5. Service Implementation Pattern (Reference)

Each service module SHOULD follow this structure:

```text
services/
  pihole/
    docker-compose.yml
    service.nix
```

Example `service.nix` pattern:

```nix
{ config, lib, ... }:
{
  systemd.services.pihole = {
    wantedBy = [ "multi-user.target" ];
    after = [ "docker.service" ];
    serviceConfig = {
      ExecStart = "${lib.getExe config.virtualisation.docker.package} compose up";
      ExecStop = "${lib.getExe config.virtualisation.docker.package} compose down";
      WorkingDirectory = "/var/lib/pihole";
      Restart = "always";
    };
  };
}
```

Codex MAY adapt details but MUST preserve the pattern.

---

## 6. Evaluation Safety Requirements

The public repository MUST:

- Evaluate without private files
- Build without secrets
- Support dry evaluation (`nix flake check`)

Private configuration MUST be optional and additive.

---

## 7. Naming and Structure Guidelines

Recommended top-level layout:

```text
flake.nix
lib/
services/
docs/
```

Naming rules:

- Use role-based names, not real identities
- Avoid environment-specific naming (prod, home, office)
- Prefer clarity over brevity

---

## 8. Migration & Future-Proofing

This architecture intentionally supports:

- Adding more consumers without duplicating shared service logic
- Moving selected services to Kubernetes later
- Keeping edge / stateful services outside K8s

Codex MUST NOT introduce patterns that block future migration.

---

## 9. Summary (Non-Negotiable Rules)

- Consumer repos select, services implement
- Docker Compose is declarative and supervised
- No secrets in repo
- No imperative Docker usage
- Public repo must always evaluate

Failure to follow these rules is considered a bug.

---

## 10. Final Note for Codex

When in doubt:

> **Prefer composability, explicitness, and reversibility.**

These properties are more important than speed or convenience.
