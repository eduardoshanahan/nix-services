# nix-services

This repository is governed by codex_initial_prompt.md.

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

For the current ownership matrix and first contradiction register, see:
`documentation_unification_block_1.md`.

Quick pointer map:

- Host setup/provisioning/secrets: `nix-pi` -> `docs/SETUP.md`,
  `docs/PROVISIONING.md`, `docs/SECRETS.md`.
- Service behavior/options/operations: `nix-services` -> `services/*/README.md`
  and service plans in this repository.
- Common service docs:
  - `services/homepage/README.md`
  - `services/uptime-kuma/README.md`
  - `services/traefik/README.md`
  - `services/grafana/README.md`

## Public Repo Hygiene

Before commit/push, run the sanitization checklist in:

`PUBLIC_REPO_SANITIZATION_POLICY.md`

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

## Pre-commit Hooks (via `prek`)

This repo uses pre-commit hooks defined in `.pre-commit-config.yaml`.

From the dev shell (`nix develop`), hooks are automatically installed/updated
via `prek install` when the config changes.

Run hooks manually:

`prek run --all-files`
