# synology-services

Sanitized, reproducible deployment artifacts for Synology hosts.

## Scope

- This directory intentionally contains no credentials, certificates, or host-private secrets.
- Host-specific values are either parameterized in `.env.example` files or documented as manual DSM UI steps.

## Layout

- `hhnas4/node-exporter/compose.yaml`
- `hhnas4/node-exporter/.env.example`
- `hhnas4/deploy.sh`
- `hhnas4/DSM_MANUAL_CHECKLIST.md`

## Reproducibility Contract

- Container definitions, pinned image tags, ports, and restart policies must be git-tracked here.
- Any unavoidable Synology DSM UI action must be documented in `DSM_MANUAL_CHECKLIST.md`.
- Secret material must stay outside this repository.
