# `nix-services` Documentation Index

This file is the local documentation index for repository-level documents in
`nix-services`.

Use `README.md` for the repo overview and ownership boundary.
Use this file when you are already in `nix-services` and need to find the right
class of document quickly.

## Stable Reference Docs

- `repository_boundary_and_responsibility_guidelines.md`
- `architecture_and_implementation_guidelines.md`
- `service_deployment_model.md`
- `runtime_secrets_docker_services.md`
- `storage_persistence_policy_bind_mounts.md`
- `DOCKER_COMPOSE_RESTART_POLICY_GUIDANCE.md`
- `DOC_SYNC_CHECKLIST.md`
- `PUBLIC_REPO_SANITIZATION_POLICY.md`

## Monitoring / Traffic / Platform Plans

- `monitoring_and_metrics_plan_prometheus_traefik.md`
- `tls_enablement_plan_post_dns_traefik.md`
- `pi_hole_deployment_plan_traefik_no_dns_→_dns_transition.md`
- `zero_downtime_pi_hole_dhcp_migration_checklist.md`
- `traefik_first_deployment_plan_pre_dns_operator_validated.md`
- `change_management_and_upgrade_plan.md`

These are design and rollout references. Unless a new rollout is actively in
progress, they should be read as recovery/expansion/planning material rather
than everyday operator truth.

## Session Continuity And Investigation Notes

- `documentation_unification_block_1.md`
- `SERVICE_INVESTIGATION_CONTINUATION_2026-03-18.md`
- `ghost_internal_blog_session_handoff_2026-02-27.md`
- `synology_monitoring_logs_plan.md`

These preserve verified context across sessions. They are not a substitute for
service READMEs or host-owned runtime-difference docs in `nix-pi`.

## Service-Specific Truth

For actual module behavior and options, prefer:

- `services/*/README.md`
- matching `services/*/*.nix`

If the deployed host intentionally differs from shared module behavior, the
canonical host-side record is:

- `../nix-pi/docs/HOST_RUNTIME_DIVERGENCES.md`

For host-owned Uptime Kuma monitor exceptions:

- `../nix-pi/docs/UPTIME_KUMA_MONITOR_POLICY.md`

## Boundary Reminder

- `README.md`
  - repo overview, ownership boundaries, and primary documentation pointers
- `services/*/README.md`
  - shared service behavior, options, and service-local operations
- `../nix-pi/docs/HOST_RUNTIME_DIVERGENCES.md`
  - canonical host-specific runtime differences from shared service defaults
