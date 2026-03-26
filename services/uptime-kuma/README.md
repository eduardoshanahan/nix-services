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

## Adminer access

Adminer provides the shared SQL/MariaDB/Postgres interface for the homelab
databases and is mounted behind the Synology reverse proxy. Point any Kuma
monitors that track the database admin UI at `https://adminer.${config.lab.domain}/`
so they follow the same TLS-public endpoint. The container itself listens on
port `8080` and the NAS publishes that service internally on port `8070`, but
the public-facing proxy stays on ports `80`/`443` only. Keep the real DNS name
and firewall configuration in the private repo so the monitored endpoint always
matches the live deployment.

## Host-specific divergence note

- Some consumers add a companion monitor-sync unit and declarative monitor file
  in their host repo.
- Those hosts may also extend `uptime-kuma-compose.service.restartTriggers` so
  monitor-definition changes force a managed restart/sync cycle.
- In those deployments, monitor inventory is partly host policy rather than
  state managed only through the UI.
- Canonical host-side references:
  - `../nix-pi/docs/policy/HOST_RUNTIME_DIVERGENCES.md`
  - `../nix-pi/docs/policy/UPTIME_KUMA_MONITOR_POLICY.md`
