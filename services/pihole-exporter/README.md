# Pi-hole Exporter Service Module

This module deploys the `ekofr/pihole-exporter` container for Prometheus scraping.

## Deployment model

- Compose file is versioned at `services/pihole-exporter/docker-compose.yml`.
- Pi-hole password is injected at runtime from `services.piholeExporter.pihole.passwordFile` into `/run/secrets/pihole-exporter.env`.
- Exporter listens on host TCP port `services.piholeExporter.listenPort` (default `9617`).

## Exposed options

- `services.piholeExporter.enable`
- `services.piholeExporter.containerName`
- `services.piholeExporter.network`
- `services.piholeExporter.timezone`
- `services.piholeExporter.listenPort`
- `services.piholeExporter.pihole.hostname`
- `services.piholeExporter.pihole.port`
- `services.piholeExporter.pihole.protocol`
- `services.piholeExporter.pihole.passwordFile`
- `services.piholeExporter.image.repository`
- `services.piholeExporter.image.tag`
