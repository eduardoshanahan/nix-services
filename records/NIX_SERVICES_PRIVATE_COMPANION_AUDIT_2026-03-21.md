# `nix-services` Private Companion Audit - 2026-03-21

## Purpose

This record captures the first explicit audit of whether `nix-services`
currently needs a real sibling private companion repo similar to
`nix-cluster-private` or `nix-pi-private`.

The goal is to avoid creating a placeholder migration just because the pattern
exists elsewhere. The decision here should be based on real evaluation-time
needs, not symmetry.

## Audit scope

The audit reviewed:

- `flake.nix`
- `README.md`
- `docs/policy/private_vs_public_separation_guidelines.md`
- `docs/policy/PUBLIC_REPO_SANITIZATION_POLICY.md`
- shared service READMEs that still referenced old host-private paths
- service modules and helpers for runtime secret handling under:
  - `services/`
  - `lib/`

## Current finding

As of 2026-03-21:

- `nix-services` does **not** currently need an evaluation-time private flake
  to operate correctly
- the repo already evaluates publicly without private files
- the dominant private contract is runtime-path based:
  - `/run/secrets/...`
- host-specific non-secret divergences are currently owned in
  `../nix-pi-private`, not in `nix-services`

That means there is no current equivalent of the old brittle
`nix-pi/nixos/hosts/private/*.nix` model inside `nix-services`.

## Evidence

### 1. No private flake input in `flake.nix`

`nix-services/flake.nix` currently exposes:

- a dev shell
- exported service modules
- exported service aliases

It does not currently:

- declare a `private` flake input
- resolve host-private modules
- conditionally import sibling private files for evaluation

### 2. Shared modules mostly consume runtime secret paths

The service modules overwhelmingly use patterns such as:

- `passwordFile`
- `secretFile`
- `authKeyFile`
- generated runtime env files under `/run/secrets/...`

This is the right separation:

- public repo owns reusable module behavior
- host layer provisions decrypted runtime files
- service modules consume only the runtime paths

### 3. Remaining private truth is host-owned

The meaningful remaining non-secret runtime divergences still referenced from
shared docs are host-owned behaviors such as:

- Homepage multi-host Docker inventory
- Ghost SMTP TLS relaxation
- Uptime Kuma declarative monitor sync wiring

Those belong in `../nix-pi-private/modules/rpi-box-02.nix`, not in a shared
`nix-services-private` overlay.

### 4. Existing "private overlay" language is mostly legacy policy wording

The audit found policy/docs language that still mentions:

- `private/`
- `hosts-private/`
- private overlays as a possible extension point

But this language is not backed by an active evaluation-time private contract in
the actual code.

## Decision

Current decision:

- do **not** introduce `nix-services-private` as an evaluation-time dependency
  yet
- keep runtime secrets on `/run/secrets/...`
- keep host-owned divergences in `nix-pi` / `nix-pi-private`
- treat any future `nix-services-private` repo as conditional, not mandatory

In other words:

- `nix-services-private` is a reserved future option
- not a current operational requirement

## What would justify a future `nix-services-private`

Create a real private companion repo for `nix-services` only if a future change
introduces shared service-level private values that:

1. must exist at evaluation time, and
2. do not belong to a specific host layer, and
3. are not better represented as runtime secret paths

Examples that might justify it later:

- shared non-secret service defaults that should stay private across hosts
- reusable private service overlays that truly apply across more than one host
- operator-private service contracts that are not secrets but also should not
  live in the public repo

## What should stay out of a future `nix-services-private`

Even if such a repo is created later, it should still not own:

- decrypted runtime secrets
- SOPS provisioning
- host selection
- one-host runtime divergences
- host-local deployment exceptions

Those remain host-layer concerns.

## Immediate follow-up completed during this audit

The shared docs were aligned with the current host-private reality by replacing
stale references to the old `nix-pi/nixos/hosts/private/...` layout with:

- `../nix-pi-private/modules/rpi-box-02.nix`

Affected docs included:

- `services/homepage/README.md`
- `services/uptime-kuma/README.md`
- `services/ghost/README.md`
- `docs/policy/PUBLIC_REPO_SANITIZATION_POLICY.md`

## Recommended next step

Treat `nix-services` as:

- companion-pattern compatible
- but not currently companion-pattern dependent

The next migration/inventory target should therefore shift to:

- `synology-services`

unless a new concrete `nix-services` evaluation-time private requirement is
discovered later.
