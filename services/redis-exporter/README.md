# Redis Exporter Service Module

This module deploys `redis_exporter` via Docker Compose and exposes Prometheus metrics on port `9121` by default.

## Exposed options

- `services.redisExporterCompose.enable`
- `services.redisExporterCompose.containerName`
- `services.redisExporterCompose.network`
- `services.redisExporterCompose.timezone`
- `services.redisExporterCompose.listenPort`
- `services.redisExporterCompose.redis.username`
- `services.redisExporterCompose.redis.host`
- `services.redisExporterCompose.redis.port`
- `services.redisExporterCompose.redis.passwordFile`
- `services.redisExporterCompose.image.repository`
- `services.redisExporterCompose.image.tag`

## Required secret

- `services.redisExporterCompose.redis.passwordFile` must point to a runtime file containing the Redis password.

The module writes `/run/secrets/redis-exporter.env` with:

- `REDIS_PASSWORD="..."`
