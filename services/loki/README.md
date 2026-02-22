# Loki Service Module

This module deploys Loki (single-node) using a checked-in Docker Compose file.

## Deployment model

- Compose file is versioned at `services/loki/docker-compose.yml`.
- NixOS injects runtime environment variables (container name, image, host port, data dir).
- NixOS renders Loki config at `/etc/loki/config.yaml` with local filesystem storage.
- systemd runs `docker compose up -d` / `docker compose down`.
- Data persists under `services.lokiCompose.dataDir` (default `/var/lib/loki`).

## Exposed options

- `services.lokiCompose.enable`
- `services.lokiCompose.containerName`
- `services.lokiCompose.dataDir`
- `services.lokiCompose.httpPort`
- `services.lokiCompose.retentionPeriod`
- `services.lokiCompose.image.repository`
- `services.lokiCompose.image.tag`
- `services.lokiCompose.image.allowMutableTag`

## Example

```nix
services.lokiCompose = {
  enable = true;
  dataDir = "/srv/loki";
  httpPort = 3100;
  retentionPeriod = "30d";
};
```
