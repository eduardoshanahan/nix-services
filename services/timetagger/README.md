# TimeTagger Service Module

This module deploys TimeTagger behind Traefik using a checked-in Docker Compose file.

## Deployment model

- Compose file is versioned at `services/timetagger/docker-compose.yml`.
- NixOS injects runtime environment variables (container name, image/tag, network, hostname, TLS mode, timezone, data path, credentials, log level).
- systemd runs `docker compose up -d` / `docker compose down`.
- Data persists under `services.timeTaggerCompose.dataDir` (default `/var/lib/timetagger`).

## Exposed options

- `services.timeTaggerCompose.enable`
- `services.timeTaggerCompose.containerName`
- `services.timeTaggerCompose.hostname`
- `services.timeTaggerCompose.timezone`
- `services.timeTaggerCompose.network`
- `services.timeTaggerCompose.dataDir`
- `services.timeTaggerCompose.logLevel`
- `services.timeTaggerCompose.credentials`
- `services.timeTaggerCompose.image.repository`
- `services.timeTaggerCompose.image.tag`
- `services.timeTaggerCompose.image.allowMutableTag`
- `services.timeTaggerCompose.tls`

## Image pinning strategy

- Default image repository is `ghcr.io/almarklein/timetagger`.
- Mutable tags are allowed by default because this module defaults to `latest`.
- To pin explicitly, set both:
  - `services.timeTaggerCompose.image.tag = "<fixed-tag>";`
  - `services.timeTaggerCompose.image.allowMutableTag = false;`

## Example

```nix
services.timeTaggerCompose = {
  enable = true;
  hostname = "timetagger.${config.lab.domain}";
  dataDir = "/srv/prometheus/timetagger";
  tls = true;

  image = {
    tag = "latest";
    allowMutableTag = true;
  };
};
```
