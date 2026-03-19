# Reflash & Rejoin Node Runbook (Pointer)

Canonical source of truth for host reflash/rejoin procedure lives in:

- `nix-pi/reflash_rejoin_node_runbook.md`

This file is intentionally pointer-only to avoid drift between repositories.

## Scope In `nix-services`

`nix-services` documents service contracts and runtime behavior after a host is
rejoined. Host lifecycle procedures (flash/bootstrap/rejoin) are owned by
`nix-pi`.

## Local Rule

When a host must be rebuilt from scratch or rejoined, follow the canonical
runbook in `nix-pi` and treat service plans in this repo as recovery/validation
references.
