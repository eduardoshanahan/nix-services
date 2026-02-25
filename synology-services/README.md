# synology-services

Sanitized, reproducible deployment artifacts for Synology hosts.

## Scope

- This directory intentionally contains no credentials, certificates, or host-private secrets.
- Host-specific values are either parameterized in `.env.example` files or documented as manual DSM UI steps.

## Layout

- `nas-host-template/node-exporter/compose.yaml`
- `nas-host-template/node-exporter/.env.example`
- `nas-host-template/deploy.sh`
- `nas-host-template/DSM_MANUAL_CHECKLIST.md`

## Reproducibility Contract

- Container definitions, pinned image tags, ports, and restart policies must be git-tracked here.
- Any unavoidable Synology DSM UI action must be documented in `DSM_MANUAL_CHECKLIST.md`.
- Secret material must stay outside this repository.
