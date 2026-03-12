# Radarr service

Radarr is packaged here as a Docker Compose-backed NixOS module.

- Compose file lives at `services/radarr/docker-compose.yml`.
- The module exports `services.radarrCompose`.
- Default image is `lscr.io/linuxserver/radarr:latest`.
- Persistent state stays under `services.radarrCompose.dataDir` and should be pointed
  at a dedicated host path such as `/srv/radarr`.
- Optional media-library access is provided with `services.radarrCompose.mediaDir`,
  mounted inside the container at `services.radarrCompose.mediaMountPath`
  (default `/media`).
- Optional downloader access is provided with `services.radarrCompose.downloadsDir`,
  mounted inside the container at `services.radarrCompose.downloadsMountPath`
  (default `/downloads`).
- The first-pass deployment intentionally keeps Radarr on its default internal
  SQLite database inside `dataDir`; no shared SQL backend on `hhnas4` is
  required.
- The service is intended to run behind Traefik on the shared external
  `traefik` Docker network.

Operational notes:

- Upstream listens on port `7878`.
- Media-library and downloader paths still depend on host-level storage
  decisions, but the module can now bind-mount an NAS-backed host path.
- Verified intended deployed shape on 2026-03-11:
  - URL: `https://radarr.<homelab-domain>/`
  - host: `rpi-box-02`
  - state path: `/srv/radarr`
  - database: local SQLite in `/srv/radarr`

Important options:

- `services.radarrCompose.enable`
- `services.radarrCompose.hostname`
- `services.radarrCompose.dataDir`
- `services.radarrCompose.uid`
- `services.radarrCompose.gid`
- `services.radarrCompose.mediaDir`
- `services.radarrCompose.mediaMountPath`
- `services.radarrCompose.downloadsDir`
- `services.radarrCompose.downloadsMountPath`
- `services.radarrCompose.image.repository`
- `services.radarrCompose.image.tag`
- `services.radarrCompose.image.allowMutableTag`
- `services.radarrCompose.tls`

Example:

```nix
services.radarrCompose = {
  enable = true;
  hostname = "radarr.${config.lab.domain}";
  tls = true;
  dataDir = "/srv/radarr";
  mediaDir = "/mnt/media";
  downloadsDir = "/mnt/media/Downloads/qbittorrent";
};
```
