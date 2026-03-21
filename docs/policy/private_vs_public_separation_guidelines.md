# Separation of Public and Private Concerns

This document defines **mandatory guidelines** for keeping this repository safe to publish while still allowing real infrastructure to be deployed from it.

It is written both for **humans** and for **Codex / AI-assisted development**. Codex MUST follow these rules when modifying or extending this repository.

---

## 1. Core Principle

> **The public repository contains structure, not secrets.**

This repo is a **blueprint**, not a live configuration dump.

Anything committed here must be safe to:

- Read by strangers
- Index by search engines
- Be reused by others

If a file or value would compromise security if published, it **does not belong here**.

---

## 2. What Is Allowed in the Public Repository

The following are explicitly allowed and encouraged:

- Nix flakes, modules, and profiles
- Host *roles* (e.g. "dns-box", "edge-box")
- Service definitions (Pi-hole, Traefik, etc.)
- Docker and Docker Compose orchestration logic
- Build-time configuration
- Placeholder directory structure for private data

All of the above must be **generic**, **reusable**, and **non-identifying**.

---

## 3. What Is NOT Allowed in the Public Repository

Codex MUST NOT add or commit:

- Secrets of any kind
  - Passwords
  - API tokens
  - Private keys
  - OAuth credentials
- `.env` files with real or fake values
- Inline credentials inside Nix, YAML, or scripts
- Internal IP addresses or real network topology
- Real domain names or DNS zones
- Comments describing real infrastructure details

> ⚠️ **Important**: Fake or "temporary" secrets are treated as real secrets and are NOT allowed.

---

## 4. Private Directories: How to Use Them Safely

Private directories should generally live outside the public repo in a sibling
private companion repo or local untracked workspace.

### Forbidden contents

- Any values (even dummy ones)
- Example secrets
- Example IPs
- Example hostnames that resemble real ones

### Naming rules

- Prefer sibling private companion repos or runtime secret paths over tracked
  in-repo private placeholders
- Avoid operational detail in names when documenting private boundaries
  - ❌ `vpn-wireguard-home/`
  - ❌ `dns-prod-zone/`
  - ✅ `../nix-services-private/`
  - ✅ `/run/secrets/...`

---

## 5. Optional Private Inputs

Public configuration MUST NOT depend on private tracked files to evaluate.

Private configuration must be **optional**.

### Current preferred pattern

- keep shared service modules publicly evaluable on their own
- keep runtime secrets external (for example `/run/secrets/...`)
- keep private continuity and operator notes in `../nix-services-private/`
- keep host-specific private wiring in the owning host repo, not here

This ensures:

- the public repo builds cleanly
- private state stays outside the published tree
- no placeholder directories are needed just to model private behavior

---

## 6. Secrets Handling (Out of Scope for Public Repo)

Secrets MUST be provided via one of the following **external mechanisms**:

- Files injected at runtime (e.g. `/run/secrets/...`)
- Encrypted secret management (e.g. sops-nix)
- Private companion repository

The public repo may reference secret **paths**, but never secret **values**.

---

## 7. Docker & Docker Compose Rules

Docker Compose files in this repo:

- MUST NOT contain secrets
- MUST NOT contain `.env` files with values
- MAY reference external env files by path

Example (allowed):

```yaml
env_file:
  - /run/secrets/pihole.env
```

Example (forbidden):

```yaml
environment:
  PIHOLE_PASSWORD=changeme
```

---

## 8. Safe-to-Publish Test

Before committing or generating code, ask:

> "Could a stranger use this repository to access my network or services?"

If the answer is **yes or maybe**, the change must NOT be committed.

---

## 9. Enforcement

- These rules apply to **all future changes**
- Codex MUST treat this document as authoritative
- Violations must be fixed immediately

This separation is a **hard requirement**, not a suggestion.

---

## 10. Summary

- Public repo = structure and intent
- Private data = external, encrypted, or overlaid
- No secrets, no exceptions
- Optional imports only
- Generic naming only

Following these rules keeps the repository:

- Safe to publish
- Easy to reason about
- Ready for real infrastructure deployment
