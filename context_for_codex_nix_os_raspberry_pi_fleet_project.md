# Context for Codex – NixOS Raspberry Pi Fleet Project

This document is **context to share with Codex** so the conversation can continue seamlessly.

It describes the **current decisions, mental model, and target architecture**. Nothing here is speculative; these are **intentional choices**.

---

## 1. High-level goal

Build a **small fleet of Raspberry Pis** that:

- Run **NixOS**
- Are managed entirely from a **workstation**
- Use **Docker** to run applications (including AI workloads)
- Avoid imperative configuration on the devices
- Are reproducible, replaceable, and low-maintenance

---

## 2. Core principles (do not violate)

1. **Host is declarative**
   - NixOS manages the Pi OS, users, networking, Docker daemon, firewall

2. **Applications run in Docker**
   - Especially for AI / ML / vendor software
   - No attempt to Nixify complex AI stacks initially

3. **No snowflakes**
   - No manual SSH edits on Pis
   - No ad-hoc fixes

4. **Workstation is the control plane**
   - All configuration files are edited locally
   - Changes are applied remotely

5. **Git is source of truth**
   - Git tracks configuration
   - Git does NOT deploy
   - `nixos-rebuild` deploys

---

## 3. Bootstrap model for Raspberry Pis

### Initial install (once per Pi)

- Download official **NixOS SD card image** for Raspberry Pi (AArch64)
- Flash SD card
- Mount SD card on workstation
- Edit `/etc/nixos/configuration.nix` on the SD card to:
  - Enable DHCP
  - Enable SSH
  - Install SSH public key
- Boot Pi headless (Ethernet)

After this point:

- SD card is never touched again

---

## 4. Ongoing management model

All future changes:

```bash
nixos-rebuild switch \
  --target-host root@<pi-ip> \
  --flake .#<pi-name>
```

- Builds happen on the workstation
- Results are pushed to the Pi
- Activation is atomic
- Rollbacks are available

---

## 5. Multi-Pi structure

Single Git repository managing all Pis:

```text
pi-nixos/
├── flake.nix
├── modules/
│   ├── common.nix
│   ├── docker.nix
│   └── networking.nix
├── hosts/
│   ├── pi-1.nix
│   ├── pi-2.nix
│   └── pi-3.nix
```

- `modules/` = shared logic
- `hosts/` = per-Pi identity and roles

---

## 6. Docker usage model

- Docker daemon is enabled via NixOS
- Containers run application workloads
- Images are pulled from registries
- Docker Compose may be used per Pi

NixOS does **not** manage application internals.

---

## 7. Dev environment on the workstation

- Uses **Nix dev shells**
- Dev shells provide:
  - git
  - ansible (bootstrap only)
  - nix tooling
- Host system stays minimal

SSH keys:

- Live on the host
- Shared across dev shells via SSH agent

---

## 8. Ansible usage (important)

- Ansible is **bootstrap-only**
- Used only to:
  - Install Nix
  - Install NixOS on non-NixOS systems (e.g. VPS)

Once a machine runs NixOS:

- Ansible is not used again

---

## 9. Non-Nix software policy

If software is:

- Complex
- Binary-heavy
- GPU/CUDA-based
- Vendor-provided

→ **Run it in Docker**

Nix is used for:

- The host
- Tooling
- Reproducibility

---

## 10. Mental model to keep

- NixOS = system state
- Docker = workload runtime
- Git = history & truth
- Workstation = control plane
- Pis = declarative targets

---

## 11. What Codex should help with next

Codex can now help with:

- Writing NixOS modules for Docker
- Designing per-Pi roles
- Adding Docker Compose cleanly
- Secrets management for containers
- CI for building Docker images
- Scaling the same model to VPSes

---

## 12. Explicit non-goals (for now)

- Kubernetes
- Over-engineered orchestration
- Full Nix packaging of AI stacks
- Mutable configuration on devices

---

## End of context

This document represents the **current architectural agreement**.
Future decisions should align with it unless explicitly changed.
