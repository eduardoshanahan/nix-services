# Reflash & Rejoin Node — Operator Runbook

This document describes the **authoritative, repeatable procedure** for reflashing a NixOS node and safely re‑joining it to a network where **Pi-hole provides DNS and DHCP**.

This runbook is designed for the `nix-services` / `nix-pi` architecture and assumes:

- Declarative NixOS configurations
- Operator‑validated bootstrap
- No reliance on ephemeral DHCP state after convergence

---

## Scope & Intent

This runbook applies when:

- An SD card is reflashed
- A node is rebuilt from scratch
- A node must rejoin the LAN cleanly

It explicitly separates:

- **Discovery phase** (temporary DHCP)
- **Convergence phase** (static, declarative state)

---

## Preconditions

Before starting, verify:

- Pi-hole is running and healthy
- Pi-hole DHCP is enabled on the target LAN
- Router DHCP is disabled for that LAN
- SSH keys for the operator user are baked into the image
- The target node has a known MAC address (optional but helpful)

---

## Phase 1 — Reflash

1. Power off the target node
2. Reflash the SD card with the desired NixOS image
3. Insert SD card and power the node on

At this point:

- The node has **no static IP**
- DHCP is enabled by default

---

## Phase 2 — Discovery via Pi-hole (Temporary DHCP)

1. Open the Pi-hole web UI
2. Navigate to:
   - **DHCP → DHCP Leases** or
   - **Tools → Network**
3. Identify the new node by:
   - MAC address
   - Default hostname (often `nixos` or similar)
4. Note the **temporarily assigned IP address**

This IP is **for discovery only**.

---

## Phase 3 — SSH Bootstrap

From the operator workstation:

```bash
ssh <user>@<temporary-ip>
```

Confirm:

- SSH access works
- You are on the expected node

---

## Phase 4 — Declarative Convergence

Run the standard deployment command:

```bash
nixos-rebuild switch \
  --flake path:.#<hostname> \
  --target-host <temporary-ip> \
  --build-host <temporary-ip> \
  --sudo
```

During activation:

- Static networking is applied (if configured)
- The node drops its DHCP lease
- Network restarts

This may temporarily disconnect the SSH session.

---

## Phase 5 — Reconnect on Final IP

After convergence:

1. Reconnect using the **final static IP**:

   ```bash
   ssh <user>@<final-ip>
   ```

2. Verify:

   - Hostname is correct
   - Services are running
   - Network is stable

---

## Phase 6 — Validation

Confirm in Pi-hole UI:

- Old DHCP lease has expired or disappeared
- Node now appears with:
  - Correct hostname
  - Correct (static) IP

Confirm locally:

```bash
ip addr
ip route
```

---

## Rollback & Recovery

If anything goes wrong:

- Recheck Pi-hole DHCP leases
- Re-enable router DHCP temporarily if needed
- Reflash and repeat the process

No state is permanently lost during this procedure.

---

## Operational Rules (Non‑Negotiable)

- DHCP is **only** used for discovery
- Infrastructure nodes must converge to static IPs
- Never depend on DHCP for long‑term reachability
- Always treat Pi-hole UI data as **observational**, not authoritative

---

## Summary

This procedure guarantees:

- Zero manual IP guessing
- Safe reflashing
- Deterministic convergence
- No hidden state

It represents the **supported and recommended** way to rejoin nodes in the `nix-services` architecture.
