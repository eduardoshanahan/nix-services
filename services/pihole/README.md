# Pi-hole Service Module

This module deploys Pi-hole DNS + admin UI using a checked-in Docker Compose file.

## Deployment model

- Compose file is versioned at `services/pihole/docker-compose.yml`.
- NixOS injects runtime environment variables (container name, network, hostname, TLS mode, timezone).
- Pi-hole web password is injected at runtime from `services.pihole.webPasswordFile` into `/run/secrets/pihole.env`.
- systemd runs `docker compose up -d` / `docker compose down`.
- After startup, a route-recovery check validates the Traefik admin path and restarts Traefik once if needed.
- Persistent data uses Docker-managed named volumes declared in the compose file.

## Exposed options

- `services.pihole.enable`
- `services.pihole.containerName`
- `services.pihole.hostname`
- `services.pihole.timezone`
- `services.pihole.network`
- `services.pihole.shmSize`
- `services.pihole.webPasswordFile`
- `services.pihole.tls`

## Runtime secret contract

`services.pihole.webPasswordFile` must point to a runtime-provisioned file (for example `/run/secrets/pihole-web-password`) containing only the web password on one line.

## Network and ports

- DNS is exposed on host port `53/tcp` and `53/udp`.
- UI is exposed through Traefik labels (no host bind for ports `80/443`).
- Default container shared memory is `256m` to avoid Pi-hole FTL pressure on busy resolvers.

## Image pinning strategy

- Default image is `pihole/pihole:2026.04.0`.

## Example

```nix
services.pihole = {
  enable = true;
  hostname = "pihole.${config.lab.domain}";
  shmSize = "256m";
  tls = true;
  webPasswordFile = "/run/secrets/pihole-web-password";
};
```
