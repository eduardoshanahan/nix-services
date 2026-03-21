# Prowlarr service

Prowlarr is packaged here as a Docker Compose-backed NixOS module.

- Compose file lives at `services/prowlarr/docker-compose.yml`.
- The module exports `services.prowlarrCompose`.
- Default image is `lscr.io/linuxserver/prowlarr:latest`.
- Persistent state stays under `services.prowlarrCompose.dataDir` and should be pointed
  at a dedicated host path such as `/srv/prowlarr`.
- The first-pass deployment intentionally keeps Prowlarr on its default internal
  SQLite database inside `dataDir`; no shared SQL backend on `hhnas4` is
  required.
- The service is intended to run behind Traefik on the shared external
  `traefik` Docker network.

Operational notes:

- Upstream listens on port `9696`.
- Verified intended deployed shape on 2026-03-12:
  - URL: `https://prowlarr.internal.example/`
  - host: `rpi-box-02`
  - state path: `/srv/prowlarr`
  - database: local SQLite in `/srv/prowlarr`

Important options:

- `services.prowlarrCompose.enable`
- `services.prowlarrCompose.hostname`
- `services.prowlarrCompose.dataDir`
- `services.prowlarrCompose.uid`
- `services.prowlarrCompose.gid`
- `services.prowlarrCompose.image.repository`
- `services.prowlarrCompose.image.tag`
- `services.prowlarrCompose.image.allowMutableTag`
- `services.prowlarrCompose.tls`

Example:

```nix
services.prowlarrCompose = {
  enable = true;
  hostname = "prowlarr.${config.lab.domain}";
  tls = true;
  dataDir = "/srv/prowlarr";
};
```
