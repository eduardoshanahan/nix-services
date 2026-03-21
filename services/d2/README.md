# D2 Service Module

This module deploys a local D2 editor+renderer behind Traefik using Docker Compose.

## What it provides

- Local web editor for `.d2` files.
- Server-side render endpoint using the `d2` CLI (`SVG` output).
- Persistent project storage on host (`dataDir/projects`).
- Optional HTTP basic auth (enabled by default).

## Module options

- `services.d2Compose.enable`
- `services.d2Compose.containerName`
- `services.d2Compose.hostname`
- `services.d2Compose.timezone`
- `services.d2Compose.network`
- `services.d2Compose.dataDir`
- `services.d2Compose.image.repository`
- `services.d2Compose.image.tag`
- `services.d2Compose.image.allowMutableTag`
- `services.d2Compose.auth.enable`
- `services.d2Compose.auth.username`
- `services.d2Compose.auth.passwordFile`
- `services.d2Compose.defaultFile`
- `services.d2Compose.tls`

## Auth behavior

When auth is enabled and no `passwordFile` is provided, startup generates:

- `${dataDir}/auth/admin-password`

Generation uses `openssl rand -base64 24` once (first start) and reuses the
existing password on subsequent restarts.

## Persistence

- Projects: `${dataDir}/projects/*.d2`
- Generated auth password (default mode): `${dataDir}/auth/admin-password`

Use `/srv/d2` on storage-backed hosts.

## Example

```nix
services.d2Compose = {
  enable = true;
  hostname = "d2.${config.lab.domain}";
  tls = true;
  dataDir = "/srv/d2";
};
```
