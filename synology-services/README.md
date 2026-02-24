# synology-services

Git-tracked templates for Synology stack deployment.

This directory is intentionally safe for publication:

- No real hostnames or IP addresses
- No credentials or certificate material
- No environment-specific secrets

## Layout

- `monitoring/compose.yaml` (currently empty baseline)

## Usage

1. Copy this directory (or selected files) to Synology private storage.
2. Add only the services you currently want to run.
3. Keep secret values in private files only.
