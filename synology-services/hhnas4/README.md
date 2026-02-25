# hhnas4

Reproducible Synology monitoring artifacts for host `hhnas4`.

## Deploy

From this repository:

```bash
cd synology-services/hhnas4
./deploy.sh hhnas4.hhlab.home.arpa
```

Optional target directory override:

```bash
./deploy.sh hhnas4.hhlab.home.arpa /volume1/docker/homelab/hhnas4
```

## What is automated

- `node-exporter` compose deployment with pinned image tag.
- Compose pull + up sequence on target NAS.

## What remains manual

- DSM Log Center forwarding setup for file/security activity logs.
- See `DSM_MANUAL_CHECKLIST.md`.
