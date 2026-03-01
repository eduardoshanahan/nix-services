# Vikunja Service Module

This module deploys Vikunja behind Traefik using a checked-in Docker Compose file.

## Deployment model

- Compose file is versioned at `services/vikunja/docker-compose.yml`.
- NixOS injects runtime environment variables (container name, image/tag, network, hostname, public URL, TLS mode, timezone, data path, registration mode).
- systemd runs `docker compose up -d` / `docker compose down`.
- Persistent state uses local SQLite plus uploaded files under `services.vikunja.dataDir` (default `/var/lib/vikunja`).

## Exposed options

- `services.vikunja.enable`
- `services.vikunja.containerName`
- `services.vikunja.hostname`
- `services.vikunja.timezone`
- `services.vikunja.network`
- `services.vikunja.dataDir`
- `services.vikunja.enableRegistration`
- `services.vikunja.image.repository`
- `services.vikunja.image.tag`
- `services.vikunja.image.allowMutableTag`
- `services.vikunja.tls`

## Runtime shape

- The module uses Vikunja's built-in SQLite support (`VIKUNJA_DATABASE_TYPE=sqlite`).
- The SQLite database is stored at `/app/vikunja/files/vikunja.db` inside the container.
- Uploaded files are stored under `/app/vikunja/files`.
- `VIKUNJA_SERVICE_PUBLICURL` is derived from `hostname` and `tls`.

## Image pinning strategy

- Default policy is pinned tags only.
- Default image is `vikunja/vikunja:2.1.0`.
- Mutable tags like `latest` are blocked unless
  `services.vikunja.image.allowMutableTag = true`.

## Example

```nix
services.vikunja = {
  enable = true;
  hostname = "tasks.${config.lab.domain}";
  dataDir = "/var/lib/vikunja";
  tls = true;
  enableRegistration = false;
};
```
