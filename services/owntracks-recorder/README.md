# OwnTracks Recorder Service Module

This module deploys OwnTracks Recorder behind Traefik using a checked-in Docker Compose file.

## Deployment model

- Compose file is versioned at `services/owntracks-recorder/docker-compose.yml`.
- NixOS injects runtime environment variables (container name, image/tag, network, hostname, TLS mode, internal HTTP port, timezone, data path).
- The module runs Recorder in HTTP-only mode (`/pub`) and disables the MQTT listener.
- systemd runs `docker compose up -d` / `docker compose down`.
- Data persists under `services.owntracksRecorder.dataDir` (default `/var/lib/owntracks-recorder`).

## Exposed options

- `services.owntracksRecorder.enable`
- `services.owntracksRecorder.containerName`
- `services.owntracksRecorder.hostname`
- `services.owntracksRecorder.timezone`
- `services.owntracksRecorder.network`
- `services.owntracksRecorder.dataDir`
- `services.owntracksRecorder.httpPort`
- `services.owntracksRecorder.entryPoint`
- `services.owntracksRecorder.image.repository`
- `services.owntracksRecorder.image.tag`
- `services.owntracksRecorder.image.allowMutableTag`
- `services.owntracksRecorder.tls`

## HTTP client mode

Point the mobile app's HTTP endpoint at:

```text
https://<hostname>/pub
```

If TLS is disabled for local testing, use `http://<hostname>/pub` instead.

When using the recommended dedicated cleartext Traefik entrypoint, append the
entrypoint port (for example `:8084`):

```text
http://<hostname>:8084/pub
```

## Image pinning strategy

- Default policy is pinned tags only.
- Default image is `owntracks/recorder:1.0.1`.
- Mutable tags like `latest` are blocked unless
  `services.owntracksRecorder.image.allowMutableTag = true`.

## Example

```nix
services.owntracksRecorder = {
  enable = true;
  hostname = "owntracks.${config.lab.domain}";
  dataDir = "/srv/owntracks/data";
  tls = true;
};
```
