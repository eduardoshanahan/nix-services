# Task: audited all nix-services image versions and created docs/service-versions.md reference table

## Status

raw

## Source Repo

nix-services

## Context

nixos

## What was attempted

Extracted container image names and pinned versions for all services across nix-services (options.nix defaults),
synology-services (compose.yaml), and nix-cluster (kustomization.yaml / deployment.yaml).

## What worked

- nix-services: grep `repository = lib.mkOption` and `tag = lib.mkOption` with version-like defaults from `*.nix` files
- synology-services: grep `image:` from `compose.yaml` files
- nix-cluster: grep `version:` and `image:` from `kustomization.yaml` and `deployment.yaml`, excluding vendored chart CRDs

## What failed

Nothing failed; some services use `latest` or digest-only pins.

## Wrong assumptions

None.

## Reusable insights

- nix-services image versions live in `services/*/options.nix` as `default = "..."` inside `tag = lib.mkOption` blocks
- synology-services versions live in `hhnas4/*/compose.yaml` as `image: repo:tag`
- nix-cluster Helm chart versions live in `kustomization.yaml` under `helmCharts[].version`
- Reference doc saved to `docs/service-versions.md` in nix-services — update it when bumping any service version

## Candidate for promotion

No — reference doc is the artifact; this investigation is informational only.
