# Sonarr service

Sonarr is packaged here as a Docker Compose-backed NixOS module.

- Compose file lives at `services/sonarr/docker-compose.yml`.
- The module exports `services.sonarrCompose`.
- Default image is `lscr.io/linuxserver/sonarr:latest`.
- Persistent state stays under `services.sonarrCompose.dataDir` and should be pointed
  at a dedicated host path such as `/srv/sonarr`.
- Optional TV-library access is provided with `services.sonarrCompose.mediaDir`,
  mounted inside the container at `services.sonarrCompose.mediaMountPath`
  (default `/tv`).
- Optional downloader access is provided with `services.sonarrCompose.downloadsDir`,
  mounted inside the container at `services.sonarrCompose.downloadsMountPath`
  (default `/downloads`).
- The first-pass deployment intentionally keeps Sonarr on its default internal
  SQLite database inside `dataDir`; no shared SQL backend on `hhnas4` is
  required.
- The service is intended to run behind Traefik on the shared external
  `traefik` Docker network.

Operational notes:

- Upstream listens on port `8989`.
- The current `rpi-box-02` media layout exposes TV content at `/mnt/media/TV Shows`
  and qBittorrent completed downloads at `/mnt/media/Downloads/qbittorrent`.
- Verified intended deployed shape on 2026-03-13:
  - URL: `https://sonarr.<homelab-domain>/`
  - host: `rpi-box-02`
  - state path: `/srv/sonarr`
  - database: local SQLite in `/srv/sonarr`

Important options:

- `services.sonarrCompose.enable`
- `services.sonarrCompose.hostname`
- `services.sonarrCompose.dataDir`
- `services.sonarrCompose.uid`
- `services.sonarrCompose.gid`
- `services.sonarrCompose.mediaDir`
- `services.sonarrCompose.mediaMountPath`
- `services.sonarrCompose.downloadsDir`
- `services.sonarrCompose.downloadsMountPath`
- `services.sonarrCompose.image.repository`
- `services.sonarrCompose.image.tag`
- `services.sonarrCompose.image.allowMutableTag`
- `services.sonarrCompose.tls`

Example:

```nix
services.sonarrCompose = {
  enable = true;
  hostname = "sonarr.${config.lab.domain}";
  tls = true;
  dataDir = "/srv/sonarr";
  mediaDir = "/mnt/media/TV Shows";
  downloadsDir = "/mnt/media/Downloads/qbittorrent";
};
```
