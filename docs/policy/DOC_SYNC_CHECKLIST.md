# Documentation Sync Checklist

Use this checklist whenever a change affects shared service behavior, host
runtime policy, or operator-facing deployment reality.

The goal is simple: if code changed in a way that would surprise an operator
reading the docs, the docs must move in the same change.

## Canonical Ownership Reminder

- Shared module behavior/options/contracts:
  - `nix-services`
- Host-specific runtime divergence:
  - `nix-pi/docs/policy/HOST_RUNTIME_DIVERGENCES.md`
- Host-managed Uptime Kuma monitor policy/exceptions:
  - `nix-pi/docs/policy/UPTIME_KUMA_MONITOR_POLICY.md`

## Run This Checklist When You Change

- a service module option or default
- a Compose file or systemd lifecycle behavior
- a runtime secret path or runtime-generated file path
- a host-local override in `nix-pi`
- a Uptime Kuma monitor target, accepted status-code assumption, or exception
- a deploy/rebuild operator workflow
- a top-level repo map or documentation boundary

## Service Change Checks

If a change affects a shared service module in `nix-services`:

1. Update the matching `services/*/README.md` if:
   - options changed
   - defaults changed
   - runtime paths changed
   - startup/health/restart behavior changed
2. Update broader policy docs if needed, for example:
   - `DOCKER_COMPOSE_RESTART_POLICY_GUIDANCE.md`
   - monitoring/design plan docs
3. If host-specific behavior is relevant, ensure the service README points to
   the canonical host-side reference instead of trying to duplicate host truth.

## Host Change Checks

If a change affects deployed host behavior in `nix-pi`:

1. Update `docs/policy/HOST_RUNTIME_DIVERGENCES.md` when:
   - a host-local override is added
   - a host-local override is removed
   - the rationale for a divergence changes
2. Update `docs/policy/UPTIME_KUMA_MONITOR_POLICY.md` when:
   - a declarative monitor target changes
   - a monitor exception is added or removed
   - accepted status-code or TLS behavior changes
3. Update `README.md` only if the change affects:
   - top-level navigation
   - canonical documentation ownership
   - evergreen operator quick guidance

## Anti-Drift Rules

- Do not restate full shared module contracts in `nix-pi`.
- Do not hide host-specific runtime truth only in code comments if operators
  need to know about it.
- Prefer pointers to canonical docs over duplicate prose.
- If a detail is host-specific today but might become reusable, document the
  current host fact first and extract shared behavior separately.

## Pre-Merge Question

Before commit/push, ask:

> If someone read the current docs after this change, would they understand the
> real deployed behavior without re-discovering it from code?

If the answer is no, update the docs in the same change.
