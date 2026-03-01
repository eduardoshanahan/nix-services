# Focalboard Service Module

This module deploys standalone Focalboard behind Traefik using a checked-in Docker Compose file.

## Deployment model

- Compose file is versioned at `services/focalboard/docker-compose.yml`.
- NixOS injects runtime environment variables (container name, image/tag, network, hostname, TLS mode, timezone, data path).
- systemd runs `docker compose up -d` / `docker compose down`.
- Persistent state uses the container's default local SQLite database and file storage under `services.focalboard.dataDir` (default `/var/lib/focalboard`), mounted at `/opt/focalboard/data`.

## Exposed options

- `services.focalboard.enable`
- `services.focalboard.containerName`
- `services.focalboard.hostname`
- `services.focalboard.timezone`
- `services.focalboard.network`
- `services.focalboard.dataDir`
- `services.focalboard.image.repository`
- `services.focalboard.image.tag`
- `services.focalboard.image.allowMutableTag`
- `services.focalboard.tls`

## Runtime shape

- Focalboard Personal Server listens on port `8000` in the container.
- The container image stores writable state under `/opt/focalboard/data`.
- The module prepares the host data directory as `65534:65534` before startup to match the image's `nobody` user.

## Image pinning strategy

- Default policy is pinned tags only.
- Default image is `mattermost/focalboard:7.11.3`.
- Mutable tags like `latest` are blocked unless
  `services.focalboard.image.allowMutableTag = true`.

## Upstream notes

- Upstream documentation still documents the standalone Docker image, but the project is effectively community-maintained and the upstream repo states it is not currently maintained.
- `7.11.4` and `8.0.0` are plugin-only releases upstream, so this module defaults to `7.11.3`, which is the latest release that still includes the standalone Personal Server.

## Example

```nix
services.focalboard = {
  enable = true;
  hostname = "focalboard.${config.lab.domain}";
  tls = true;
};
```
