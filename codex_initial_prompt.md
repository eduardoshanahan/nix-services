# Codex Initial Prompt — nix-services

You are working in the repository `nix-services`.

This repository defines **application services and operational policy**
for NixOS hosts running on ARM64.
It intentionally contains **no hardware bootstrap logic** and **no secrets**.

This repository is **execution-ready**.
All architectural decisions are already made and documented.

---

## AUTHORITATIVE DOCUMENTS (MANDATORY)

You MUST treat the following documents as authoritative and binding.
Do not contradict, bypass, or reinterpret them.

- Private vs Public Separation Guidelines
- Architecture & Implementation Guidelines
- Repository Boundary & Responsibility Guidelines
- ARM64-Specific Deployment Considerations
- Service Deployment Model
- Traefik-First Deployment Plan (Pre-DNS, Operator-Validated)
- Pi-hole Deployment Plan (Traefik + No-DNS → DNS Transition)
- TLS Enablement Plan (Post-DNS, Traefik)
- Standard Service Template (NixOS + Docker Compose)
- Monitoring & Metrics Plan (Prometheus + Traefik)
- Backup & Restore Plan (Volumes + Pi-hole State)
- Disaster Recovery Drill Checklist
- Change Management & Upgrade Plan

If a task conflicts with any document, STOP and ask for clarification.

---

## GLOBAL INVARIANTS (NON-NEGOTIABLE)

- Assume all target hosts are `aarch64-linux` (ARM64), even if development or testing
  occurs on other architectures.
- One service = one directory under `services/`.
- Docker Compose is owned and supervised by NixOS via systemd.
- Traefik permanently owns host ports **80 and 443**.
- No secrets, tokens, passwords, domains, IPs, or credentials
  may appear in the repository.
- Private data is injected only via ignored paths or runtime overlays.
- Operator-validated steps MUST NOT be automated or inferred.
- Changes must be incremental and isolated.

---

## FLAKE INTERFACE CONTRACT (MANDATORY)

The `nix-services` flake MUST expose services as NixOS modules.

Required interface:

- Every service MUST be exported under:
  - `outputs.nixosModules.<service-name>`
- A convenience alias MUST exist at:
  - `outputs.services.<service-name>`

Consumers MUST be able to import services as:

```nix
nix-services.services.<service-name>
```

This interface MUST be implemented before any service
can be considered complete or deployable.

---

## WORKING MODE

- Make the smallest change that moves the plan forward.
- Do not combine unrelated changes.
- Do not refactor without explicit instruction.
- Prefer clarity over cleverness.
- Treat repository documents as a contract, not guidance.
- When uncertain, STOP and ask.

---

## Implementation phase

- Follow the instructions in codex_implementation_prompt.md
