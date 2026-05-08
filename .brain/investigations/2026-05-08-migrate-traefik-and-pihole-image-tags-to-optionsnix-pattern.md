# Task: migrate traefik and pihole image tags to options.nix pattern

## Status

promoted

## Source Repo

nix-services

## Context

nixos

## What was attempted

Migrated traefik and pihole from Pattern 3 (hardcoded image tags in
`docker-compose.yml` / `render.nix`) to Pattern 1 (options.nix defaults →
env vars → `${VAR}` substitution in compose).

### Changes in nix-services (commit 0c60539)

traefik:

- `services/traefik/options.nix`: added `image.repository` (default `"traefik"`),
  `image.tag` (default `"v3.7.0"`), `image.allowMutableTag` (default `false`)
- `services/traefik/traefik.nix`: added `TRAEFIK_IMAGE_REPOSITORY` and
  `TRAEFIK_IMAGE_TAG` to `Environment`; added whitespace and mutable-tag
  assertions
- `services/traefik/render.nix`: replaced `image: traefik:v3.7.0` with
  `image: ''${TRAEFIK_IMAGE_REPOSITORY}:''${TRAEFIK_IMAGE_TAG}` (Nix heredoc
  escape)
- `services/traefik/docker-compose.yml`: replaced hardcoded image with
  `image: ${TRAEFIK_IMAGE_REPOSITORY}:${TRAEFIK_IMAGE_TAG}`

pihole:

- `services/pihole/pihole.nix`: added `image.repository`, `image.tag`,
  `image.allowMutableTag` options inline (no separate options.nix); added
  `PIHOLE_IMAGE_REPOSITORY` and `PIHOLE_IMAGE_TAG` to `Environment`; added
  assertions
- `services/pihole/docker-compose.yml`: replaced `image: pihole/pihole:2026.04.1`
  with `image: ${PIHOLE_IMAGE_REPOSITORY}:${PIHOLE_IMAGE_TAG}`

Deployed to all three RPi boxes after updating nix-pi flake.lock to 0c60539.

## What worked

- `nix flake check` passed cleanly after all six file changes
- `nixos-rebuild test` exit 0 on all three boxes simultaneously
- `nixos-rebuild switch` exit 0 on all three boxes simultaneously
- No pre-pull needed — image tags did not change, only the injection mechanism
- All three boxes confirmed `traefik:v3.7.0` and `pihole/pihole:2026.04.1`
  running and services `active` after switch

## What failed

Nothing.

## Wrong assumptions

None.

## Reusable insights

- **`''${VAR}` in Nix `''...''` heredocs**: to pass a literal `${VAR}` through
  to Docker Compose (so Docker Compose can expand it at runtime), write
  `''${VAR}` in the Nix string. Plain `${VAR}` would be Nix interpolation and
  fail at eval time.
- **pihole has no separate options.nix**: all `services.pihole` options live
  inline in `pihole.nix`. Add new options there, not in a new file.
- **No pre-pull needed for non-version-changing migrations**: when the image tag
  stays the same and only the referencing mechanism changes, `nixos-rebuild`
  does not trigger a new `docker pull`. Services restart from the cached image.

## Candidate for promotion

- `''${VAR}` Nix heredoc pattern → nix-services AGENT.md or constraints
- pihole options location (inline in pihole.nix) → service-level note
