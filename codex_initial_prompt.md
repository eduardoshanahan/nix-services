Before doing anything else:

1. Read and fully internalize codex_initial_prompt.md.
2. Confirm you understand that Traefik is already implemented and is a dependency.
3. Confirm you understand the Flake Interface Contract.

Task:

Implement the Pi-hole service in nix-services.

The implementation MUST strictly follow:

- Pi-hole Deployment Plan (Traefik + No-DNS → DNS Transition)
- Standard Service Template (NixOS + Docker Compose)
- Service Deployment Model

Scope:

- Create a new service under services/pihole/
- Provide:
  - docker-compose.yml
  - pihole.nix (systemd-supervised Docker Compose)
- Export the service via:
  - outputs.nixosModules.pihole
  - outputs.services.pihole

Mandatory technical requirements:

- Pi-hole MUST run behind Traefik for its web UI.
- Pi-hole MUST NOT bind host ports 80 or 443.
- Pi-hole DNS (port 53 TCP/UDP) MUST be defined but MUST NOT assume active usage yet.
- Pi-hole MUST join the Traefik Docker network.
- All state MUST be persisted via volumes.
- No secrets may appear in the repository.
- Secrets MUST be referenced only via external env files or runtime overlays.
- Role-specific values (primary vs secondary) MUST be configurable via module options.

Forbidden actions:

- Do NOT deploy Pi-hole to any host.
- Do NOT modify Traefik.
- Do NOT enable DNS cutover automatically.
- Do NOT add TLS.
- Do NOT add monitoring.
- Do NOT commit example passwords or tokens.

Deliverables:

- docker-compose.yml
- pihole.nix
- Updated flake exports exposing the Pi-hole service
- Minimal inline documentation explaining:
  - Pre-DNS UI access via Traefik + /etc/hosts
  - Persistence expectations
  - Manual DNS cutover (documented only)

Stop when the Pi-hole service is implemented and correctly exported.
If anything is unclear or conflicts with an authoritative document, STOP and ask.
