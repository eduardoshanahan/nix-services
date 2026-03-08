# Traggo Service Module

This module deploys Traggo behind Traefik using a checked-in Docker Compose file.

## Deployment model

- Compose file is versioned at `services/traggo/docker-compose.yml`.
- NixOS injects runtime environment variables (hostname, TLS mode, network, image/tag, timezone).
- A runtime secret file (`/run/secrets/traggo.env`) is generated from
  `services.traggoCompose.admin.passwordFile` and passed to the container.
- systemd runs `docker compose up -d` / `docker compose down`.
- Data is bind-mounted from the host path configured by
  `services.traggoCompose.dataDir` to `/opt/traggo/data`.

## Exposed options

- `services.traggoCompose.enable`
- `services.traggoCompose.containerName`
- `services.traggoCompose.hostname`
- `services.traggoCompose.timezone`
- `services.traggoCompose.network`
- `services.traggoCompose.dataDir`
- `services.traggoCompose.image.repository`
- `services.traggoCompose.image.tag`
- `services.traggoCompose.image.allowMutableTag`
- `services.traggoCompose.tls`
- `services.traggoCompose.admin.username`
- `services.traggoCompose.admin.passwordFile`
