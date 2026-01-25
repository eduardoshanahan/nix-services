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
