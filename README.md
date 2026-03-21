# nix-services

This repository is governed by `docs/prompts/codex_initial_prompt.md`.

This repository defines application services and operational policy
for ARM64 NixOS hosts.

It intentionally contains:

- No secrets
- No hardware bootstrap logic
- No imperative Docker usage

If you are looking for Raspberry Pi bootstrapping and image creation,
see the `nix-pi` repository.

## Repository Relationship

`nix-pi` (foundation/host repo) imports `nix-services` as a flake input and
consumes exported NixOS modules from this repo.

`nix-services` must remain service-focused and must not depend on `nix-pi`.

## Documentation Ownership

To avoid duplication and contradictions between `nix-pi` and `nix-services`,
documentation is split by responsibility:

- `nix-services` owns service architecture, service module contracts, Compose +
  systemd runtime patterns, service-level plans, and Synology service runbooks.
- `nix-pi` owns host lifecycle docs: workstation setup, image build/flash,
  bootstrap, host rebuild/deploy flow, and SOPS provisioning workflow.
- `nix-pi` also owns the canonical register of intentional host runtime
  divergences from shared service defaults.

For the ongoing documentation sync gate, see:
`docs/policy/DOC_SYNC_CHECKLIST.md`.

For the local documentation index, see:
`DOCUMENTATION_INDEX.md`.

Compose lifecycle policy note:

- `docs/policy/DOCKER_COMPOSE_RESTART_POLICY_GUIDANCE.md`

Quick documentation pointers:

- Host setup/provisioning/secrets: sibling repo `nix-pi` ->
  `../nix-pi/docs/lifecycle/SETUP.md`, `../nix-pi/docs/lifecycle/PROVISIONING.md`,
  `../nix-pi/docs/lifecycle/SECRETS.md`.
- Host-specific runtime divergence register: sibling repo `nix-pi` ->
  `../nix-pi/docs/policy/HOST_RUNTIME_DIVERGENCES.md`
- Host-owned Uptime Kuma monitor policy: sibling repo `nix-pi` ->
  `../nix-pi/docs/policy/UPTIME_KUMA_MONITOR_POLICY.md`
- Documentation sync gate for both repos: `docs/policy/DOC_SYNC_CHECKLIST.md`
- Stable shared policy docs: `docs/policy/`
- Shared rollout/runbook docs: `docs/plans/`, `docs/recovery/`
- Private continuity notes and handoffs: sibling repo `../nix-services-private/records/`
- Local documentation index: `DOCUMENTATION_INDEX.md`
- Service behavior/options/operations: `nix-services` -> `services/*/README.md`
  and service plans in this repository.
- Common service docs:
  - `services/homepage/README.md`
  - `services/uptime-kuma/README.md`
  - `services/traefik/README.md`
  - `services/grafana/README.md`
  - `services/smtp-relay/README.md`
  - `services/d2/README.md`
  - `services/fossflow/README.md`
  - `services/searxng/README.md`

## Public Repo Hygiene

Before commit/push, run the sanitization checklist in:

`docs/policy/PUBLIC_REPO_SANITIZATION_POLICY.md`

## diagrams.net Startup Behavior

The `diagrams-net` service uses a Docker healthcheck and a systemd post-start
health gate (`ExecStartPost`) that waits until the container reports `healthy`
or fails startup on timeout/unhealthy state.

Module-specific options and persistence guidance:
`services/diagrams-net/README.md`.

## Runtime Secrets (Consumption Only)

`nix-pi` owns secret provisioning (e.g. via `sops-nix`) and materializes decrypted files at activation time under runtime paths like `/run/secrets/...` (tmpfs).

`nix-services` only consumes those runtime file paths and must never create secrets, generate keys, or require secret material in Git or the Nix store.

For Docker Compose-based modules, the pattern is:

- The module exposes a `secretFile` option (string/path) that must be an absolute path (starts with `/`).
- The module passes that path to Compose via `env_file` (Compose reads the file at runtime; Nix does not read its contents).
- The operator must ensure the secret file exists before enabling the service (e.g. `/run/secrets/service.env`).

## Current Private Model

As of 2026-03-21, `nix-services` does not currently require an evaluation-time
private companion flake.

Current operating model:

- runtime secrets stay on `/run/secrets/...`
- host-specific private wiring stays in `nix-pi` / `nix-pi-private`
- private continuity and handoff notes now live in `../nix-services-private`
- the shared repo itself remains publicly evaluable without sibling private
  inputs

## Pre-commit Hooks (via `prek`)

This repo uses pre-commit hooks defined in `.pre-commit-config.yaml`.

From the dev shell (`nix develop`), hooks are automatically installed/updated
via `prek install` when the config changes.

Run hooks manually:

`prek run --all-files`
