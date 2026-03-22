# Seerr service

Seerr is packaged here as a Docker Compose-backed NixOS module.

- Compose file lives at `services/seerr/docker-compose.yml`.
- The module exports `services.seerr`.
- Current default image is `ghcr.io/seerr-team/seerr:v3.1.0`.
- Persistent state stays under `services.seerr.dataDir` and should be pointed
  at a dedicated host path such as `/srv/seerr`.
- The PostgreSQL password is read from
  `services.seerr.database.postgres.passwordFile` and rendered into
  `/run/secrets/seerr.env` at service start.
- Startup now waits for PostgreSQL to accept TCP connections before launching
  the container, which helps avoid first-run config resets during host-wide
  Docker restarts.
- The module mounts `/etc/ssl/certs/homelab-root-ca.crt` into the container and
  sets `NODE_EXTRA_CA_CERTS` so Seerr can talk to internal HTTPS services such
  as `https://jellyfin.<lab-domain>/`.
- The service is intended to run behind Traefik with PostgreSQL as the primary
  backend.

Operational notes:

- Upstream listens on port `5055` by default.
- Initial Jellyfin integration is completed in the Seerr web UI after first
  startup; this module ensures the container can trust the homelab TLS chain.
- PostgreSQL must already contain the `seerr` role and database before the
  service starts.
- Declarative integration reconciliation only runs when Seerr's
  `settings.json` is already initialized, so a brand-new instance is left for
  normal first-time setup.
- Verified deployed shape on 2026-03-11:
  - URL: `https://seerr.internal.example/`
  - Postgres endpoint: `postgres.internal.example:5433`
  - media-server integration: Jellyfin at `https://media.internal.example/`

Important options:

- `services.seerr.enable`
- `services.seerr.hostname`
- `services.seerr.dataDir`
- `services.seerr.database.postgres.host`
- `services.seerr.database.postgres.port`
- `services.seerr.database.postgres.name`
- `services.seerr.database.postgres.user`
- `services.seerr.database.postgres.passwordFile`
- `services.seerr.image.repository`
- `services.seerr.image.tag`
- `services.seerr.tls`

Example:

```nix
services.seerr = {
  enable = true;
  hostname = "seerr.internal.example";
  tls = true;
  dataDir = "/srv/seerr";
  database.postgres = {
    host = "postgres.internal.example";
    port = 5433;
    name = "seerr";
    user = "seerr";
    passwordFile = "/run/secrets/seerr-db-password";
  };
};
```
