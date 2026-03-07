# Docker Socket Proxy Service Module

This module deploys a read-only Docker socket proxy using a checked-in Docker Compose file.

## Deployment model

- Compose file is versioned at `services/docker-socket-proxy/docker-compose.yml`.
- NixOS injects runtime environment variables (container name, image/tag, bind address/port, socket path, API allowlist toggles).
- systemd runs `docker compose up -d` / `docker compose down`.
- The host Docker socket is mounted read-only into the proxy container.

## Exposed options

- `services.dockerSocketProxyCompose.enable`
- `services.dockerSocketProxyCompose.containerName`
- `services.dockerSocketProxyCompose.listenAddress`
- `services.dockerSocketProxyCompose.listenPort`
- `services.dockerSocketProxyCompose.socketPath`
- `services.dockerSocketProxyCompose.api.containers`
- `services.dockerSocketProxyCompose.api.events`
- `services.dockerSocketProxyCompose.api.images`
- `services.dockerSocketProxyCompose.api.info`
- `services.dockerSocketProxyCompose.api.networks`
- `services.dockerSocketProxyCompose.api.ping`
- `services.dockerSocketProxyCompose.api.version`
- `services.dockerSocketProxyCompose.api.volumes`
- `services.dockerSocketProxyCompose.api.post`
- `services.dockerSocketProxyCompose.api.auth`
- `services.dockerSocketProxyCompose.api.secrets`
- `services.dockerSocketProxyCompose.api.services`
- `services.dockerSocketProxyCompose.api.swarm`
- `services.dockerSocketProxyCompose.api.tasks`
- `services.dockerSocketProxyCompose.image.repository`
- `services.dockerSocketProxyCompose.image.tag`
- `services.dockerSocketProxyCompose.image.allowMutableTag`

## Image pinning strategy

- Default image repository is `docker.io/tecnativa/docker-socket-proxy`.
- Mutable tags are allowed by default.
- To pin explicitly, set:
  - `services.dockerSocketProxyCompose.image.tag = "<fixed-tag>";`
  - `services.dockerSocketProxyCompose.image.allowMutableTag = false;`

## Example

```nix
services.dockerSocketProxyCompose = {
  enable = true;
  listenAddress = "127.0.0.1";
  listenPort = 2375;
  image = {
    tag = "latest";
    allowMutableTag = true;
  };
};
```
