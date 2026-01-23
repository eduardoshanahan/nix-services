# Pi-hole Deployment Plan (Traefik + No-DNS → DNS Transition)

This document defines the **step-by-step implementation plan** for deploying **Pi-hole** behind **Traefik** on ARM64 NixOS boxes, starting **before DNS is active**, and then transitioning to **Pi-hole-provided DNS** once validated.

This plan is written to be **directly executable by Codex**.

Codex MUST follow this plan **in order** and MUST comply with:

- *Private vs Public Separation Guidelines*
- *Architecture & Implementation Guidelines*
- *Repository Boundary & Responsibility Guidelines*
- *ARM64-Specific Deployment Considerations*
- *Traefik-First Deployment Plan (Pre-DNS)*

---

## 0. Goal and Scope

### Goal

- Deploy **two Pi-hole instances** (primary + secondary) on separate boxes
- Expose Pi-hole UI **only via Traefik** (no direct host port 80/443 from Pi-hole)
- Ensure Pi-hole DNS can be enabled safely after UI validation
- Transition from **no-DNS testing** to **Pi-hole as active DNS** for the network

### Non-goals (for this plan)

- Let’s Encrypt / public TLS
- DHCP server configuration (router-based DHCP is assumed)
- Gravity Sync / shared blocklists (may be added later)

---

## 1. Preconditions (OPERATOR-VALIDATED, MUST be true)

These preconditions are **not enforced by code**.

Codex MUST assume they have been **manually validated by the operator** before proceeding with any Pi-hole-related implementation.

Before starting Pi-hole work, Codex MUST confirm the operator has verified:

- [ ] Traefik is deployed and stable on the target box(es)
- [ ] Traefik owns host ports **80 and 443** (exclusively)
- [ ] Traefik dashboard is reachable (via `/etc/hosts` on a client)
- [ ] Docker and systemd supervision are working (reboot test)

### How to validate (informational, not automated)

- **Traefik dashboard**: Open a browser to the Traefik dashboard hostname (via `/etc/hosts`).
- **Port ownership**: Verify ports 80 and 443 are bound by Traefik (`ss -lntup | grep ':80\|:443'`).
- **Reboot test**: Reboot the host and confirm Traefik is running automatically.

If any item fails, STOP and fix Traefik first.

---

## 2. Repository Structure (Required)

Create the Pi-hole service directory:

```
services/
  pihole/
    docker-compose.yml
    pihole.nix
```

Do not add Pi-hole logic to host files.

---

## 3. Pi-hole Deployment Model (MANDATORY)

### 3.1 Ports

- Pi-hole DNS uses **host port 53** (TCP + UDP)
- Pi-hole UI MUST NOT bind to host port 80 or 443
- Pi-hole UI MUST be reachable only through Traefik routing

Traefik permanently owns 80/443.

### 3.2 Networking

Pi-hole MUST join:

- The dedicated Traefik Docker network (so Traefik can route to it)
- A Pi-hole-specific network if needed (optional)

### 3.3 Data persistence

Pi-hole MUST use persistent volumes for:

- Configuration
- DNS settings
- Gravity database

No state may be stored in ephemeral container layers.

---

## 4. Pre-DNS Phase: UI-First Validation

### 4.1 Intention

Pi-hole must be deployable and testable **before** it becomes your network DNS.

During this phase:

- Pi-hole container runs
- UI is routed via Traefik
- DNS port 53 can be left **disabled** or **bound but not used by clients**

### 4.2 Access without DNS

Until DNS exists, UI access is via client-side `/etc/hosts`.

Client (not committed):

```
<BOX_IP> pihole-primary.local
<BOX_IP> pihole-secondary.local
```

Traefik routers MUST use `Host()` rules for these names.

### 4.3 Required validations (UI)

Codex MUST validate:

- [ ] Pi-hole UI loads through Traefik
- [ ] Admin login works (credentials are not in the repo)
- [ ] Persisted configuration survives container restart
- [ ] Persisted configuration survives host reboot

Do not proceed until this passes.

---

## 5. Secrets and Configuration Handling (MANDATORY)

Pi-hole requires sensitive configuration (e.g., admin password).

Codex MUST ensure:

- No secrets are committed
- Compose references external secret paths only

