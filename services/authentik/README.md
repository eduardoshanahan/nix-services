# Authentik

Docker Compose-based Authentik module for NixOS hosts.

## Notes

- This module is intended for current Authentik versions where Redis is no
  longer a required runtime dependency.
- Postgres should be provided externally (for example a shared
  `postgres.internal.example` service).

## Main options

- `services.authentikCompose.enable`
- `services.authentikCompose.hostname`
- `services.authentikCompose.network`
- `services.authentikCompose.dataDir`
- `services.authentikCompose.tls`
- `services.authentikCompose.secretKeyFile`
- `services.authentikCompose.database.postgres.host`
- `services.authentikCompose.database.postgres.port`
- `services.authentikCompose.database.postgres.name`
- `services.authentikCompose.database.postgres.user`
- `services.authentikCompose.database.postgres.passwordFile`
- `services.authentikCompose.bootstrap.email`
- `services.authentikCompose.bootstrap.passwordFile` (optional)
- `services.authentikCompose.bootstrap.tokenFile` (optional)

## Runtime behavior

- Runs two containers:
  - `authentik-server`
  - `authentik-worker`
- Traefik routes to Authentik server on container port `9000`.
- A runtime env file is generated at `/run/secrets/authentik.env` from secret
  files and module options.

## Secret inputs

At minimum:

- `secretKeyFile` -> `AUTHENTIK_SECRET_KEY`
- `database.postgres.passwordFile` -> Postgres password

Optional bootstrap:

- `bootstrap.passwordFile` -> `AUTHENTIK_BOOTSTRAP_PASSWORD`
- `bootstrap.tokenFile` -> `AUTHENTIK_BOOTSTRAP_TOKEN`

Set at most one bootstrap method.
