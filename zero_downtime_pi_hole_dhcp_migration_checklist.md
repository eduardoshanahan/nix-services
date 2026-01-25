# Zero‑Downtime Pi‑hole DHCP Migration Checklist

This document describes a **safe, operator‑validated, zero‑downtime procedure** for migrating DHCP authority from an upstream router (e.g. UCG / ISP router) to **Pi‑hole**, as used in the `nix-services` architecture.

It is designed to be:

- Reproducible
- Low‑risk
- Reversible
- Suitable for a homelab or small LAN

No automation is assumed. All steps are intentionally explicit.

---

## Preconditions (MUST be true before starting)

Verify **all** of the following before proceeding.

### Infrastructure

- Pi‑hole host has a **stable IP address**
  - Either via DHCP reservation **or** static NixOS configuration
  - Example: `192.168.3.97`
- Pi‑hole is reachable from at least one other LAN machine
- Pi‑hole DNS resolution works:

```bash
dig @<pihole-ip> google.com
```

### Service state

- Pi‑hole container is healthy
- Web UI is accessible
- Firewall is enabled on the host
- Firewall allows:
  - UDP 53
  - TCP 53

### Router access

- You have admin access to the router / gateway
- You can enable and disable DHCP quickly

---

## Migration Strategy (High‑Level)

The migration relies on **ordered authority handoff**:

1. Pi‑hole DHCP is enabled first
2. Router DHCP is disabled second
3. Clients renew leases

At no point are two DHCP servers active simultaneously.

---

## Step‑by‑Step Migration

### Step 1 — Prepare Pi‑hole DHCP (NO activation yet)

In the Pi‑hole UI:

- Navigate to **Settings → DHCP**
- Configure:
  - DHCP range (e.g. `192.168.1.100 – 192.168.1.200`)
  - Router / gateway IP (e.g. `192.168.1.1`)
  - Lease time (default is fine)
- **Do NOT enable DHCP yet**
- Save settings

This stages configuration without affecting the network.

---

### Step 2 — Enable Pi‑hole DHCP

- Toggle **Enable DHCP server** in Pi‑hole
- Save

Pi‑hole is now *ready* to serve leases, but clients will not switch until they renew.

---

### Step 3 — Immediately Disable Router DHCP

On the router / gateway:

- Disable the DHCP server
- Apply / save configuration

⚠️ **Critical rule:**

> Never leave both DHCP servers enabled at the same time.

At this point:

- Existing clients keep their current leases
- New DHCP requests are handled by Pi‑hole

---

### Step 4 — Renew One Test Client

On a single test machine:

```bash
sudo dhclient -v
```

or disconnect/reconnect network.

Verify:

- Client receives an IP in the Pi‑hole DHCP range
- DNS server points to Pi‑hole
- Name resolution works

Check in Pi‑hole UI:

- Client appears under **DHCP Leases**
- Hostname is visible

---

### Step 5 — Gradual Client Renewal

Allow the rest of the network to migrate naturally:

- Existing leases expire
- Clients renew automatically
- No manual action required

Optional:

- Manually renew critical machines

---

## Post‑Migration Validation

Confirm the following:

- Router DHCP is **disabled**
- Pi‑hole DHCP is **enabled**
- New clients receive IPs from Pi‑hole
- Local hostnames resolve automatically
- No DHCP warnings in Pi‑hole logs

---

## Rollback Plan (Always Available)

If anything goes wrong:

1. Re‑enable DHCP on the router
2. Disable DHCP in Pi‑hole
3. Renew client leases if necessary

This fully restores the previous state.

---

## Notes on High Availability (Future)

This procedure assumes **single‑node DHCP**.

Future improvements may include:

- Secondary Pi‑hole
- DNS redundancy
- DHCP failover strategies

These are **out of scope** for initial migration and should be addressed only after stable operation.

---

## Summary

- DHCP authority requires a **stable infrastructure IP**, not DHCP itself
- Pi‑hole DHCP can be enabled without downtime
- Ordered handoff prevents outages
- Rollback is trivial

This checklist represents the **recommended and supported** migration path within the `nix-services` architecture.
