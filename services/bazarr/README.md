# Bazarr service

Bazarr is packaged here as a Docker Compose-backed NixOS module.

- Compose file lives at `services/bazarr/docker-compose.yml`.
- The module exports `services.bazarrCompose`.
- Default image is `lscr.io/linuxserver/bazarr:v1.5.6-ls348`.
- Persistent state stays under `services.bazarrCompose.dataDir` and should be pointed
  at a dedicated host path such as `/srv/bazarr`.
- Optional TV-library access is provided with `services.bazarrCompose.tvDir`,
  mounted inside the container at `services.bazarrCompose.tvMountPath`
  (default `/tv`).
- Optional movies-library access is provided with `services.bazarrCompose.moviesDir`,
  mounted inside the container at `services.bazarrCompose.moviesMountPath`
  (default `/movies`).
- The generated systemd unit declares `RequiresMountsFor` for the configured
  state and optional bind-mounted paths so boot-time startup waits for those
  mounts before Docker starts the container.
- The service is intended to run behind Traefik on the shared external
  `traefik` Docker network.

Operational notes:

- Upstream listens on port `6767`.
- Bazarr is a subtitle companion for Sonarr and Radarr; mount the same media
  directories used by those services so subtitle files can be written alongside
  the media files.
- Verified intended deployed shape on 2026-05-17:
  - URL: `https://bazarr.internal.example/`
  - state path: `/srv/bazarr`

Important options:

- `services.bazarrCompose.enable`
- `services.bazarrCompose.hostname`
- `services.bazarrCompose.dataDir`
- `services.bazarrCompose.uid`
- `services.bazarrCompose.gid`
- `services.bazarrCompose.tvDir`
- `services.bazarrCompose.tvMountPath`
- `services.bazarrCompose.moviesDir`
- `services.bazarrCompose.moviesMountPath`
- `services.bazarrCompose.image.repository`
- `services.bazarrCompose.image.tag`
- `services.bazarrCompose.image.allowMutableTag`
- `services.bazarrCompose.tls`

Example:

```nix
services.bazarrCompose = {
  enable = true;
  hostname = "bazarr.internal.example";
  tls = true;
  dataDir = "/srv/bazarr";
  tvDir = "/srv/media/tv";
  moviesDir = "/srv/media/movies";
};
```