Allowed patterns:

- `env_file: /run/secrets/pihole.env`
- secret values injected via:
  - private overlay
  - runtime secret file
  - encrypted secret management (later)

Forbidden:

- Inline passwords in compose
- Dummy passwords in repo

---

## 6. NixOS Ownership: systemd-managed Compose

The `services/pihole/pihole.nix` module MUST:

- Ensure required directories exist via tmpfiles
- Deploy the compose file to a deterministic runtime location
- Create a systemd unit to run:
  - `docker compose up -d` on start
  - `docker compose down` on stop
- Depend on `docker.service` and `network-online.target`
- Use restart settings suitable for ARM64

Manual docker commands are forbidden.

---

## 7. Host Integration (Primary and Secondary)

### 7.1 Host-level enablement

Codex MUST enable Pi-hole by importing the module in the correct host files.

Primary host imports:

- base profile
- traefik service
- pihole service

Secondary host imports:

- base profile
- traefik service (if running locally on that box)
- pihole service

### 7.2 Role-specific values

Any role-specific values (primary vs secondary) MUST be:

- Non-secret
- Minimal
- Defined as module options or host variables

Examples:

- hostname
- UI hostname (`pihole-primary.local`)
- container name

Do not hardcode real domains.

---

## 8. DNS Activation Phase: Safe Cutover

### 8.1 Preconditions for DNS cutover

Before making Pi-hole the network DNS, Codex MUST verify:

- [ ] Port 53 is available and not conflicted (no other resolver binding 53)
- [ ] Pi-hole DNS service is responding locally
- [ ] Traefik continues to function after any resolver changes

### 8.2 Cutover procedure (operational, not code)

Codex MUST document (but NOT automate) the DNS cutover steps:

1. Configure router/DHCP to advertise two DNS servers:
   - Primary Pi-hole IP
   - Secondary Pi-hole IP
2. Reduce DNS TTLs if applicable (optional)
3. Roll out the DHCP change
4. Verify clients receive the new DNS settings

Codex MUST NOT commit router configuration.

### 8.3 Post-cutover validation

Codex MUST validate:

- [ ] Client DNS queries succeed using primary
- [ ] Client DNS queries succeed using secondary
- [ ] If primary is stopped, clients still resolve via secondary
- [ ] Pi-hole query log shows client activity

---

## 9. DNS-Based Naming Transition (Optional but Recommended)

Once Pi-hole is active, you may transition away from client `/etc/hosts`.

Codex MUST ensure:

- Traefik routing rules do not require host file changes
- Only DNS entries change

Two acceptable options:

1. Keep `.local` names and maintain them via local DNS
2. Introduce a private zone (e.g., `home.arpa`) later

Do not introduce public domains in this plan.

---

## 10. Failure Modes and Guardrails

### 10.1 Port 80/443 conflicts

If Pi-hole attempts to bind 80/443, the deployment is incorrect.

Fix:

- Remove host bindings for 80/443 from Pi-hole
- Route UI exclusively through Traefik

### 10.2 Port 53 conflicts

If another service binds port 53, Pi-hole DNS will not start.

Fix:

- Disable/adjust conflicting local resolvers
- Keep Pi-hole as the only 53 binder on that host

### 10.3 Boot race conditions

If Pi-hole fails to start after reboot, tighten systemd dependencies:

- `After=docker.service network-online.target`
- `Wants=network-online.target`

---

## 11. Deliverables (What Codex Must Produce)

Codex MUST produce:

- `services/pihole/docker-compose.yml` (no secrets)
- `services/pihole/pihole.nix` (systemd-managed compose)
- Host imports enabling Pi-hole on the chosen primary and secondary boxes
- Minimal documentation for:
  - pre-DNS UI testing via `/etc/hosts`
  - DNS cutover steps
  - post-cutover validation checklist

---

## 12. Summary: Mandatory Execution Order

1. Verify Traefik stability
2. Implement Pi-hole module + compose
3. Validate UI through Traefik (pre-DNS)
4. Validate persistence + reboots
5. Verify port 53 readiness
6. Perform DNS cutover (manual router change)
7. Validate primary/secondary failover
8. Transition naming from `/etc/hosts` to DNS (optional)

Codex MUST NOT skip steps.

