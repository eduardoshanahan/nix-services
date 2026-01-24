# Codex Implementation Prompt — nix-services

## CURRENT PHASE

The project is in **Phase 2.1: Traefik Version 3.6.7**.

Your task is:

> Implement Traefik version 3.6.7 strictly following  
> **Traefik-First Deployment Plan (Pre-DNS, Operator-Validated)**  
> using the **Standard Service Template**  
> and exposing the service according to the **Flake Interface Contract**.

**Do NOT preserve backward compatibility with Traefik v2 configuration**
Use Traefik v3-native configuration only.

**Traefik MUST enable only the Docker provider.**
File provider, Kubernetes provider, and experimental providers MUST NOT be enabled.
The existing current implementation is not a constraint and can be deleted and start from scratch if beneficial.
However, the service directory structure and flake interface contract MUST be preserved.

**Assume no DNS, no ACME, and no TLS certificates exist.**
Traefik MUST operate in HTTP-only mode initially.

**Traefik MUST be supervised by systemd and configured to restart automatically on failure.**

Do NOT:

* Add Pi-hole
* Add TLS
* Add monitoring
* Deploy Traefik to any host
* Modify host behavior beyond what Traefik requires

Stop once Traefik is implemented and correctly exported.
Wait for explicit instruction before proceeding past Traefik.
