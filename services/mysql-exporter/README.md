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

`rpi-box-02` now uses the shared module behavior directly again; it no longer
needs a host-specific compose override for this service.

Canonical host-side reference for current divergence/alignment status:

- `../nix-pi/docs/HOST_RUNTIME_DIVERGENCES.md`
