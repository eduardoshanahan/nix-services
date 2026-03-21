# FossFLOW

FossFLOW is a browser-based diagramming service exposed through Traefik.

## Runtime model

- Host owner: whichever `nix-pi` host enables `services.fossflowCompose`
- Deployment model: NixOS module writes `/etc/fossflow/docker-compose.yml` and
  systemd manages `docker compose up -d` / `docker compose down`
- Container health is gated by `ExecStartPost`, so startup fails if the
  container never becomes healthy

## Important paths

- Module: `services/fossflow/fossflow.nix`
- Compose file template: `services/fossflow/docker-compose.yml`
- Persistent data on host: `services.fossflowCompose.dataDir`
- In-container diagram storage path: `services.fossflowCompose.storagePath`

## Key options

- `services.fossflowCompose.hostname`
- `services.fossflowCompose.network`
- `services.fossflowCompose.dataDir`
- `services.fossflowCompose.storagePath`
- `services.fossflowCompose.enableServerStorage`
- `services.fossflowCompose.image.{repository,tag,digest}`

## Validation

```bash
systemctl --no-pager --full status fossflow
docker ps --filter name=fossflow --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' fossflow
```

If routed through Traefik, also check the configured hostname:

```bash
curl -skI https://<fossflow-hostname>/
```

## Notes

- The module uses a persistent host directory, not a runtime-generated
  bind-mounted file under `/run`, so it did not match the 2026-03-17 reboot
  race pattern that affected Alertmanager and MySQL exporter.
