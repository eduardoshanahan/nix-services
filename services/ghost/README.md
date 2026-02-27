# Ghost Service Module

This module deploys Ghost behind Traefik using a checked-in Docker Compose file.

## Deployment model

- Compose file is versioned at `services/ghost/docker-compose.yml`.
- NixOS injects runtime environment variables (container name, image/tag, network, hostname, URL, timezone, data path, database host/port/name/user).
- Ghost database password is injected at runtime from `services.ghost.database.passwordFile` into `/run/secrets/ghost.env`.
- systemd runs `docker compose up -d` / `docker compose down` and waits for container health after startup.
- Content persists under `services.ghost.dataDir` (default `/var/lib/ghost`).

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

## Database contract

- Production use requires MySQL 8.
- `services.ghost.database.passwordFile` must point to a runtime-provisioned file (for example `/run/secrets/ghost-db-password`) containing only the password on a single line.
- The MySQL server, database, and user must already exist before Ghost is started.

## Mail contract

- `services.ghost.mail.passwordFile` must point to a runtime-provisioned file containing only the SMTP password on a single line.
- When mail is enabled, the module writes `mail__options__auth__pass` into `/run/secrets/ghost.env` alongside the database password.
- Gmail works with:
  - `host = "smtp.gmail.com"`
  - `port = 465`
  - `secure = true`

## Image pinning strategy

- Default policy is pinned tags only.
- Default image is `ghost:6.19.2`.
- Mutable tags like `latest` are blocked unless
  `services.ghost.image.allowMutableTag = true`.

## Example

```nix
services.ghost = {
  enable = true;
  hostname = "blog.${config.lab.domain}";
  dataDir = "/var/lib/ghost";
  tls = true;

  database = {
    host = "hhnas4";
    port = 3306;
    name = "ghost";
    user = "ghost";
    passwordFile = "/run/secrets/ghost-db-password";
  };

  mail = {
    enable = true;
    from = "eduardoshanahan@gmail.com";
    host = "smtp.gmail.com";
    port = 465;
    secure = true;
    user = "eduardoshanahan@gmail.com";
    passwordFile = "/run/secrets/ghost-mail-password";
  };
};
```
