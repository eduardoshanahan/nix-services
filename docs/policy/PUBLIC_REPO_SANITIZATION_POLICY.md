# Public Repo Sanitization Policy

Use this checklist before every commit/push to avoid leaking internal topology or secrets.

## What must NOT be published

- Real internal hostnames/FQDNs (example: `*.home.arpa`).
- Real LAN IPs (example: `192.168.x.x`, `10.x.x.x` tied to real infra).
- Real SNMP communities, API tokens, passwords, keys, certs.
- Real private service URLs and reverse-proxy host rules.

## What is allowed in shared files

- Placeholders such as:
  - `<nas-a-fqdn>`, `<logs-node-lan-ip>`, `internal.example`
  - `change-me-snmp-community`
- Generic examples that are clearly non-production.

## Keep real values only in private scope

- `nixos/hosts/private/*`
- secrets files (`sops`, runtime secret files, local `.env`)
- local operator notes not committed to shared/public repos

## Required pre-push checks

Run from repo root:

```bash
rg -n --hidden --no-ignore -S 'home\.arpa|192\.168\.|10\.[0-9]+\.[0-9]+\.[0-9]+|([A-Za-z0-9_-]{16,})' --glob '*.md' --glob '*.nix' --glob '*.yml' --glob '*.yaml'
gitleaks detect --no-git --source . --max-target-megabytes 5
```

If any result contains real infrastructure identifiers or credentials, sanitize before push.

## Dashboard/query guidance

- Do not hardcode real hostnames in shared Grafana/Loki queries.
- Prefer job/label-driven selectors (for example `job="synology-snmp"`).
- Use host-specific filters only in private overlays.

## PR review gate

Before merge:

1. Confirm no real infra identifiers in shared docs/examples.
2. Confirm no credentials/secrets in tracked files.
3. Confirm placeholders are used consistently.
