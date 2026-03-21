# Docker Compose Restart Policy Guidance

This note captures the current policy for `nix-services` modules that use:

- systemd `Type = "oneshot"`
- `docker compose up -d` / `docker compose down`
- Docker Compose service-level `restart: unless-stopped`

It exists to document the decisions made during the 2026-03-17 investigation so
future sessions do not need to rediscover the rationale.

## Summary decision

`restart: unless-stopped` remains the default policy for the current
systemd-managed Compose service classes in this repository.

We are not removing it repo-wide because it still provides useful steady-state
behavior after successful startup:

- container-level recovery after process crashes
- continued service availability if the container dies long after the oneshot
  systemd unit has exited
- expected behavior for long-running web apps, exporters, and infra components
  that are not meant to stay down after a transient runtime crash

The 2026-03-17 incidents do **not** show that `unless-stopped` is wrong
everywhere. They show that it is dangerous when combined with ephemeral host
single-file bind mounts under `/run` that must exist in a specific shape before
Docker restarts the container.

## Current policy by service class

### Keep `restart: unless-stopped`

These service classes are intentionally left on Docker restart policy because
they benefit from container self-restart and did not match the exact reboot-race
failure mode:

- services using only persistent host directories or named volumes
- services using Compose `env_file` for runtime secrets, where Compose reads the
  file during `compose up -d` instead of requiring Docker to remount that file
  later on daemon restart
- services with health-gated startup but ordinary steady-state runtime behavior
- ingress, dashboards, applications, and exporters whose long-term availability
  should not depend on a oneshot systemd unit staying active as a supervisor

Examples:

- `grafana`
- `ghost`
- `home-assistant`
- `seerr`
- `uptime-kuma`
- `vikunja`
- `prometheus`
- `loki`
- `promtail`
- `unpoller`
- `pihole`
- `postgres-exporter`
- `redis-exporter`
- `mongodb-exporter`
- `authentik`
- `woodpecker`
- `fossflow`
- `searxng`

### Keep `restart: unless-stopped`, but only with explicit runtime-file safeguards

These services matched the dangerous class and therefore require explicit
guardrails if they continue using Docker restart policy:

- `alertmanager`
  - runtime config file under `/run/alertmanager/alertmanager.yml`
  - safeguard: render step heals stale non-file path before templating
- `mysql-exporter`
  - runtime my.cnf now moved to `/run/mysql-exporter/mysql-exporter.my.cnf`
  - safeguard: dedicated runtime dir plus stale non-file cleanup before render

Decision:

- keep `unless-stopped`
- keep the runtime-file safeguards
- do not reintroduce `/run/secrets/<file>` single-file bind mounts for these
  stacks without the same level of protection

### Defer any policy change pending service-specific design

These classes may eventually deserve a different lifecycle strategy, but there
is not enough evidence yet to change them in the same pass:

- host-network/system-level agents such as `tailscale`
- Docker API / socket-adjacent services such as `traefik`,
  `docker-socket-proxy`, `dozzle`, `homepage` Docker integration, and
  `woodpecker-agent`
- DNS or network-edge services such as `pihole`

Why deferred:

- changing restart policy here affects host observability, ingress, CI, or
  network reachability
- a safe change would need explicit runtime tests and likely service-specific
  option design rather than a blanket repo edit

## Practical rule for future modules

If a new Compose-backed module is added:

1. Default to `restart: unless-stopped` only if the service should recover from
   normal runtime crashes without operator intervention.
2. Avoid bind-mounting runtime-generated **single files** from ephemeral `/run`
   paths into the container.
3. Prefer one of these patterns instead:
   - Compose `env_file`
   - a dedicated runtime directory such as `/run/<service>/...`
   - copying credentials/config into a persistent service-owned path before
     container start
4. If a single-file bind mount under `/run` is unavoidable, add an explicit
   stale-path healing step before startup and test reboot behavior.

## What would justify changing policy later

Revisit `restart: unless-stopped` for a service when at least one of these is
true:

- reboot testing shows Docker restart races even after runtime-path hardening
- the service should only ever start through a carefully ordered systemd
  sequence and gains little from container self-restart
- the service already has a better recovery mechanism through systemd timers,
  healthchecks, or dedicated supervisory logic
- changing the policy can be validated on the actual host without risking
  ingress or monitoring blind spots
