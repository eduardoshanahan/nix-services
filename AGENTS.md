# AGENTS.md

This file is the working guide for agents operating inside `nix-services/`.

`nix-services` is the shared service layer of the homelab. It owns:

- reusable NixOS service modules exported from the flake
- service-local Docker Compose definitions and generated config
- systemd supervision for Compose-backed services
- shared service options, assertions, and defaults
- service-side operational docs, rollout plans, and policy docs
- shared runtime-secret consumption helpers
- Synology service runbooks that belong with service architecture

`nix-services` does not own host bootstrap, hardware enablement, SOPS setup, or
which host runs a service. Those belong in `../nix-pi`.

## Start Here

When working in `nix-services`, read in this order:

1. `README.md`
2. `DOCUMENTATION_INDEX.md`
3. the stable reference docs that match the task:
   - `docs/policy/repository_boundary_and_responsibility_guidelines.md`
   - `docs/policy/architecture_and_implementation_guidelines.md`
   - `docs/policy/service_deployment_model.md`
   - `docs/policy/runtime_secrets_docker_services.md`
   - `docs/policy/storage_persistence_policy_bind_mounts.md`
   - `docs/policy/DOCKER_COMPOSE_RESTART_POLICY_GUIDANCE.md`
   - `docs/policy/DOC_SYNC_CHECKLIST.md`
   - `docs/policy/PUBLIC_REPO_SANITIZATION_POLICY.md`
4. the relevant service README under `services/*/README.md`
5. the matching implementation files:
   - `flake.nix`
   - `lib/*.nix`
   - `services/*/*.nix`
   - `services/*/docker-compose.yml`
   - `services/*/render.nix`
   - `services/*/options.nix`
   - `services/*/scripts.nix`
6. if the task touches prior investigation or rollout work:
   - read stable public plans in `docs/plans/`
   - read matching private continuity notes in `../nix-services-private/records/`
   - check for `../nix-services-private/records/<service>/INVESTIGATION.md` and
     read it before making any changes — it records verified facts and working
     procedures for that service; create it if it does not exist yet

If a local doc points to `nix-pi` for host truth, follow the pointer instead of
duplicating host behavior here.

## Ownership Boundary

Use `nix-services` for:

- shared service behavior
- reusable module options and assertions
- Compose generation and systemd lifecycle patterns
- runtime secret consumption contracts
- service READMEs and service-side policy docs
- shared monitoring/logging/traffic design docs

Use `nix-pi` for:

- host selection and service enablement
- hardware, images, and Raspberry Pi bootstrap
- Docker enablement at the host layer
- SOPS provisioning and `/run/secrets/...` materialization
- host-local overrides and runtime divergences
- host-owned Uptime Kuma monitor inventory and operator workflows

Rule: if the change would be useful on more than one host, it probably belongs
here. If it is a one-host exception, it probably belongs in `nix-pi`.

## Public Vs Private References

Public repos in this workspace may intentionally use anonymized placeholders
such as `*.internal.example` for Git remotes, service URLs, hostnames, and
other environment-specific identifiers.

Treat those values as sanitized public-side references, not as the canonical
live endpoints. Check the matching private sibling repo for the real values
before assuming a placeholder address is wrong or unavailable.

## Sandbox And Homelab DNS

Access to real homelab hostnames under `*.<homelab-domain>` should be treated as
host-network work, not ordinary sandbox-safe repo work.

If a command needs to reach `*.<homelab-domain>` over SSH, Git, HTTP, HTTPS, or
similar network paths, prefer running it outside the sandbox. Do not change repo
code just because a sandboxed command reports temporary resolution failure for a
healthy homelab hostname.

## Repo Structure

- `flake.nix`: dev shell plus exported service modules
- `lib/`: shared helpers, especially runtime-secret and Servarr reconciliation helpers
- `services/<name>/`: one service per directory
- `services/<name>/README.md`: canonical service behavior/options/operations doc
- `docs/policy/`: stable architecture, boundary, lifecycle, and sanitization docs
- `docs/plans/`: rollout and expansion plans
- `docs/recovery/`: recovery and rebuild runbooks
- `records/`: pointer-only directory; private continuity notes live in `../nix-services-private/records/`

Common service shapes in this repo:

- checked-in compose + module wiring
- generated compose or generated config via `render.nix`
- option splits in `options.nix`
- helper scripts in `scripts.nix`
- health-gated startup via `ExecStartPost`
- post-start reconciliation units for some Servarr apps
- multi-instance service shape for Ghost

## Hard Invariants

- Assume target hosts are `aarch64-linux` unless explicitly told otherwise.
- Keep secrets, tokens, private keys, real domains, and real internal IPs out of Git.
- Public/shared files must stay sanitized and safe to publish.
- Private continuity notes, environment-specific operator workflow, and other
  sensitive operational details belong in `../nix-services-private/records/`,
  not in public docs or records here.
- Services are imported by consumers; this repo does not deploy to hosts directly.
- Docker Compose is always owned by NixOS systemd units, never by manual `docker compose up`.
- Traefik permanently owns host ports `80` and `443`.
- HTTP apps should be exposed internally and routed through Traefik.
- Prefer bind-mounted persistent paths like `/var/lib/<service>` by default.
- Use the Nix-provided Docker path:
  `${config.virtualisation.docker.package}/bin/docker`
