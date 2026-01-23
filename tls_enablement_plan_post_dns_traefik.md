# TLS Enablement Plan (Post-DNS, Traefik)

> **Operator-validated plan**  
> This document contains both declarative steps (implemented by Codex) and operational validation gates (validated by a human operator).
>
> Codex MUST NOT attempt to automate, infer, or “satisfy” operator-validated checks.

This document defines the **step-by-step plan** to enable **TLS/HTTPS** on services routed through **Traefik**, **after DNS is active and stable**.

It builds on:
- *Traefik-First Deployment Plan (Pre-DNS, Operator-Validated)*
- *Pi-hole Deployment Plan (Traefik + No-DNS → DNS Transition)*

---

## 0. Goal and Non-Goals

### Goal

- Enable HTTPS for internal services routed through Traefik
- Use DNS-backed hostnames (no `/etc/hosts` dependency)
- Establish a repeatable TLS pattern for all future services

### Non-goals

- Public internet exposure
- External traffic routing
- Zero-trust / mTLS (may be added later)

---

## 1. Preconditions (OPERATOR-VALIDATED, MUST be true)

These preconditions are **not enforced by code**.

Codex MUST assume they have been **manually validated by the operator** before proceeding.

The operator MUST confirm:

- [ ] Pi-hole DNS is active and stable
- [ ] Clients resolve service hostnames via Pi-hole
- [ ] Traefik is running and routing services correctly over HTTP
- [ ] No TLS configuration is currently enabled in Traefik

### How to validate (informational, not automated)

- **DNS resolution**: `dig service.local @<pihole-ip>`
- **HTTP routing**: Access service UI over plain HTTP
- **Traefik health**: Dashboard reachable and error-free

If any item fails, STOP and resolve it before continuing.

---

## 2. TLS Strategy Selection (MANDATORY DECISION)

Before implementation, the operator MUST choose **one** TLS strategy.

Codex MUST NOT choose on behalf of the operator.

### Option A — Internal CA (recommended for homelab)

- Use a private Certificate Authority
- Certificates trusted by internal clients
- No external dependencies

Examples:
- mkcert
- step-ca
- custom OpenSSL CA

### Option B — ACME with internal DNS

- Use ACME with DNS challenge
- Requires DNS provider API support
- More complex, but closer to production patterns

For most homelabs, **Option A is recommended**.

---

## 3. Internal CA TLS Enablement (Option A)

### 3.1 Certificate material handling

Certificates and keys:

- MUST NOT be committed to the repo
- MUST be provided via external paths (e.g. `/run/secrets`)
- MAY be generated manually by the operator

Codex MUST reference **paths only**, never values.

---

### 3.2 Traefik static TLS configuration

Codex MUST:

- Extend Traefik configuration to:
  - Enable HTTPS entrypoint (443)
  - Reference certificate and key paths

Example (conceptual):

```yaml
entryPoints:
  websecure:
    address: ":443"
```

Actual cert paths are operator-provided and not committed.

---

### 3.3 Router TLS configuration

For each HTTP service:

- Enable TLS on the Traefik router
- Reuse the same certificate or wildcard where appropriate

Codex MUST NOT duplicate certificate material.

---

## 4. HTTP → HTTPS Transition

### 4.1 Initial dual-stack phase

During transition:

- HTTP remains enabled
- HTTPS is enabled in parallel
- No automatic redirects yet

This allows rollback without breaking access.

---

### 4.2 Enforce HTTPS (after validation)

Once HTTPS is validated:

- Enable HTTP → HTTPS redirection in Traefik
- Apply redirection globally

Codex MUST ensure this change is reversible.

---

## 5. Validation Checklist (OPERATOR-VALIDATED)

The operator MUST validate:

- [ ] HTTPS works for all routed services
- [ ] Certificates are trusted by client devices
- [ ] No certificate warnings appear in browsers
- [ ] HTTP redirects correctly to HTTPS (after enforcement)
- [ ] Services remain reachable after host reboot

Codex MUST NOT proceed until validation passes.

---

## 6. Failure Modes and Guardrails

### 6.1 Certificate trust failures

If clients reject certificates:

- Import the CA certificate into client trust stores
- Verify certificate hostnames match DNS names

---

### 6.2 Traefik startup failures

If Traefik fails to start:

- Verify certificate/key paths exist
- Ensure permissions allow Traefik to read them
- Temporarily disable TLS to restore service

---

## 7. Future Extensions (Out of Scope)

- ACME DNS challenges
- Public certificates
- Per-service certificates
- mTLS between services

These require separate plans.

---

## 8. Summary: Mandatory Execution Order

1. Operator validates DNS and HTTP routing
2. Operator selects TLS strategy
3. Certificates are generated out-of-band
4. Codex enables TLS support in Traefik
5. Operator validates HTTPS
6. Codex enforces HTTP → HTTPS redirect

Codex MUST NOT skip steps.

