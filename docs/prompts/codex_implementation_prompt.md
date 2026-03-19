# Codex Implementation Prompt — nix-services

## CURRENT PHASE

The project is in **Phase 2.2: Runtime Secret → Env Injection Helper**.

This phase exists to **extract and formalize a reusable pattern**
that was validated during the Pi-hole v6 deployment.

No new services are being added in this phase.

---

## OBJECTIVE (STRICT)

Implement a **reusable helper** in `nix-services` that:

- Reads a runtime-provisioned secret file (absolute path)
- Generates a **runtime-only env file** under `/run/secrets`
- Is safe for secrets (never enters the Nix store)
- Is designed for services that **do NOT support `*_FILE` natively**
- Can be reused by multiple services without copy-paste

This helper MUST be used to refactor the existing Pi-hole service,
without changing its external behavior.

---

## SCOPE (ALLOWED)

You MAY:

- Add a new helper under `lib/`
- Import that helper from `services/pihole/pihole.nix`
- Replace inline shell logic with the shared helper
- Make minimal documentation updates if required for clarity

You MUST:

- Keep all secrets out of the repository
- Preserve existing service options and semantics
- Preserve the Flake Interface Contract
- Preserve repository boundaries

---

## SCOPE (FORBIDDEN)

You MUST NOT:

- Add new services
- Modify nix-pi or any host configuration
- Change Docker images, versions, or ports
- Add TLS, ACME, DNS, or monitoring
- Change Traefik configuration
- Introduce service-specific logic into the helper
- Refactor unrelated code

If a change is not strictly required to extract the helper,
DO NOT make it.

---

## HELPER DESIGN REQUIREMENTS

The helper MUST:

- Live under: `lib/`
- Be generic (no Pi-hole-specific naming or logic)
- Accept parameters:
  - `name` (used for filenames/logging)
  - `secretFile` (absolute path, runtime-provisioned)
  - `envVar` (environment variable name to emit)
- Generate an env file at:
  - `/run/secrets/<name>.env`
- Fail fast with a clear error if:
  - `secretFile` is null
  - `secretFile` does not exist
  - `secretFile` is empty
- Strip trailing newlines from the secret
- Escape values safely for shell-compatible env files
- Set restrictive permissions (`0700` dir, `0600` file)
- Never write secrets to the Nix store

The helper MUST return a value suitable for use in:

- `systemd.services.<name>.serviceConfig.ExecStartPre`

---

## PI-HOLE REFACTOR REQUIREMENTS

After introducing the helper:

- Update `services/pihole/pihole.nix` to use the helper
- Remove inline secret-processing shell scripts
- Ensure Pi-hole continues to:
  - Generate `/run/secrets/pihole.env`
  - Inject `FTLCONF_webserver_api_password` correctly
  - Require `services.pihole.webPasswordFile` via assertion

Behavior MUST remain identical from the host’s perspective.

---

## DOCUMENTATION REQUIREMENTS

If documentation is updated:

- Keep changes minimal
- Only document:
  - When to use the helper
  - When NOT to use it (services supporting `*_FILE`)
- Do NOT rewrite existing documents

---

## SUCCESS CRITERIA

This phase is complete when:

- The helper exists and is reusable
- Pi-hole uses the helper
- No secrets appear in Git, Nix store, or logs
- `nix flake check` passes
- No other services are affected

---

## WORKING MODE (MANDATORY)

- Make the smallest change that moves the plan forward
- Prefer correctness over abstraction
- Stop immediately if any ambiguity arises
- Ask for clarification instead of guessing

Begin implementation.
