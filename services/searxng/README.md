# SearXNG

SearXNG is a metasearch service exposed through Traefik.

## Runtime model

- Host owner: whichever `nix-pi` host enables `services.searxngCompose`
- Deployment model: NixOS module writes `/etc/searxng/docker-compose.yml` and
  systemd manages `docker compose up -d` / `docker compose down`
- Startup is health-gated with `ExecStartPost`

## Important paths

- Module: `services/searxng/searxng.nix`
- Compose file template: `services/searxng/docker-compose.yml`
- Persistent config directory on host: `services.searxngCompose.configDir`
- Persistent cache/data directory on host: `services.searxngCompose.dataDir`

## Key options

- `services.searxngCompose.hostname`
- `services.searxngCompose.network`
- `services.searxngCompose.configDir`
- `services.searxngCompose.dataDir`
- `services.searxngCompose.image.{repository,tag,digest}`

## Validation

```bash
systemctl --no-pager --full status searxng
docker ps --filter name=searxng --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' searxng
```

If routed through Traefik, also check the configured hostname:

```bash
curl -skI https://<searxng-hostname>/
```

## Notes

- The service uses persistent host directories for config and cache, not a
  runtime-generated single-file bind mount from `/run`, so it did not match the
  2026-03-17 reboot race class.
