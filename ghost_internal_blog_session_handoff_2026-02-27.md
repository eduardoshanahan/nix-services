# Ghost Internal Blog Session Handoff (2026-02-27)

This note captures the final state of the Ghost deployment work completed in
this session so the next session can resume without re-discovery.

## Final state

- Ghost is deployed on `rpi-box-02`.
- Ghost is reachable internally at `https://blog.<homelab-domain>`.
- The site is intentionally internal-only.
- Ghost is behind Traefik on `rpi-box-02`.
- Ghost uses MySQL 8 on `hhnas4`.
- Ghost mail is configured for Gmail SMTP.
- Host-side and container-side trust for the homelab internal CA is working.

## Verified runtime status

- `ghost.service` on `rpi-box-02` is healthy and starts cleanly.
- Internal HTTPS probe through Traefik returns `HTTP/2 200`.
- A direct Node HTTPS request from inside the Ghost container to
  `https://blog.<homelab-domain>/` succeeds.
- Ghost can connect to MySQL on `hhnas4`.
- Ghost content is stored locally on `rpi-box-02`.

## Intentional scope decision

- The blog remains internal-only.
- Do not add the Ghost ActivityPub proxy routing to `ap.ghost.org`.
- ActivityPub / Social Web is not being pursued in this setup.

## Known non-blocking warning

- Ghost still probes `/.ghost/activitypub/v1/site/`.
- That path returns `404` in the current internal-only setup.
- This causes non-blocking ActivityPub-related log noise.
- This is expected and currently acceptable because the blog is not intended for
  public federation.

## Architecture

- App host: `rpi-box-02`
- Database host: `hhnas4`
- Database engine: dedicated `mysql:8` container on Synology
- Reverse proxy: Traefik on `rpi-box-02`
- Mail transport: Gmail SMTP

## Changes made in `nix-services`

- Added the Ghost service module:
  - `services/ghost/ghost.nix`
  - `services/ghost/docker-compose.yml`
  - `services/ghost/README.md`
- Ghost module supports:
  - pinned Ghost image
  - MySQL database configuration
  - runtime secret file for DB password
  - Gmail SMTP configuration
  - runtime secret file for SMTP password
  - `NODE_EXTRA_CA_CERTS` for internal CA trust inside the container
- Ghost container mounts:
  - `/etc/ssl/certs/homelab-root-ca.crt` from the host
  - into `/etc/ghost/homelab-root-ca.crt`
- The Ghost container uses:
  - `NODE_EXTRA_CA_CERTS=/etc/ghost/homelab-root-ca.crt`
- Added the Synology MySQL stack for Ghost under:
  - `synology-services/hhnas4/ghost-mysql/`

## Changes made in `nix-pi`

- `rpi-box-02` private host config enables Ghost.
- `rpi-box-02` private host config wires:
  - `ghost-db-password`
  - `ghost-mail-password`
- Shared private module now trusts the homelab root CA:
  - `nixos/modules/private.nix`
- Shared private module also exposes the root CA at:
  - `/etc/ssl/certs/homelab-root-ca.crt`
- Added tracked root CA file:
  - `nixos/certs/homelab-root-ca.crt`

## MySQL notes

- MySQL is running on `hhnas4`.
- Final working data persistence uses a Docker named volume, not a bind mount.
- Synology ACL behavior made bind mounts unreliable for MySQL bootstrap.
- The Ghost DB user is working.
- The Ghost database is working.

## Secret handling

- Secrets are not stored in tracked plaintext.
- `nix-pi` SOPS contains:
  - `ghost-db-password`
  - `ghost-mail-password`
- `rpi-box-02` receives runtime secrets under `/run/secrets/...`
- Synology still uses a local untracked `.env` file on `hhnas4` for MySQL.

## Important operational notes

- `nixos/hosts/private/*.nix` is gitignored, so changes there do not appear in
  `git status`.
- The `rpi-box-01` resolver order must remain:
  - `192.168.1.1`
  - `192.168.1.58`
  - `1.1.1.1`
- A previous attempt to put Pi-hole first on `rpi-box-01` caused startup /
  reachability issues and was rolled back.

## Cleanup candidates (not urgent)

- `nix-pi/nixos/certs/hhlab-wildcard.crt` still exists but is no longer used as
  a trust anchor.
- This file can be removed later if you want to reduce confusion.

## Good starting point for the next session

1. Decide whether to ignore the ActivityPub log noise permanently or try to
   disable Ghost's Social Web / ActivityPub behavior cleanly.
2. Optionally test a real outbound Ghost email flow (invite or password reset)
   to confirm Gmail SMTP end to end.
3. Optionally add documentation cleanup:
   - remove obsolete references to the unused wildcard trust file
   - add a short operator note that the blog is internal-only by design

## Current practical conclusion

- The blog is usable.
- The stack is stable.
- The remaining issue is only non-critical ActivityPub log noise tied to the
  intentional decision to keep the service internal-only.
