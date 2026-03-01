# Vikunja Service Module

This module deploys Vikunja behind Traefik using a checked-in Docker Compose file.

## Deployment model

- Compose file is versioned at `services/vikunja/docker-compose.yml`.
- NixOS injects runtime environment variables (container name, image/tag, network, hostname, public URL, TLS mode, timezone, data path, registration mode).
- systemd runs `docker compose up -d` / `docker compose down`.
- Persistent state uses local SQLite plus uploaded files under `services.vikunjaCompose.dataDir` (default `/var/lib/vikunja`).

## Exposed options

- `services.vikunjaCompose.enable`
- `services.vikunjaCompose.containerName`
- `services.vikunjaCompose.hostname`
- `services.vikunjaCompose.timezone`
- `services.vikunjaCompose.network`
- `services.vikunjaCompose.dataDir`
- `services.vikunjaCompose.enableRegistration`
- `services.vikunjaCompose.image.repository`
- `services.vikunjaCompose.image.tag`
- `services.vikunjaCompose.image.allowMutableTag`
- `services.vikunjaCompose.tls`

## Runtime shape

- The module uses Vikunja's built-in SQLite support (`VIKUNJA_DATABASE_TYPE=sqlite`).
- The SQLite database is stored at `/app/vikunja/files/vikunja.db` inside the container.
- Uploaded files are stored under `/app/vikunja/files`.
- The module sets `HOME` and `XDG_CACHE_HOME` into the writable data path so the container does not try to write under `/.cache`.
- The host data directory is prepared as owner `1000:0` before startup to match the container user.
- `VIKUNJA_SERVICE_PUBLICURL` is derived from `hostname` and `tls`.

## Image pinning strategy

- Default policy is pinned tags only.
- Default image is `vikunja/vikunja:2.1.0`.
- Mutable tags like `latest` are blocked unless
  `services.vikunjaCompose.image.allowMutableTag = true`.

## Example

```nix
services.vikunjaCompose = {
  enable = true;
  hostname = "tasks.${config.lab.domain}";
  dataDir = "/var/lib/vikunja";
  tls = true;
  enableRegistration = false;
};
```
