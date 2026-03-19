# Documentation Unification - Block 1 (Ownership Matrix)

Date: 2026-02-25

## Objective

Define a single source of truth per topic across `nix-pi` and `nix-services`, while keeping docs split by repository and removing duplication/contradictions over time.

This block does not rewrite existing docs yet. It establishes ownership and a contradiction register.

Given current project state, all documented deployment plans should be treated as:

- rebuild-from-scratch references
- disaster recovery runbooks
- environment expansion guides

They are not the day-to-day path for already-deployed stable services.

## Repository Roles (Canonical)

- `nix-pi` owns host lifecycle documentation:
  - workstation setup
  - Pi image build/flash/bootstrap
  - host rebuild/deploy flow
  - host inventory and operator run sequences
  - SOPS provisioning workflow
- `nix-services` owns service lifecycle documentation:
  - service module contracts/options
  - container runtime patterns (Compose + systemd)
  - Traefik/service integration model
  - service operations runbooks (including Synology service stacks)

## Source-of-Truth Matrix

| Topic | Canonical repo | Canonical document(s) | Non-canonical repo rule |
| --- | --- | --- | --- |
| Repo boundary and architecture model | `nix-services` | `repository_boundary_and_responsibility_guidelines.md`, `architecture_and_implementation_guidelines.md`, `service_deployment_model.md` | Keep only a short pointer paragraph in `nix-pi` |
| Host setup, provisioning, flashing | `nix-pi` | `docs/lifecycle/SETUP.md`, `docs/lifecycle/PROVISIONING.md`, `sd-image/README.md` | `nix-services` should not duplicate host bootstrap steps |
| Runtime secrets ownership split | `nix-services` | `runtime_secrets_docker_services.md` | `nix-pi` references this for the contract and documents only host-side secret provisioning |
| SOPS/age host secret provisioning | `nix-pi` | `docs/lifecycle/SECRETS.md` | `nix-services` references only paths/contracts, not provisioning steps |
| Service module options and behavior | `nix-services` | `services/*/README.md` + matching `services/*/*.nix` | `nix-pi` may list enabled services, but links back for details |
| Deploy/rebuild operator command flow | `nix-pi` | `README.md` (or future `docs/DEPLOY.md`) | `nix-services` may mention integration model, not per-host command recipes |
| DNS/DHCP migration operations | split by scope | `nix-services`: service design/cutover constraints; `nix-pi`: operator execution checklist | Each side links to the other and avoids re-stating full procedure |
| TLS enablement strategy | `nix-services` | `tls_enablement_plan_post_dns_traefik.md` | `nix-pi` only references and records host-specific execution notes |
| Monitoring stack service behavior | `nix-services` | `monitoring_and_metrics_plan_prometheus_traefik.md`, service READMEs | `nix-pi` only keeps “what is enabled on host X” summary |
| Synology service artifacts and runbooks | `synology-services` | sibling repo `../synology-services/**` | `nix-pi` should not duplicate Synology operational runbooks |
| Public repo sanitization policy | `nix-services` | `PUBLIC_REPO_SANITIZATION_POLICY.md` | `nix-pi` should replace duplicate body with a pointer doc |
| Reflash/rejoin runbook | `nix-pi` | `reflash_rejoin_node_runbook.md` | `nix-services` should replace its runbook with a pointer doc |
| Codex response style policy | choose one owner (recommended: `nix-services`) | `response_style.md` | Other repo keeps a pointer only |

## Duplication and Contradiction Register (First Pass)

### Exact duplicates

- `PUBLIC_REPO_SANITIZATION_POLICY.md` exists in both repos with identical content.
  - Status: **Resolved on 2026-02-25**.
  - Risk: drift when one is edited first.
  - Resolution: keep canonical in `nix-services`; replace `nix-pi` copy with short pointer.
  - Evidence: `nix-pi/docs/policy/PUBLIC_REPO_SANITIZATION_POLICY.md` is now pointer-only.

