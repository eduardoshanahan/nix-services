# Persistent Storage Policy (Bind Mounts Default)

This document records the repository decision for persistent container data paths.

## Decision

For stateful services in `nix-services`, use **host bind mounts** by default, with a configurable absolute path option in the module.

Default path convention:

- `/var/lib/<service>` for normal persistent data
- `/srv/<service>/...` only when a host intentionally uses dedicated/larger storage

## Why This Decision

Bind mounts align better with the current architecture and operations model:

- Clear ownership: data location is explicit in host filesystem paths.
- Better runbooks: backup/restore/check commands use normal host tools.
- Better declarative fit: modules expose `dataDir` as an explicit host-level contract.
- Easier audits: operator can inspect persistent data paths without Docker volume indirection.

## Named Volumes Policy

Named volumes are not forbidden, but they are an exception.

Use named volumes only when there is a strong service-specific reason and document it in that service README/module comments.

Current exception:

- `services/pihole` currently uses named volumes and remains supported as-is.

This exception does not change the default for new services.

## Immediate Application

For new services (including Uptime Kuma migration from Synology to Pi), follow this policy and use a bind-mounted persistent path option (for example `dataDir = "/var/lib/uptime-kuma"`).
