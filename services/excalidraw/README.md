# Excalidraw Service Module

This module deploys Excalidraw behind Traefik using a checked-in Docker Compose file.

## Deployment model

- Compose file is versioned at `services/excalidraw/docker-compose.yml`.
- NixOS injects runtime environment variables (hostname, TLS mode, network, image/tag, timezone).
- systemd runs `docker compose up -d` / `docker compose down` and waits for container health after startup.

## Exposed options

- `services.excalidraw.enable`
- `services.excalidraw.containerName`
- `services.excalidraw.hostname`
- `services.excalidraw.timezone`
- `services.excalidraw.network`
- `services.excalidraw.image.repository`
- `services.excalidraw.image.tag`
- `services.excalidraw.image.digest`
- `services.excalidraw.image.allowMutableTag`
- `services.excalidraw.tls`

## Image pinning

- Preferred: set `services.excalidraw.image.digest` to an immutable digest.
- If using tags, keep `services.excalidraw.image.allowMutableTag = false` and use a fixed tag.
- `latest` is blocked unless `services.excalidraw.image.allowMutableTag = true`.

## Example

```nix
services.excalidraw = {
  enable = true;
  hostname = "excalidraw.${config.lab.domain}";
  tls = true;

  image = {
    repository = "excalidraw/excalidraw";
    digest = "sha256:...";
  };
};
```
