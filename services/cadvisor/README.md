# cAdvisor Service Module

This module deploys `cAdvisor` as a Docker Compose-managed metrics endpoint for
container and host cgroup telemetry.

## Deployment model

- Compose file is versioned at `services/cadvisor/docker-compose.yml`.
- NixOS injects runtime environment variables (container name, listen address,
  listen port, Docker data root, housekeeping interval, image/tag).
- systemd runs `docker compose up -d` / `docker compose down`.
- cAdvisor listens on host TCP port `services.cadvisorCompose.listenPort`
  (default `8081`) and serves Prometheus metrics on `/metrics`.

## Exposed options

- `services.cadvisorCompose.enable`
- `services.cadvisorCompose.containerName`
- `services.cadvisorCompose.listenAddress`
- `services.cadvisorCompose.listenPort`
- `services.cadvisorCompose.dockerDataRoot`
- `services.cadvisorCompose.housekeepingInterval`
- `services.cadvisorCompose.image.repository`
- `services.cadvisorCompose.image.tag`
- `services.cadvisorCompose.image.allowMutableTag`

## Image pinning strategy

- Default policy is pinned tags only.
- Default image is `gcr.io/cadvisor/cadvisor:v0.49.2`.
- Mutable tags like `latest` are blocked unless
  `services.cadvisorCompose.image.allowMutableTag = true`.

## Example

```nix
services.cadvisorCompose = {
  enable = true;
  listenAddress = "0.0.0.0";
  listenPort = 8081;
};
```
