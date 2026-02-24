# Grafana Service Module

This module deploys Grafana behind Traefik using a checked-in Docker Compose file.

## Deployment model

- Compose file is versioned at `services/grafana/docker-compose.yml`.
- NixOS injects runtime environment variables (container name, image/tag, network, hostname, TLS mode, timezone, data path).
- Grafana admin password is injected at runtime from `services.grafanaCompose.adminPasswordFile` into `/run/secrets/grafana.env`.
- systemd runs `docker compose up -d` / `docker compose down`.
- Data persists under `services.grafanaCompose.dataDir` (default `/var/lib/grafana`).

## Exposed options

- `services.grafanaCompose.enable`
- `services.grafanaCompose.containerName`
- `services.grafanaCompose.hostname`
- `services.grafanaCompose.timezone`
- `services.grafanaCompose.network`
- `services.grafanaCompose.dataDir`
- `services.grafanaCompose.adminPasswordFile`
- `services.grafanaCompose.image.repository`
- `services.grafanaCompose.image.tag`
- `services.grafanaCompose.image.allowMutableTag`
- `services.grafanaCompose.tls`

## Image pinning strategy

- Default policy is pinned tags only.
- Default image is `grafana/grafana:11.2.0`.
- Mutable tags like `latest` are blocked unless
  `services.grafanaCompose.image.allowMutableTag = true`.

## Example

```nix
services.grafanaCompose = {
  enable = true;
  hostname = "grafana.${config.lab.domain}";
  dataDir = "/var/lib/grafana";
  adminPasswordFile = "/run/secrets/grafana-admin-password";
  tls = true;
};
```
