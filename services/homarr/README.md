# Homarr service

Homarr is packaged here as a Docker Compose-backed NixOS module.

- Compose file lives at `services/homarr/docker-compose.yml`.
- The module exports `services.homarr`.
- Current default image is `ghcr.io/homarr-labs/homarr:v1.59.1`.
- Persistent state stays under `services.homarr.dataDir` and should be pointed
  at a dedicated host path such as `/srv/homarr`.
- `services.homarr.secretEncryptionKeyFile` must point at a runtime secret file
  containing a 64-character hex `SECRET_ENCRYPTION_KEY`.
- The service is intended to run behind Traefik.

Docker integration notes:

- Homarr supports Docker integration via `DOCKER_HOSTNAMES` and `DOCKER_PORTS`.
- This module exposes those through:
  - `services.homarr.docker.hostnames`
  - `services.homarr.docker.ports`
- In the current homelab, this pairs well with the existing Docker socket proxy
  endpoints on the Pi hosts and NAS.
- The current proxy policy is read-oriented by default because
  `services.dockerSocketProxyCompose.api.post = false`, so Homarr is best
  treated as a visibility/discovery dashboard unless that policy changes.

Operational notes:

- Upstream listens on port `7575` by default.
- Upstream docs say the container exits at startup if `SECRET_ENCRYPTION_KEY`
  is missing; this module fails earlier in `ExecStartPre` if the secret file is
  absent or empty.
- The default upstream runtime uses SQLite under `/appdata`, so no external
  database is required for first deployment.

Important options:

- `services.homarr.enable`
- `services.homarr.hostname`
- `services.homarr.dataDir`
- `services.homarr.secretEncryptionKeyFile`
- `services.homarr.image.repository`
- `services.homarr.image.tag`
- `services.homarr.tls`
- `services.homarr.docker.hostnames`
- `services.homarr.docker.ports`

Example:

```nix
services.homarr = {
  enable = true;
  hostname = "homarr.internal.example";
  tls = true;
  dataDir = "/srv/homarr";
  secretEncryptionKeyFile = "/run/secrets/homarr-secret-encryption-key";
  docker = {
    hostnames = [
      "rpi-box-01.internal.example"
      "rpi-box-02.internal.example"
      "rpi-box-03.internal.example"
      "hhnas4.internal.example"
    ];
    ports = [ 2375 2375 2375 2375 ];
  };
};
```