### Divergent duplicates

- `reflash_rejoin_node_runbook.md` exists in both repos with different scope/depth.
  - Status: **Resolved on 2026-02-25**.
  - Risk: operator may follow the wrong sequence.
  - Resolution: canonicalize in `nix-pi`; convert `nix-services` file into a pointer + rationale.
  - Evidence: `nix-services/reflash_rejoin_node_runbook.md` is now pointer-only.

- `response_style.md` exists in both repos and differs.
  - Status: **Resolved on 2026-02-25**.
  - Risk: AI assistant behavior may diverge per repo unexpectedly.
  - Resolution: pick one canonical policy and point from the other repo.
  - Evidence: `nix-pi/docs/prompts/response_style.md` is now pointer-only to `nix-services/response_style.md`.

### Scope overlaps needing boundary wording

- DNS migration content appears in both repos (`nix-pi/docs/plans/zero_downtime_dns_migration_checklist.md`, `nix-services/pi_hole_deployment_plan_traefik_no_dns_→_dns_transition.md`, `nix-services/zero_downtime_pi_hole_dhcp_migration_checklist.md`).
  - Status: **Resolved on 2026-02-25**.
  - Risk: contradictory sequencing if both documents evolve independently.
  - Resolution: split responsibility explicitly:
    - `nix-services`: service constraints and invariants.
    - `nix-pi`: operator execution checklist per environment.
  - Evidence:
    - `nix-services/pi_hole_deployment_plan_traefik_no_dns_→_dns_transition.md` now includes an explicit documentation boundary note pointing to `nix-pi`.
    - `nix-pi/docs/plans/zero_downtime_dns_migration_checklist.md` now declares operator-execution ownership and points back to `nix-services` for constraints.

- Monitoring and observability guidance appears in both repos (`nix-pi/README.md` runtime checks vs `nix-services` monitoring/service docs).
  - Status: **Resolved on 2026-02-25**.
  - Risk: command drift and stale checks.
  - Resolution: keep host-specific “known good checks” in `nix-pi`; keep service behavior/contracts in `nix-services`.
  - Evidence:
    - `nix-services/monitoring_and_metrics_plan_prometheus_traefik.md` now includes an explicit documentation boundary note pointing to `nix-pi/README.md` for host runtime checks.
    - `nix-pi/README.md` now includes a `Monitoring Documentation Boundary` section pointing to canonical service-side monitoring docs in `nix-services`.

### Internal consistency issue discovered during review

- `nix-services` Traefik plan text mentioned dashboard reachability in validation checklists, while current Traefik module uses `--api=false`.
  - Status: **Resolved on 2026-02-25**.
  - Updated docs:
    - `traefik_first_deployment_plan_pre_dns_operator_validated.md`
    - `pi_hole_deployment_plan_traefik_no_dns_→_dns_transition.md`
    - `monitoring_and_metrics_plan_prometheus_traefik.md`
    - `change_management_and_upgrade_plan.md`
  - Resolution: dashboard-specific validation language was replaced with Traefik service/container health and startup-log validation aligned with current implementation.

## Editing Rules For Next Blocks

1. Every non-canonical doc section should be reduced to:
   - one-paragraph context
   - link to canonical document
   - optional local host-specific notes only

1. Avoid duplicate procedural steps across repos.

1. Keep service option documentation only in `nix-services` service READMEs.

1. Keep per-host command snippets only in `nix-pi`.

1. Mark plan documents as `rebuild/recovery/expansion` references unless a new rollout is explicitly being executed.

## Proposed Block 2 Scope

- Update top-level README linkage only (no deep doc rewrites):
  - `nix-services/README.md`
  - `nix-pi/README.md`
- Add a short “Documentation Ownership” section in both with explicit cross-links.
- Convert only one duplicate first (recommended: sanitization policy in `nix-pi` -> pointer).
