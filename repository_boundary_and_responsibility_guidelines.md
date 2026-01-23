# Repository Boundary & Responsibility Guidelines

This document defines **where functionality belongs** across repositories and establishes **hard boundaries** between foundational infrastructure and deployed services.

It is **authoritative** and MUST be followed by **Codex / AI-assisted development** and humans alike.

---

## 1. Core Decision (Non‑Negotiable)

The system is split across **multiple repositories with clear responsibility boundaries**.

### Mandatory split

- ✅ **Foundation repository** (e.g. `nix-pi`)
- ✅ **Services repository** (this repository)

These repositories serve **different purposes** and MUST NOT be merged or blurred.

---

## 2. Foundation Repository (e.g. `nix-pi`)

### Purpose

The foundation repository exists to answer exactly one question:

> **How do we reliably boot and provision NixOS on Raspberry Pi hardware?**

### Allowed contents

The foundation repository MAY contain:

- Raspberry Pi hardware enablement
- Bootloader and firmware handling
- SD image builders
- Minimal base NixOS profiles
- Hardware‑specific fixes and workarounds

### Forbidden contents

The foundation repository MUST NOT contain:

- Application services (Pi‑hole, Traefik, etc.)
- Docker Compose stacks
- Host‑specific roles or intent
- Policy decisions about workloads
- Secrets or secret placeholders

### Stability expectations

- Changes are **infrequent and conservative**
- Backward compatibility is preferred
- The repo must remain **generic and reusable**

The foundation repo is **infrastructure**, not environment policy.

---

## 3. Services Repository (This Repository)

### Purpose

The services repository exists to answer a different question:

> **What do we run on our machines, and how is it operated?**

### Allowed contents

This repository MAY contain:

- Hosts (thin selectors)
- Profiles (policy and cross‑cutting concerns)
- Services as reusable modules
- Docker Compose–based applications
- Orchestration logic via NixOS + systemd
- Optional private overlays and secret references

### Forbidden contents

This repository MUST NOT:

- Re‑implement Raspberry Pi hardware support
- Fork or copy foundation logic
- Assume responsibility for bootstrapping hardware

All hardware and image concerns MUST come from the foundation repo.

---

## 4. Dependency Direction (MANDATORY)

Dependencies MUST flow in **one direction only**:

```
services repo  ──▶  foundation repo (nix‑pi)
```

Rules:

- The services repo MAY import the foundation repo as a flake input
- The foundation repo MUST NOT depend on the services repo
- Circular dependencies are forbidden

Example:

```nix
inputs = {
  nix-pi.url = "github:eduardoshanahan/nix-pi";
};
```

This direction preserves reuse and prevents coupling.

---

## 5. Decision Heuristic (Required Test)

Before adding anything, Codex MUST ask:

> **Could this repository be useful to someone who does not share our operational goals?**

- If **yes** → it belongs in the foundation repo
- If **no** → it belongs in the services repo

Examples:

- NixOS SD image builder → foundation
- Docker enablement for homelab → services
- Pi‑hole configuration → services
- Raspberry Pi boot fixes → foundation

---

## 6. Why This Boundary Exists

This split is intentional and provides:

- Long‑term maintainability
- Safe public publication
- Reuse across multiple future projects
- Clear mental model for Codex
- Reduced risk of secret leakage

Violating this boundary leads to:
- Repository sprawl
- Policy leakage
- Confused ownership
- Hard‑to‑reuse code

---

## 7. Enforcement

- Codex MUST NOT add services to the foundation repo
- Codex MUST NOT add hardware logic to the services repo
- Violations are considered architectural bugs

When unsure, **do not add code** and request clarification.

---

## 8. Summary

- Foundation repo = hardware + boot + images
- Services repo = hosts + services + policy
- Clear dependency direction
- No responsibility overlap

This boundary is essential to the long‑term health of the system.

