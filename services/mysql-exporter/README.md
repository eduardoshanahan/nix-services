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

The module writes `/run/secrets/mysql-exporter.env` with:

- `MYSQLD_EXPORTER_PASSWORD="...password..."`
