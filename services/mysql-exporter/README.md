# MySQL Exporter Service Module

This module deploys `mysqld-exporter` via Docker Compose and exposes Prometheus metrics on port `9104` by default.

## Exposed options

- `services.mysqlExporterCompose.enable`
- `services.mysqlExporterCompose.containerName`
- `services.mysqlExporterCompose.network`
- `services.mysqlExporterCompose.timezone`
- `services.mysqlExporterCompose.listenPort`
- `services.mysqlExporterCompose.mysql.host`
- `services.mysqlExporterCompose.mysql.port`
- `services.mysqlExporterCompose.mysql.username`
- `services.mysqlExporterCompose.mysql.passwordFile`
- `services.mysqlExporterCompose.image.repository`
- `services.mysqlExporterCompose.image.tag`

## Required secret

- `services.mysqlExporterCompose.mysql.passwordFile` must point to a runtime file containing the MySQL password.

The module writes `/run/mysql-exporter/mysql-exporter.my.cnf` and passes it to
`mysqld-exporter` via `--config.my-cnf`.

By default the compose command disables `slave_status` collection
(`--no-collect.slave_status`) to avoid requiring replication/super privileges
for standard single-instance deployments.

Consumers can use the shared module behavior directly without needing a
service-specific compose override.

Canonical host-side reference for current divergence/alignment status:

- `../nix-pi/docs/policy/HOST_RUNTIME_DIVERGENCES.md`
