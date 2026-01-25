# Standard Service Template (NixOS + Docker Compose)

> **Authoritative template**  
> This document defines the **canonical pattern** for adding any new service to this repository.
>
> Codex MUST use this template as the starting point for **all services** (Pi-hole, draw.io, future apps).

This template is compatible with:

- ARM64 (aarch64-linux)
- NixOS
- Docker + Docker Compose
- Traefik-first routing
- Operator-validated plans

---

## 0. Purpose of This Template

This template enforces:

- One service = one module
- Declarative ownership by NixOS
- No secrets in the repository
- systemd-supervised Docker Compose
- Compatibility with Traefik routing

Any deviation from this template MUST be justified explicitly.

---

## 1. Required Directory Structure

Every service MUST follow this layout:

```text
services/
  <service-name>/
    docker-compose.yml
    service.nix
```

Rules:

- `<service-name>` is lowercase and generic
- No service logic may exist outside this directory

---

## 2. docker-compose.yml (Canonical Pattern)

This file defines **only container-level concerns**.

### Mandatory rules

- No secrets (no passwords, tokens, keys)
- No `.env` files with values
- Explicit, pinned image versions
- Multi-arch images (ARM64 compatible)
- No host bindings for ports 80 or 443

### Canonical example

```yaml
version: "3.9"

services:
  app:
    image: example/app:1.2.3
    container_name: example-app
    restart: unless-stopped

    networks:
      - traefik

    volumes:
      - app-data:/var/lib/app

    environment:
      TZ: UTC

    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.app.rule=Host(`app.local`)"
      - "traefik.http.services.app.loadbalancer.server.port=8080"

volumes:
  app-data:

networks:
  traefik:
    external: true
```

### Notes

- The `traefik` network MUST already exist
- Hostnames (`app.local`) are placeholders and not real domains
- Ports are internal only; Traefik handles ingress

---

## 3. service.nix (Canonical Pattern)

This file defines **host-level ownership** of the service.

### Mandatory responsibilities

The NixOS module MUST:

- Ensure required directories exist
- Deploy the compose file to a deterministic path
- Define a systemd unit to manage the service lifecycle
- Depend on Docker and networking

### Canonical example (service.nix)

```nix
{ config, lib, pkgs, ... }:

let
  serviceName = "example";
  serviceDir = "/var/lib/${serviceName}";
  docker = config.virtualisation.docker.package;
in
{
  systemd.tmpfiles.rules = [
    "d ${serviceDir} 0755 root root -"
  ];

  environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

  systemd.services.${serviceName} = {
    description = "${serviceName} service (Docker Compose)";

    wantedBy = [ "multi-user.target" ];
    after = [ "docker.service" "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      WorkingDirectory = "/etc/${serviceName}";
      ExecStart = "${docker}/bin/docker compose up";
      ExecStop = "${docker}/bin/docker compose down";
      Restart = "always";
      RestartSec = "5s";
    };
  };
}
```

---

## 4. Secrets Handling (MANDATORY)

Secrets MUST NOT appear in either file.

Allowed patterns:

- Reference secret files by path:

```yaml
env_file:
  - /run/secrets/app.env
```

Secret files are:

- Injected at runtime
- Or provided by private overlays
- Or managed by encrypted secret tooling

---

## 5. Traefik Integration Rules

All HTTP services:

- MUST expose UI/API via Traefik only
- MUST NOT bind host ports 80 or 443
- MUST define Traefik labels in Compose

Traefik is the permanent ingress layer.

---

## 6. Host Integration Pattern

Hosts enable services **only by importing modules**.

Example:

```nix
{
  imports = [
    ../profiles/edge-box.nix
    ../services/example/service.nix
  ];
}
```

Hosts MUST NOT:

- Modify Docker Compose
- Override service internals

---

## 7. Validation Checklist (OPERATOR-VALIDATED)

Before considering a service complete, the operator MUST validate:

- [ ] Container is running
- [ ] Service survives container restart
- [ ] Service survives host reboot
- [ ] UI/API reachable via Traefik
- [ ] No unexpected port bindings on host

Codex MUST NOT proceed until validation passes.

---

## 8. Common Anti-Patterns (FORBIDDEN)

- Running `docker compose up` manually
- Committing `.env` files with values
- Binding host ports for HTTP services
- Hardcoding real domains or IPs
- Copying service logic into host files

---

## 9. Summary

- One service, one directory
- Compose defines containers only
- NixOS owns lifecycle
- Traefik owns ingress
- Secrets stay out of the repo

This template is mandatory for all services.
