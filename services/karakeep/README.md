# KaraKeep Service Module

This module deploys KaraKeep behind Traefik using a checked-in Docker Compose file.

## Deployment model

- Compose file is versioned at `services/karakeep/docker-compose.yml`.
- NixOS injects runtime environment variables (hostname, TLS mode, network, image/version, timezone).
- A runtime secret file (`/run/secrets/karakeep.env`) is generated from:
  - `services.karakeepCompose.nextAuthSecretFile`
  - `services.karakeepCompose.meiliMasterKeyFile`
- systemd runs `docker compose up -d` / `docker compose down`.
- Persistent storage:
  - KaraKeep data at `services.karakeepCompose.dataDir`
  - Meilisearch index at `services.karakeepCompose.meilisearchDataDir`

## Exposed options

- `services.karakeepCompose.enable`
- `services.karakeepCompose.containerName`
- `services.karakeepCompose.hostname`
- `services.karakeepCompose.timezone`
- `services.karakeepCompose.network`
- `services.karakeepCompose.dataDir`
- `services.karakeepCompose.meilisearchDataDir`
- `services.karakeepCompose.image.repository`
- `services.karakeepCompose.image.version`
- `services.karakeepCompose.image.allowMutableVersion`
- `services.karakeepCompose.chromeImage`
- `services.karakeepCompose.meilisearchImage`
- `services.karakeepCompose.nextAuthSecretFile`
- `services.karakeepCompose.meiliMasterKeyFile`
- `services.karakeepCompose.tls`
