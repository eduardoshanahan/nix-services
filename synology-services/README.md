# synology-services

Git-tracked templates for Synology stack deployment.

This directory is intentionally safe for publication:

- No real hostnames or IP addresses
- No credentials or certificate material
- No environment-specific secrets

## Layout

- `monitoring/compose.yaml`
- `monitoring/prometheus/prometheus.yml`
- `monitoring/prometheus/alert.rules.yml`
- `monitoring/alertmanager/alertmanager.yml`
- `monitoring/grafana.env.example`

## Usage

1. Copy this directory (or selected files) to Synology private storage.
2. Replace placeholders and local defaults with your private values.
3. Keep secret values in private files only (for example `grafana.env`).
