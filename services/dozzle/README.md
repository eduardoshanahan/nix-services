# Dozzle Service Module

This module deploys Dozzle behind Traefik using a checked-in Docker Compose file.

## Deployment model

- Compose file is versioned at `services/dozzle/docker-compose.yml`.
- NixOS injects runtime environment variables (hostname, TLS mode, network, image/tag, timezone).
- systemd runs `docker compose up -d` / `docker compose down`.
- Data is bind-mounted from the host path configured by
  `services.dozzleCompose.dataDir` to `/data`.
- Docker logs are read through a read-only bind mount of
  `services.dozzleCompose.socketPath` to `/var/run/docker.sock`.

## Exposed options

- `services.dozzleCompose.enable`
- `services.dozzleCompose.containerName`
- `services.dozzleCompose.hostname`
- `services.dozzleCompose.timezone`
- `services.dozzleCompose.network`
- `services.dozzleCompose.dataDir`
- `services.dozzleCompose.socketPath`
- `services.dozzleCompose.image.repository`
- `services.dozzleCompose.image.tag`
- `services.dozzleCompose.image.allowMutableTag`
- `services.dozzleCompose.tls`
