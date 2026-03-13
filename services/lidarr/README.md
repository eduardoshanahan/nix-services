# Lidarr service

Lidarr is packaged here as a Docker Compose-backed NixOS module.

- Compose file lives at `services/lidarr/docker-compose.yml`.
- The module exports `services.lidarrCompose`.
- Default image is `lscr.io/linuxserver/lidarr:latest`.
- Persistent state stays under `services.lidarrCompose.dataDir` and should be pointed
  at a dedicated host path such as `/srv/lidarr`.
- Optional music-library access is provided with `services.lidarrCompose.mediaDir`,
  mounted inside the container at `services.lidarrCompose.mediaMountPath`
  (default `/music`).
- Optional downloader access is provided with `services.lidarrCompose.downloadsDir`,
  mounted inside the container at `services.lidarrCompose.downloadsMountPath`
  (default `/downloads`).
- The first-pass deployment intentionally keeps Lidarr on its default internal
  SQLite database inside `dataDir`; no shared SQL backend on `hhnas4` is
  required.
- The service is intended to run behind Traefik on the shared external
  `traefik` Docker network.

Operational notes:

- Upstream listens on port `8686`.
- The current `rpi-box-02` media layout exposes music content at
  `/mnt/media/Music` and qBittorrent completed downloads at
  `/mnt/media/Downloads/qbittorrent`.
- Verified intended deployed shape on 2026-03-13:
  - URL: `https://lidarr.<homelab-domain>/`
  - host: `rpi-box-02`
  - state path: `/srv/lidarr`
  - database: local SQLite in `/srv/lidarr`

Important options:

- `services.lidarrCompose.enable`
- `services.lidarrCompose.hostname`
- `services.lidarrCompose.dataDir`
- `services.lidarrCompose.uid`
- `services.lidarrCompose.gid`
- `services.lidarrCompose.mediaDir`
- `services.lidarrCompose.mediaMountPath`
- `services.lidarrCompose.downloadsDir`
- `services.lidarrCompose.downloadsMountPath`
- `services.lidarrCompose.image.repository`
- `services.lidarrCompose.image.tag`
- `services.lidarrCompose.image.allowMutableTag`
- `services.lidarrCompose.tls`

Example:

```nix
services.lidarrCompose = {
  enable = true;
  hostname = "lidarr.${config.lab.domain}";
  tls = true;
  dataDir = "/srv/lidarr";
  mediaDir = "/mnt/media/Music";
  downloadsDir = "/mnt/media/Downloads/qbittorrent";
};
```
