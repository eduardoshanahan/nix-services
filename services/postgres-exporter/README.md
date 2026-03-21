# PostgreSQL Exporter Service Module

This module deploys `postgres-exporter` via Docker Compose and exposes Prometheus metrics on port `9187` by default.

## Exposed options

- `services.postgresExporterCompose.enable`
- `services.postgresExporterCompose.containerName`
- `services.postgresExporterCompose.network`
- `services.postgresExporterCompose.timezone`
- `services.postgresExporterCompose.listenPort`
- `services.postgresExporterCompose.collectors.wal.enable`
- `services.postgresExporterCompose.collectors.statBgwriter.enable`
- `services.postgresExporterCompose.dataSourceNameFile`
- `services.postgresExporterCompose.image.repository`
- `services.postgresExporterCompose.image.tag`

## Required secret

- `services.postgresExporterCompose.dataSourceNameFile` must point to a runtime file containing a DSN, for example:
  - `postgresql://user:pass@postgres.internal.example:5433/db?sslmode=disable`

The module writes `/run/secrets/postgres-exporter.env` with:

- `DATA_SOURCE_NAME="...dsn..."`

Collector toggles are exposed as first-class module options so hosts can
disable collectors without replacing the entire compose file.

The generated systemd unit also uses restart triggers for the rendered Compose
file, so collector or image changes converge on the host during rebuilds
without requiring a separate manual restart.

## Known host-specific override

- `rpi-box-02` now uses shared module options to disable selected collectors
  (`wal`, `stat_bgwriter`) for its current Postgres role/version mix.
- Canonical host-side reference:
  - `../nix-pi/docs/policy/HOST_RUNTIME_DIVERGENCES.md`

## Example

```nix
services.postgresExporterCompose = {
  enable = true;
  listenPort = 9187;
  dataSourceNameFile = "/run/secrets/postgres-exporter-dsn";
  collectors = {
    wal.enable = false;
    statBgwriter.enable = false;
  };
};
```
