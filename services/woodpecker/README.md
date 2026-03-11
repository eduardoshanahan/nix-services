# Woodpecker CI (rpi-box-02)

Compose-backed Woodpecker deployment for the NixOS service-host pattern used on
`rpi-box-02`.

## Topology

- Woodpecker server on `rpi-box-02`
- ARM64 agent on `rpi-box-02`
- External PostgreSQL on `postgres.<homelab-domain>:5433`
- Gitea forge on `https://gitea.<homelab-domain>`
- Separate AMD64 NAS agent deployed from `synology-services/hhnas4/woodpecker-agent`

## Required secrets

The host wiring expects these SOPS keys:

- `woodpecker-agent-secret`
- `woodpecker-gitea-client`
- `woodpecker-gitea-secret`
- `woodpecker-postgres-password`

## Required Gitea OAuth app

Create a Gitea OAuth application with callback URL:

```text
https://woodpecker.<homelab-domain>/authorize
```

## Database bootstrap

Create the database and role on the shared PostgreSQL host:

```sql
CREATE ROLE woodpecker LOGIN PASSWORD '<runtime-secret>';
CREATE DATABASE woodpecker OWNER woodpecker;
```

## Notes

- Open registration should stay disabled for this deployment.
- The colocated agent defaults to one workflow at a time.
- For private Gitea repositories, prefer Woodpecker's documented SSH clone path:
  add a repo-scoped deploy key in Gitea, store the private key as a
  repo-scoped Woodpecker secret, and set `clone.git.settings.use-ssh: true` in
  the workflow.
- The NAS AMD64 agent intentionally remains a separate deployment because it has
  a different risk profile and lifecycle than the Pi-hosted server.
