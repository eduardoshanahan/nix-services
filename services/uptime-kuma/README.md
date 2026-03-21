# Uptime Kuma Service Module

This module deploys Uptime Kuma behind Traefik using a checked-in Docker Compose file.

## Deployment model

- Compose file is versioned at `services/uptime-kuma/docker-compose.yml`.
- NixOS injects runtime environment variables (container name, image/tag, network, hostname, TLS mode, timezone, data path).
- systemd runs `docker compose up -d` / `docker compose down` and waits for container health after startup.
- The managed systemd unit is `uptime-kuma-compose.service` to avoid collisions
  with upstream NixOS runtime naming.
- Data persists under `services.uptimeKuma.dataDir` (default `/var/lib/uptime-kuma`).

## Exposed options

- `services.uptimeKuma.enable`
- `services.uptimeKuma.containerName`
- `services.uptimeKuma.hostname`
- `services.uptimeKuma.timezone`
- `services.uptimeKuma.network`
- `services.uptimeKuma.dataDir`
- `services.uptimeKuma.image.repository`
- `services.uptimeKuma.image.tag`
- `services.uptimeKuma.image.allowMutableTag`
- `services.uptimeKuma.tls`
- `services.uptimeKuma.database.type` (`sqlite` or `mariadb`)
- `services.uptimeKuma.database.mariadb.host`
- `services.uptimeKuma.database.mariadb.port`
- `services.uptimeKuma.database.mariadb.name`
- `services.uptimeKuma.database.mariadb.user`
- `services.uptimeKuma.database.mariadb.passwordFile`

## Image pinning strategy

- Default policy is pinned tags only.
- Default image is `louislam/uptime-kuma:2.1.3`.
- Mutable tags like `latest` are blocked unless
  `services.uptimeKuma.image.allowMutableTag = true`.

## Example

```nix
services.uptimeKuma = {
  enable = true;
  hostname = "kuma.${config.lab.domain}";
  dataDir = "/var/lib/uptime-kuma";
  tls = true;
};
```

## Monitoring note (internal TLS)

When Uptime Kuma itself monitors internal HTTPS services using a private CA or
self-signed certificates, monitor checks can fail with certificate verification
errors.

In that case, set `ignoreTls = true` in the monitor definition in the Kuma UI
for affected monitors, or ensure the container trusts your internal CA.

## Known host-specific override

- `../nix-pi-private/modules/rpi-box-02.nix` adds a companion
  `uptime-kuma-monitor-sync` unit plus `/etc/uptime-kuma/desired-monitors.json`
  as a declarative monitor source of truth.
- The same host also extends `uptime-kuma-compose.service.restartTriggers` so
  monitor-definition changes force a managed restart/sync cycle.
- On `rpi-box-02`, monitor inventory is therefore partly host policy, not just
  state managed through the UI.
- Canonical host-side references:
  - `../nix-pi/docs/policy/HOST_RUNTIME_DIVERGENCES.md`
  - `../nix-pi/docs/policy/UPTIME_KUMA_MONITOR_POLICY.md`