- Keep changes small, isolated, and reversible.

## Dev Shell And Git

- Prefer running Git commands from `nix develop`.
- At the start of a session, enter `nix develop`, run `git fetch origin`, then
  `git pull --rebase origin main`, and review `git status --short --branch`
  before editing.
- This repo expects pre-commit tooling from the dev shell; if hooks fail because
  tools are missing, the fix is usually to enter `nix develop`, not to skip hooks.
- Do not bypass hooks by default just because the host environment lacks the
  required binaries.
- Do not use `--no-verify` as a workaround for missing local tools; enter
  `nix develop` and rerun the normal workflow instead.
- When the task is complete, commit and push the finished changes to `origin`
  instead of leaving them only in the local checkout unless the user asks for
  that.
- If the task changes service behavior, the work is not finished at commit/push
  time: update the owning `nix-pi` or `nix-cluster` consumer as needed, do the
  full host rebuild, and verify on the live host that the fix still works after
  the rebuild.

## Implementation Patterns To Preserve

Most modules in this repo follow this pattern:

- expose options under `services.<name>` or `services.<name>Compose`
- validate inputs with assertions
- enable Docker declaratively
- write compose/config into `/etc/<service>/...`
- manage lifecycle with a systemd `Type = "oneshot"` unit using
  `docker compose up -d` and `docker compose down`
- wait for `docker.service` and `network-online.target`
- create/check runtime directories and files in `ExecStartPre`
- create the external Docker network if needed
- use `restartTriggers` for generated inputs

Preserve existing naming and exported interfaces in `flake.nix`. Consumers rely
on both `outputs.nixosModules.<name>` and `outputs.services.<name>`.

## Secrets And Runtime Files

- `nix-services` consumes runtime secret paths; it does not provision secrets.
- Prefer `lib/runtime-secret-env.nix` when a container needs a plain env var at startup.
- Prefer `lib/runtime-secrets.nix` when the service supports direct `*_FILE`-style path passing.
- Secrets must only be read at runtime from absolute paths such as `/run/secrets/...`.
- Never read secret contents during Nix evaluation.
- Be careful with ephemeral `/run` single-file bind mounts. Read
  `docs/policy/DOCKER_COMPOSE_RESTART_POLICY_GUIDANCE.md` before adding or changing them.

If a service already uses a custom runtime env writer, do not replace it with a
generic helper unless the behavior truly matches and the change stays scoped.

## Service README Rules

`services/*/README.md` is the canonical operator-facing doc for shared service truth.

Update the README in the same change when you alter:

- module options
- defaults
- runtime paths
- startup, health, or restart behavior
- secret-file contracts
- image pinning policy
- shared host-agnostic operational expectations

If behavior is host-specific, point to the canonical `nix-pi` doc instead of
copying host truth here.

## Host-Specific Reality

Some shared service READMEs intentionally point to host-owned exceptions in
`../nix-pi/docs/policy/HOST_RUNTIME_DIVERGENCES.md` or
`../nix-pi/docs/policy/UPTIME_KUMA_MONITOR_POLICY.md`.

Do not pull those host-local behaviors into shared modules just to “clean up”
duplication unless the behavior is becoming reusable.

Current notable host-local exceptions mentioned from this repo include:

- Homepage Docker inventory overrides
- Ghost SMTP TLS relaxation for one host/instance
- Uptime Kuma declarative monitor sync wiring

## Documentation Sync Rules

When behavior changes, update the owning docs in the same change.

Especially:

- shared service module changes:
  update `services/*/README.md`
- repo-wide lifecycle/runtime-secret policy changes:
  update the relevant top-level policy doc
- doc ownership or navigation changes:
  update `README.md`, `DOCUMENTATION_INDEX.md`, and `docs/policy/DOC_SYNC_CHECKLIST.md`
- public/private boundary changes:
  update `docs/policy/PUBLIC_REPO_SANITIZATION_POLICY.md` and/or
  `docs/policy/private_vs_public_separation_guidelines.md`

Use `docs/policy/DOC_SYNC_CHECKLIST.md` as the merge gate.

## Practical Decision Heuristics

- Need to add or change a reusable service option:
  work here.
- Need to change how a Compose-backed service is rendered or supervised:
  work here.
- Need to wire a secret source, SOPS declaration, or host-specific secret path:
  work in `nix-pi`.
- Need to document a one-host override:
  implement and document it in `nix-pi`, then add only a pointer here if shared docs need the warning.
- Need to add a new service:
  start from `docs/policy/standard_service_template_nix_os_docker_compose.md`, then follow the patterns of the closest existing module.
- Need to change a Servarr integration:
  inspect `lib/servarr-reconcile.nix` and the matching app modules before editing.
- Need to touch ingress behavior:
  inspect `services/traefik/*` and keep the change isolated from unrelated service work.

## Avoid

- putting host placement logic in shared modules
- hardcoding real domains, IPs, credentials, or topology details
- introducing imperative Docker steps as part of normal operation
- changing exported flake names casually
- editing service behavior without updating its README
- duplicating host-specific truth from `nix-pi`
- assuming every service should use the same helper just because a helper exists
- bundling unrelated service changes into one pass
