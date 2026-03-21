# MongoDB Exporter

Prometheus exporter for MongoDB.

## Purpose

- Scrapes MongoDB metrics and exposes them on HTTP `:9216` for Prometheus.
- Runs on Docker Compose and reads `MONGODB_URI` from a runtime secret file.

## Minimal config

```nix
services.mongodbExporterCompose = {
  enable = true;
  listenPort = 9216;
  mongoUriFile = "/run/secrets/mongodb-exporter-uri";
};
```

Prometheus scrape target example:

```nix
services.prometheusCompose.scrape.mongodbExporterTargets = [
  "mongodb-exporter.internal.example:9216"
];
```
