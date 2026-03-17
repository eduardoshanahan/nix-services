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

## Known host-specific override

- `nix-pi/nixos/hosts/private/rpi-box-02.nix` still overrides the generated
  compose file for `mysql-exporter`.
- The current override preserves the stabilized runtime file mount and pins the
  collector arguments explicitly for that host.
- When debugging `rpi-box-02`, check both the shared module and the host
  override before assuming the live container command line.
