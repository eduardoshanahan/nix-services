# Alertmanager Service Module

This module deploys Alertmanager behind Traefik using a checked-in Docker Compose file.

## Deployment model

- Compose file is versioned at `services/alertmanager/docker-compose.yml`.
- NixOS injects runtime environment variables (container name, image/tag, network, hostname, TLS mode, timezone, data path).
- NixOS renders Alertmanager config at `/etc/alertmanager/alertmanager.yml`.
- systemd runs `docker compose up -d` / `docker compose down`.
- Data persists under `services.alertmanager.dataDir` (default `/var/lib/alertmanager`).

## Exposed options

- `services.alertmanager.enable`
- `services.alertmanager.containerName`
- `services.alertmanager.hostname`
- `services.alertmanager.timezone`
- `services.alertmanager.network`
- `services.alertmanager.dataDir`
- `services.alertmanager.image.repository`
- `services.alertmanager.image.tag`
- `services.alertmanager.image.allowMutableTag`
- `services.alertmanager.tls`

## Image pinning strategy

- Default policy is pinned tags only.
- Default image is `prom/alertmanager:v0.27.0`.
- Mutable tags like `latest` are blocked unless
  `services.alertmanager.image.allowMutableTag = true`.

## Example

```nix
services.alertmanager = {
  enable = true;
  hostname = "alertmanager.${config.lab.domain}";
  dataDir = "/var/lib/alertmanager";
  tls = true;
};
```
