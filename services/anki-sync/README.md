# Anki Sync Service Module

Docker Compose-backed self-hosted Anki sync server managed through a NixOS
module.

## Purpose

- Runs the official Anki sync server behind Traefik.
- Builds the container from the upstream Docker example published in the Anki
  repository.
- Persists Anki sync state in a configurable host directory.

## Module

- Option path: `services.ankiSyncCompose`
- Entrypoint module: `services/anki-sync/anki-sync.nix`

## Minimal configuration

```nix
{
  services.ankiSyncCompose = {
    enable = true;
    hostname = "anki-sync.internal.example";
    tls = true;
    dataDir = "/srv/anki-sync";
    account.username = "eduardo";
  };
}
```

## Key options

- `services.ankiSyncCompose.hostname`: Traefik `Host()` rule.
- `services.ankiSyncCompose.tls`: route on `websecure` with TLS when enabled.
- `services.ankiSyncCompose.dataDir`: persistent host directory mounted at
  `/anki_data`.
- `services.ankiSyncCompose.version`: pinned upstream Anki release used to
  build the sync server.
- `services.ankiSyncCompose.uid`
- `services.ankiSyncCompose.gid`
- `services.ankiSyncCompose.account.username`
- `services.ankiSyncCompose.account.passwordFile`
- `services.ankiSyncCompose.account.passwordsHashed`

## Password handling

- If `account.passwordFile` is set, it must point to a runtime-provisioned
  single-line file.
- If `account.passwordFile` is left unset, startup generates a password once at
  `${dataDir}/auth/sync-password` and reuses it on later starts.
- The module writes `/run/secrets/anki-sync.env` at service start and injects
  `SYNC_USER1` from that runtime-only env file.

## Validation

- `systemctl status anki-sync`
- `docker ps --filter name=anki-sync`
- `curl -skI https://anki-sync.<domain>/`
- `curl -fsS http://127.0.0.1:8080/health`

## Notes

- This module follows Anki's official self-hosted sync guidance and uses the
  upstream Docker example from the Anki repository rather than a third-party
  server implementation.
- Anki clients can stop syncing if you update the desktop/mobile apps ahead of
  the server version. Keep the pinned `version` aligned with the client version
  family you run.
- The upstream server listens on plain HTTP inside the container; TLS should be
  terminated by Traefik or another reverse proxy.
