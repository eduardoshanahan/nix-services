# MySQL Exporter Service Module

This module deploys `mysqld-exporter` via Docker Compose and exposes Prometheus metrics on port `9104` by default.

## Exposed options

- `services.mysqlExporterCompose.enable`
- `services.mysqlExporterCompose.containerName`
- `services.mysqlExporterCompose.network`
- `services.mysqlExporterCompose.timezone`
- `services.mysqlExporterCompose.listenPort`
- `services.mysqlExporterCompose.dataSourceNameFile`
- `services.mysqlExporterCompose.image.repository`
- `services.mysqlExporterCompose.image.tag`

## Required secret

- `services.mysqlExporterCompose.dataSourceNameFile` must point to a runtime file containing the exporter DSN, for example:
  - `user:pass@(mysql.internal.example:3306)/`

The module writes `/run/secrets/mysql-exporter.env` with:

- `DATA_SOURCE_NAME="...dsn..."`
