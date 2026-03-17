# PostgreSQL Exporter Service Module

This module deploys `postgres-exporter` via Docker Compose and exposes Prometheus metrics on port `9187` by default.

## Exposed options

- `services.postgresExporterCompose.enable`
- `services.postgresExporterCompose.containerName`
- `services.postgresExporterCompose.network`
- `services.postgresExporterCompose.timezone`
- `services.postgresExporterCompose.listenPort`
- `services.postgresExporterCompose.dataSourceNameFile`
- `services.postgresExporterCompose.image.repository`
- `services.postgresExporterCompose.image.tag`

## Required secret

- `services.postgresExporterCompose.dataSourceNameFile` must point to a runtime file containing a DSN, for example:
  - `postgresql://user:pass@postgres.internal.example:5433/db?sslmode=disable`

The module writes `/run/secrets/postgres-exporter.env` with:

- `DATA_SOURCE_NAME="...dsn..."`

## Known host-specific override

- `nix-pi/nixos/hosts/private/rpi-box-02.nix` overrides the generated
  `postgres-exporter` compose file to disable selected collectors
  (`wal`, `stat_bgwriter`) for that host's current Postgres role/version mix.
- During incident response on `rpi-box-02`, treat the host override as part of
  the effective runtime contract.

## Example

```nix
services.postgresExporterCompose = {
  enable = true;
  listenPort = 9187;
  dataSourceNameFile = "/run/secrets/postgres-exporter-dsn";
};
```
