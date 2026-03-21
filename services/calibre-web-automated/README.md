# Calibre-Web-Automated service

Calibre-Web-Automated is packaged here as a Docker Compose-backed NixOS module.

- Compose file lives at `services/calibre-web-automated/docker-compose.yml`.
- The module exports `services.calibreWebAutomatedCompose`.
- Default image is `crocodilestick/calibre-web-automated:latest`.
- Persistent state stays under `services.calibreWebAutomatedCompose.dataDir` and
  should be pointed at a dedicated host path such as
  `/srv/calibre-web-automated`.
- The Calibre library lives under `services.calibreWebAutomatedCompose.libraryDir`
  and is mounted inside the container at
  `services.calibreWebAutomatedCompose.libraryMountPath`
  (default `/calibre-library`).
- The ingest/watch folder lives under
  `services.calibreWebAutomatedCompose.ingestDir` and is mounted inside the
  container at `services.calibreWebAutomatedCompose.ingestMountPath`
  (default `/cwa-book-ingest`).
- When the library lives on a network share such as NFS or SMB, set
  `services.calibreWebAutomatedCompose.networkShareMode = true`.
- The generated systemd unit now declares `RequiresMountsFor` for the configured
  state, library, and ingest paths so boot-time startup waits for those mounts
  before Docker starts the container.
- The service is intended to run behind Traefik on the shared external
  `traefik` Docker network.

Operational notes:

- Upstream listens on port `8083`.
- Do not point the service at an existing Calibre library until it has been
  validated with a fresh library; Calibre-Web-Automated writes to `metadata.db`.
- Keep the ingest folder separate from the library folder.
- Intended first deployment shape on `rpi-box-02`:
  - URL: `https://calibre.<homelab-domain>/`
  - host: `rpi-box-02`
  - state path: `/srv/calibre-web-automated`
  - library path: `/mnt/media/Books/CalibreWebAutomated/library`
  - ingest path: `/mnt/media/Books/CalibreWebAutomated/ingest`

Important options:

- `services.calibreWebAutomatedCompose.enable`
- `services.calibreWebAutomatedCompose.hostname`
- `services.calibreWebAutomatedCompose.dataDir`
- `services.calibreWebAutomatedCompose.libraryDir`
- `services.calibreWebAutomatedCompose.libraryMountPath`
- `services.calibreWebAutomatedCompose.ingestDir`
- `services.calibreWebAutomatedCompose.ingestMountPath`
- `services.calibreWebAutomatedCompose.uid`
- `services.calibreWebAutomatedCompose.gid`
- `services.calibreWebAutomatedCompose.networkShareMode`
- `services.calibreWebAutomatedCompose.trustedProxyCount`
- `services.calibreWebAutomatedCompose.image.repository`
- `services.calibreWebAutomatedCompose.image.tag`
- `services.calibreWebAutomatedCompose.image.allowMutableTag`
- `services.calibreWebAutomatedCompose.tls`

Example:

```nix
services.calibreWebAutomatedCompose = {
  enable = true;
  hostname = "calibre.${config.lab.domain}";
  tls = true;
  dataDir = "/srv/calibre-web-automated";
  libraryDir = "/mnt/media/Books/CalibreWebAutomated/library";
  ingestDir = "/mnt/media/Books/CalibreWebAutomated/ingest";
  networkShareMode = true;
};
```
