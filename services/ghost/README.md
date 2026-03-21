# Ghost Service Module

This module deploys Ghost behind Traefik using a checked-in Docker Compose file.

## Deployment model

- Compose file is versioned at `services/ghost/docker-compose.yml`.
- NixOS injects runtime environment variables (container name, image/tag, network, hostname, URL, timezone, data path, database host/port/name/user).
- Ghost database password is injected at runtime from `services.ghost.database.passwordFile` into a runtime env file (`/run/secrets/ghost.env` in legacy mode, `/run/secrets/ghost-<name>.env` in multi-instance mode).
- systemd runs `docker compose up -d` / `docker compose down` and waits for container health after startup.
- Content persists under `services.ghost.dataDir` (legacy mode) or per-instance `services.ghost.instances.<name>.dataDir`.
- The host root CA file is mounted from `/etc/ssl/certs/homelab-root-ca.crt`
  so Ghost's Node runtime can trust internal HTTPS endpoints.
- Supports multi-instance mode through `services.ghost.instances.<name>`.

## Exposed options

- `services.ghost.enable`
- `services.ghost.containerName`
- `services.ghost.hostname`
- `services.ghost.timezone`
- `services.ghost.network`
- `services.ghost.dataDir`
- `services.ghost.image.repository`
- `services.ghost.image.tag`
- `services.ghost.image.allowMutableTag`
- `services.ghost.database.host`
- `services.ghost.database.port`
- `services.ghost.database.name`
- `services.ghost.database.user`
- `services.ghost.database.passwordFile`
- `services.ghost.mail.enable`
- `services.ghost.mail.from`
- `services.ghost.mail.host`
- `services.ghost.mail.port`
- `services.ghost.mail.secure`
- `services.ghost.mail.user`
- `services.ghost.mail.passwordFile`
- `services.ghost.tls`
- `services.ghost.instances.<name>.*` (multi-instance mode)

## Multi-instance mode

- For more than one blog on the same host, use `services.ghost.instances`.
- Each instance gets its own:
  - systemd unit (`ghost-<name>`)
  - compose directory (`/etc/ghost-<name>`)
  - runtime secret env file (`/run/secrets/ghost-<name>.env`)
  - Traefik router/service labels (`ghost-<name>`)
- Legacy single-instance mode (`services.ghost.enable = true;` with top-level
  options) remains supported for compatibility.
- Do not combine legacy top-level options and `services.ghost.instances` in the
  same host config.

## Database contract

- Production use requires MySQL 8.
- `services.ghost.database.passwordFile` (or per-instance `services.ghost.instances.<name>.database.passwordFile`) must point to a runtime-provisioned file (for example `/run/secrets/ghost-db-password`) containing only the password on a single line.
- The MySQL server, database, and user must already exist before Ghost is started.

## Mail contract

- `services.ghost.mail.passwordFile` (or per-instance `services.ghost.instances.<name>.mail.passwordFile`) must point to a runtime-provisioned file containing only the SMTP password on a single line.
- When mail is enabled, the module writes `mail__options__auth__pass` into the runtime env file alongside the database password.
- Gmail works with:
  - `host = "smtp.gmail.com"`
  - `port = 465`
  - `secure = true`

## TLS trust note

- The module sets `NODE_EXTRA_CA_CERTS=/etc/ghost/homelab-root-ca.crt`.
- The mounted root CA file comes from the host path
  `/etc/ssl/certs/homelab-root-ca.crt`.
- This is required when Ghost needs to verify internal HTTPS endpoints behind a
  private CA, such as its own ActivityPub self-check.

## Host-specific divergence note

- Some consumers may apply host-private Ghost overrides in their host repo.
- If Ghost mail behavior differs from the shared module docs, check the host
  divergence record before changing the shared service.
- Canonical host-side reference:
  - `../nix-pi/docs/policy/HOST_RUNTIME_DIVERGENCES.md`

## Image pinning strategy

- Default policy is pinned tags only.
- Default image is `ghost:6.19.2`.
- Mutable tags like `latest` are blocked unless
  `services.ghost.image.allowMutableTag = true`.

## Example

```nix
services.ghost.instances = {
  blog = {
    hostname = "blog.${config.lab.domain}";
    dataDir = "/var/lib/ghost-blog";
    tls = true;
    database = {
      host = "mysql.internal.example";
      port = 3306;
      name = "ghost_blog";
      user = "ghost_blog";
      passwordFile = "/run/secrets/ghost-blog-db-password";
    };
    mail = {
      enable = true;
      from = "blog@example.com";
      host = "smtp-relay.${config.lab.domain}";
      port = 2525;
      secure = false;
      user = "";
      passwordFile = "/run/secrets/ghost-mail-password";
    };
  };

  notes = {
    hostname = "notes.${config.lab.domain}";
    dataDir = "/var/lib/ghost-notes";
    tls = true;
    database = {
      host = "mysql.internal.example";
      port = 3306;
      name = "ghost_notes";
      user = "ghost_notes";
      passwordFile = "/run/secrets/ghost-notes-db-password";
    };
    mail = {
      enable = true;
      from = "notes@example.com";
      host = "smtp-relay.${config.lab.domain}";
      port = 2525;
      secure = false;
      user = "";
      passwordFile = "/run/secrets/ghost-mail-password";
    };
  };
};
```
