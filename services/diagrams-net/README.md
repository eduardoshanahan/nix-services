# diagrams.net Service Module

This module deploys diagrams.net (Draw.io) behind Traefik using Docker Compose.

## Operational defaults

- Default mode is stateless (`services.diagramsNet.persistence.enable = false`).
- Container is hardened by default:
  - non-root user (`1000:1000`)
  - read-only root filesystem
  - `no-new-privileges`
  - `cap_drop = [ "ALL" ]`
  - `/tmp` mounted as `tmpfs`
  - CPU/memory/PID limits

## Persistence decision

Persistence is optional and opt-in.

Reasoning:

- Stateless default keeps rollbacks and rebuilds simpler.
- Persistent storage is only needed when the operator explicitly wants local
  state retained on disk.

When enabled, the module creates `services.diagramsNet.persistence.hostPath`
via `systemd-tmpfiles` and bind-mounts it into
`services.diagramsNet.persistence.containerPath`.

## Key options

- `services.diagramsNet.image.repository`
- `services.diagramsNet.image.tag`
- `services.diagramsNet.image.allowMutableTag`
- `services.diagramsNet.extraEnv`
- `services.diagramsNet.extraLabels`
- `services.diagramsNet.persistence.enable`
- `services.diagramsNet.persistence.hostPath`
- `services.diagramsNet.persistence.containerPath`

## Image pinning strategy

- Default policy is pinned tags only.
- `services.diagramsNet.image.tag` defaults to a concrete version (`29.0.3`).
- Mutable tags like `latest` are blocked by assertion unless
  `services.diagramsNet.image.allowMutableTag = true`.

Recommended practice:

- Use explicit version tags in `nix-services`.
- Upgrade intentionally by changing the tag in Git, then deploy via `nix-pi`.

## Upgrade procedure

1. In `nix-services`, change `services.diagramsNet.image.tag` (or override in host config if you use that model).
2. Commit and push `nix-services`.
3. In `nix-pi`, run `nix flake update nix-services`.
4. Commit updated `flake.lock` in `nix-pi`.
5. Run `nixos-rebuild switch` for the target host.
6. Verify:
   - `systemctl status diagrams-net`
   - `docker inspect ... .State.Health.Status`
   - HTTPS check to the routed hostname.

## Example: enable persistence

```nix
services.diagramsNet = {
  enable = true;
  hostname = "diagramsnet.${config.lab.domain}";
  tls = true;

  persistence = {
    enable = true;
    hostPath = "/var/lib/diagrams-net";
    containerPath = "/data";
  };
};
```

## Validation

The module validates:

- `hostname` DNS format
- `network` name format
- `image.repository` and `image.tag` non-whitespace
- `cpus` numeric format
- `memoryLimit` positive Docker-compatible format
- image tag pinning policy (`latest` blocked unless explicitly allowed)
- absolute persistence paths when persistence is enabled
- `extraEnv` key format: `[A-Za-z_][A-Za-z0-9_]*`
- `extraLabels` key format: `[A-Za-z0-9][A-Za-z0-9._/-]*`
