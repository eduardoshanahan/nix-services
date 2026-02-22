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
- `services.diagramsNet.extraEnv`
- `services.diagramsNet.extraLabels`
- `services.diagramsNet.persistence.enable`
- `services.diagramsNet.persistence.hostPath`
- `services.diagramsNet.persistence.containerPath`

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
- `memoryLimit` Docker-compatible format
- absolute persistence paths when persistence is enabled
- `extraEnv` key format: `[A-Za-z_][A-Za-z0-9_]*`
- `extraLabels` key format: `[A-Za-z0-9][A-Za-z0-9._/-]*`
