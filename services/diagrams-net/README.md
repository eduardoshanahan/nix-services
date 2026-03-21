# diagrams.net Service Module

This module deploys diagrams.net (Draw.io) behind Traefik using a checked-in Docker Compose file.

## Deployment model

- Compose file is versioned at `services/diagrams-net/docker-compose.yml`.
- NixOS injects runtime environment variables (hostname, TLS mode, network, image/tag, timezone).
- systemd runs `docker compose up -d` / `docker compose down` and waits for container health after startup.
- Data is bind-mounted from `/var/lib/diagrams-net` on the host to `/data` in the container.

## Exposed options

- `services.diagramsNet.enable`
- `services.diagramsNet.containerName`
- `services.diagramsNet.hostname`
- `services.diagramsNet.timezone`
- `services.diagramsNet.network`
- `services.diagramsNet.image.repository`
- `services.diagramsNet.image.tag`
- `services.diagramsNet.image.allowMutableTag`
- `services.diagramsNet.tls`

## Image pinning strategy

- Default policy is pinned tags only.
- `services.diagramsNet.image.tag` defaults to `29.0.3`.
- Mutable tags like `latest` are blocked unless
  `services.diagramsNet.image.allowMutableTag = true`.

## Upgrade procedure

1. In `nix-services`, change `services.diagramsNet.image.tag`.
2. Commit and push `nix-services`.
3. In `nix-pi`, run `nix flake update nix-services`.
4. Commit the updated `flake.lock` in `nix-pi`.
5. Run `nixos-rebuild switch` for the target host.
6. Verify:
   - `systemctl status diagrams-net`
   - `docker inspect --format '{{.State.Health.Status}}' diagrams-net`
   - HTTPS response from the routed hostname.

## Example

```nix
services.diagramsNet = {
  enable = true;
  hostname = "diagramsnet.${config.lab.domain}";
  tls = true;
};
```
