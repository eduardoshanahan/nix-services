# Disaster Recovery Drill Checklist (Safe Restore Testing)

> **Operator-validated checklist**  
> This document defines a **repeatable disaster recovery drill** to safely test backups and restores **without risking live service availability**.
>
> Codex MUST NOT automate, infer, or execute any steps in this document.

This checklist validates that the **Backup & Restore Plan** actually works under realistic failure conditions.

It builds on:
- *Backup & Restore Plan (Volumes + Pi-hole State)*
- *Pi-hole Deployment Plan (Traefik + No-DNS → DNS Transition)*
- *Traefik-First Deployment Plan (Pre-DNS, Operator-Validated)*

---

## 0. Purpose of Disaster Recovery Drills

The goal of a disaster recovery (DR) drill is to answer one question:

> **Can we rebuild a box from scratch and recover state without surprises?**

This drill is:

- Safe (no impact to production DNS)
- Controlled (explicit stop points)
- Repeatable

---

## 1. Safety Rules (MANDATORY)

Before starting a drill, the operator MUST ensure:

- [ ] The drill is performed on a **non-primary box**, or
- [ ] The box is temporarily removed from active DNS (DHCP/router)

The drill MUST NOT:

- Interrupt primary DNS service
- Modify router/DHCP configuration permanently
- Overwrite the last known-good backup

If safety cannot be guaranteed, DO NOT proceed.

---

## 2. Drill Frequency (RECOMMENDED)

- Initial drill: after first successful backup
- Routine drill: every **3–6 months**
- Mandatory drill: after major architecture changes

Document the date and outcome of each drill.

---

## 3. Drill Preparation

### 3.1 Select drill target

Choose one:

- Secondary Pi-hole box (preferred)
- Spare Raspberry Pi
- Temporary SD card for an existing box

---

### 3.2 Required inputs

Ensure availability of:

- Latest backup set
- Services repository
- Foundation repo (`nix-pi`)
- Access to restore destination (disk/NAS)

---

## 4. Drill Scenario A — Full SD Card Loss

This simulates the most common real failure.

### Steps

1. Power off the target box
2. Remove or wipe the SD card
3. Flash a fresh NixOS image
4. Boot the box and confirm SSH access
5. Deploy services via the repo
6. **Do NOT restore data yet**

### Validation checkpoint

- [ ] System boots cleanly
- [ ] Traefik starts automatically
- [ ] Services start with empty state

If this fails, STOP — backup quality is irrelevant until this works.

---

## 5. Drill Scenario B — Data Restore

### Steps

1. Stop the target service (e.g. Pi-hole)
2. Restore backed-up directories to:
   - `/var/lib/<service-name>/`
3. Verify file ownership and permissions
4. Start the service

---

### Validation checkpoint (Pi-hole example)

- [ ] Pi-hole UI loads
- [ ] Blocklists and settings are present
- [ ] DNS queries resolve correctly
- [ ] Logs show expected activity

If validation fails, STOP and investigate.

---

## 6. Drill Scenario C — Reboot & Persistence

### Steps

1. Reboot the box
2. Allow all services to start

### Validation checkpoint

- [ ] Traefik is running
- [ ] Pi-hole is running
- [ ] Restored state is intact

---

## 7. Drill Scenario D — Failover Simulation (Optional)

If you have primary + secondary Pi-hole:

### Steps

1. Stop Pi-hole on the **primary** box
2. Temporarily point a test client to the secondary DNS

### Validation checkpoint

- [ ] DNS queries still succeed
- [ ] Secondary Pi-hole logs show activity

This step MUST NOT affect all clients.

---

## 8. Cleanup and Exit Criteria

After completing the drill:

- [ ] Restore normal DNS configuration
- [ ] Return secondary box to standby role
- [ ] Confirm primary services are unaffected

No configuration drift should remain.

---

## 9. Documentation (MANDATORY)

Record the following:

- Date of drill
- Scenario(s) executed
- Backup used
- Issues encountered
- Corrective actions needed

Keep this record outside the repository if it contains sensitive details.

---

## 10. Common Failure Patterns

- Missing volume paths
- Incorrect permissions after restore
- Docker network not recreated
- Traefik starting before restored services

Each failure should result in a **plan update**.

---

## 11. Success Criteria

A disaster recovery drill is considered successful if:

- A box can be rebuilt from scratch
- Service state is restored
- No production outage occurs
- No manual hacks are required

If any condition is not met, the system is **not DR-ready**.

---

## 12. Summary

- DR drills are mandatory, not optional
- Always test restores, not just backups
- Prefer secondary or isolated systems
- Fix the plan when drills reveal gaps

This checklist ensures your backups are trustworthy when you need them most.

