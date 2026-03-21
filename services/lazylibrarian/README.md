# LazyLibrarian service

LazyLibrarian is packaged here as a Docker Compose-backed NixOS module.

- Compose file lives at `services/lazylibrarian/docker-compose.yml`.
- The module exports `services.lazylibrarianCompose`.
- Default image is `lscr.io/linuxserver/lazylibrarian:latest`.
- Persistent state stays under `services.lazylibrarianCompose.dataDir` and should
  be pointed at a dedicated host path such as `/srv/lazylibrarian`.
- Optional downloader access is provided with
  `services.lazylibrarianCompose.downloadsDir`, mounted inside the container at
  `services.lazylibrarianCompose.downloadsMountPath` (default `/downloads`).
- Optional LazyLibrarian library/staging access is provided with
  `services.lazylibrarianCompose.booksDir`, mounted inside the container at
  `services.lazylibrarianCompose.booksMountPath` (default `/books`).
- Optional Calibre-Web-Automated ingest access is provided with
  `services.lazylibrarianCompose.cwaIngestDir`, mounted inside the container at
  `services.lazylibrarianCompose.cwaIngestMountPath`
  (default `/cwa-book-ingest`).
- The generated systemd unit declares `RequiresMountsFor` for the configured
  state and optional bind-mounted paths so boot-time startup waits for those
  mounts before Docker starts the container.
- The intended connection model is to keep LazyLibrarian off the Calibre
  library itself and use the CWA ingest folder as the handoff point.
- The service is intended to run behind Traefik on the shared external
  `traefik` Docker network.

Operational notes:

- Upstream listens on port `5299`.
- LazyLibrarian can talk to qBittorrent directly for torrent downloads.
- LazyLibrarian docs recommend using a separate "Calibre Books Auto Add
  Directory" when maintaining separate libraries, rather than pointing the base
  destination folder at an existing Calibre library.
- Intended first deployment shape on `rpi-box-02`:
  - URL: `https://lazylibrarian.internal.example/`
  - host: `rpi-box-02`
  - state path: `/srv/lazylibrarian`
  - downloads path: `/mnt/media/Downloads/qbittorrent`
  - LazyLibrarian books path: `/mnt/media/Books/LazyLibrarian/library`
  - CWA ingest path: `/mnt/media/Books/CalibreWebAutomated/ingest`

Important options:

- `services.lazylibrarianCompose.enable`
- `services.lazylibrarianCompose.hostname`
- `services.lazylibrarianCompose.dataDir`
- `services.lazylibrarianCompose.downloadsDir`
- `services.lazylibrarianCompose.downloadsMountPath`
- `services.lazylibrarianCompose.booksDir`
- `services.lazylibrarianCompose.booksMountPath`
- `services.lazylibrarianCompose.cwaIngestDir`
- `services.lazylibrarianCompose.cwaIngestMountPath`
- `services.lazylibrarianCompose.uid`
- `services.lazylibrarianCompose.gid`
- `services.lazylibrarianCompose.image.repository`
- `services.lazylibrarianCompose.image.tag`
- `services.lazylibrarianCompose.image.allowMutableTag`
- `services.lazylibrarianCompose.tls`

Example:

```nix
services.lazylibrarianCompose = {
  enable = true;
  hostname = "lazylibrarian.${config.lab.domain}";
  tls = true;
  dataDir = "/srv/lazylibrarian";
  downloadsDir = "/mnt/media/Downloads/qbittorrent";
  booksDir = "/mnt/media/Books/LazyLibrarian/library";
  cwaIngestDir = "/mnt/media/Books/CalibreWebAutomated/ingest";
};
```
