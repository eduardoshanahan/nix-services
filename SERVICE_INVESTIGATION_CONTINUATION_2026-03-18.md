# Service Investigation Continuation - 2026-03-18

This file is the committed restart point for the next session.

It summarizes the work completed on 2026-03-17 across `nix-services` and
`nix-pi`, and it identifies the smallest sensible next steps.

## What is already done

### Reboot-race audit

The shared-module audit for the 2026-03-17 reboot incidents is complete.

Confirmed exact-match services for the dangerous pattern:

- `alertmanager`
- `mysql-exporter`

Current decision:

- both services keep `restart: unless-stopped`
- both now have explicit runtime-path safeguards
- no repo-wide removal of Docker restart policy is planned

Reference:

- `DOCKER_COMPOSE_RESTART_POLICY_GUIDANCE.md`

### Documentation cleanup

The top-level repo maps and missing service docs were repaired.

Relevant docs added or updated:

- `README.md`
- `DOCKER_COMPOSE_RESTART_POLICY_GUIDANCE.md`
- `services/fossflow/README.md`
- `services/searxng/README.md`
- service READMEs for:
  - `homepage`
  - `ghost`
  - `mysql-exporter`
  - `postgres-exporter`
  - `unpoller`
  - `uptime-kuma`

### Host-override reconciliation

`nix-pi/nixos/hosts/private/rpi-box-02.nix` was audited and documented.

Several host-specific behaviors were confirmed intentional and kept local.

### Shared-option extractions completed

These former `rpi-box-02` compose overrides are no longer host-local:

- `unpoller`
  - now uses shared option:
    - `services.unpollerCompose.influxdb.enable`
- `postgres-exporter`
  - now uses shared options:
    - `services.postgresExporterCompose.collectors.wal.enable`
    - `services.postgresExporterCompose.collectors.statBgwriter.enable`
- `mysql-exporter`
  - host override removed entirely because the shared module already expressed
    the desired runtime behavior

## Current remaining host-local overrides

These are the meaningful runtime divergences still left in
`nix-pi/nixos/hosts/private/rpi-box-02.nix`:

- Homepage multi-host Docker inventory
- Ghost blog SMTP TLS relaxation
- Uptime Kuma declarative monitor sync wiring

## Recommended next step

Pick **one** of the following:

1. Keep `ghost-blog` SMTP TLS relaxation host-local, but improve the comment
   and operator docs if needed.
2. Design a reusable Uptime Kuma declarative monitor-sync feature if that
   behavior should exist on more than one host.
3. Stop abstracting and switch to host validation:
   - rebuild `rpi-box-02`
   - validate the updated shared-module behavior for:
     - `unpoller`
     - `postgres-exporter`
     - `mysql-exporter`

If the goal is reliability over abstraction, option 3 is the best next move.

## Validation commands worth reusing

### Repo checks

From each repo root:

```bash
nix develop -c prek run --all-files
```

### Host validation targets

For `rpi-box-02`, the highest-value validations after a rebuild are:

```bash
ssh rpi-box-02 "systemctl --no-pager --full status mysql-exporter"
ssh rpi-box-02 "systemctl --no-pager --full status postgres-exporter"
ssh rpi-box-02 "systemctl --no-pager --full status unpoller"
ssh rpi-box-02 "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'"
ssh rpi-box-02 "curl -fsS http://127.0.0.1:9104/metrics | grep '^mysql_up '"
ssh rpi-box-02 "curl -fsS http://127.0.0.1:9187/metrics | sed -n '1,20p'"
ssh rpi-box-02 "curl -fsS http://127.0.0.1:9130/metrics | sed -n '1,20p'"
```

## Important local-only note

The root-workspace handoff file
`/home/eduardo/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/service_investigation_followups_2026-03-17.md`
contains more detailed running notes, but it is not inside a git repo. This
continuation file is the committed summary intended to survive across sessions.
