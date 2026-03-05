# Solidtime Service Module

This module deploys Solidtime behind Traefik using a checked-in Docker Compose file.

## Deployment model

- Compose file is versioned at `services/solidtime/docker-compose.yml`.
- NixOS injects runtime environment variables (container names, image tags, network, hostname, listen address/port, database and mail endpoints).
- Sensitive values are loaded from `services.solidtimeCompose.secretFile` into `/run/secrets/solidtime.env` at startup.
- systemd runs `docker compose up -d` / `docker compose down` and waits for app health.
- Data persists under `services.solidtimeCompose.dataDir` (default `/var/lib/solidtime`).

## Exposed options

- `services.solidtimeCompose.enable`
- `services.solidtimeCompose.hostname`
- `services.solidtimeCompose.network`
- `services.solidtimeCompose.listenAddress`
- `services.solidtimeCompose.listenPort`
- `services.solidtimeCompose.openFirewall`
- `services.solidtimeCompose.dataDir`
- `services.solidtimeCompose.secretFile`
- `services.solidtimeCompose.database.host`
- `services.solidtimeCompose.database.port`
- `services.solidtimeCompose.database.name`
- `services.solidtimeCompose.database.user`
- `services.solidtimeCompose.database.sslmode`
- `services.solidtimeCompose.mail.host`
- `services.solidtimeCompose.mail.port`
- `services.solidtimeCompose.mail.encryption`
- `services.solidtimeCompose.mail.fromAddress`
- `services.solidtimeCompose.mail.fromName`
- `services.solidtimeCompose.mail.username`
- `services.solidtimeCompose.image.repository`
- `services.solidtimeCompose.image.tag`
- `services.solidtimeCompose.image.allowMutableTag`
- `services.solidtimeCompose.gotenberg.image.repository`
- `services.solidtimeCompose.gotenberg.image.tag`
- `services.solidtimeCompose.gotenberg.image.allowMutableTag`
- `services.solidtimeCompose.tls`

## Runtime secret file contract

`services.solidtimeCompose.secretFile` must point to a runtime-provisioned dotenv file containing at least:

- `APP_KEY`
- `PASSPORT_PRIVATE_KEY`
- `PASSPORT_PUBLIC_KEY`
- `DB_PASSWORD`

Optional keys can also be present (for example `SUPER_ADMINS`, `MAIL_PASSWORD`).

## Example

```nix
services.solidtimeCompose = {
  enable = true;
  hostname = "solidtime.${config.lab.domain}";
  tls = true;

  dataDir = "/var/lib/solidtime";
  secretFile = "/run/secrets/solidtime-secrets.env";

  database = {
    host = "postgres.<homelab-domain>";
    port = 5433;
    name = "solidtime";
    user = "solidtime";
  };

  mail = {
    host = "smtp-relay.${config.lab.domain}";
    port = 2525;
    encryption = "";
    fromAddress = "no-reply@solidtime.${config.lab.domain}";
    fromName = "solidtime";
  };
};
```
