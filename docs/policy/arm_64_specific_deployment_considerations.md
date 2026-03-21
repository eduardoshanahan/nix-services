# ARM64-Specific Deployment Considerations

This document defines **mandatory ARM64-specific rules and safeguards** for deploying services (starting with Traefik) on Raspberry Pi devices running **aarch64 / ARM64 NixOS**.

It is **authoritative** and MUST be followed by **Codex / AI-assisted development**.

---

## 1. Target Architecture (Explicit)

All Raspberry Pi systems targeted by this repository are:

- Architecture: **aarch64-linux**
- CPU: ARMv8 (64-bit)
- OS: NixOS (ARM64)

Codex MUST assume **ARM64** unless explicitly told otherwise.

---

## 2. Docker Image Requirements (MANDATORY)

### 2.1 Multi-architecture images only

All Docker images used in this repository MUST:

- Support **linux/arm64**
- Be published as **multi-arch manifests**
- Come from official or well-maintained sources

Images that are `amd64`-only are forbidden.

---

### 2.2 Explicit version pinning

Codex MUST:

- Pin Docker images to explicit versions
- Avoid the `latest` tag

Example (allowed):

```yaml
image: traefik:v2.11
```

Example (forbidden):

```yaml
image: traefik:latest
```

This prevents silent architecture or behavior changes.

---

## 3. Resource Constraints and Stability

ARM64 Raspberry Pi systems may have limited RAM and I/O bandwidth.

### Required defaults

Services MUST:

- Use conservative log levels
- Disable verbose access logging by default
- Avoid unnecessary providers or plugins

Example Traefik flags:

```yaml
command:
  - "--log.level=INFO"
  - "--accesslog=false"
```

These settings may be relaxed later if needed.

---

## 4. Networking and Port Ownership

### 4.1 Port ownership rule (HARD REQUIREMENT)

Once Traefik is deployed:

- Traefik permanently owns **host ports 80 and 443**
- No other service may bind to these ports on the host

Other services MUST expose HTTP internally and be routed via Traefik.

---

### 4.2 Docker network isolation

Traefik MUST run on a dedicated Docker network.

Reasons:

- Predictable container discovery
- Reduced cross-service interference
- More reliable restarts on ARM systems

---

## 5. systemd + Docker Compose on ARM64

### 5.1 Docker binary path (MANDATORY)

On NixOS ARM64, Docker Compose is a plugin.

Codex MUST invoke Docker using the Nix-provided path:

```nix
${config.virtualisation.docker.package}/bin/docker compose up
```

Use of `/usr/bin/docker` or `$PATH` is forbidden.

---

### 5.2 Boot ordering requirements

Docker-based services MUST:

- Start after Docker is running
- Wait for networking to be online

Required systemd dependencies:

```nix
after = [ "docker.service" "network-online.target" ];
wants = [ "network-online.target" ];
```

This avoids race conditions common on ARM systems.

---

### 5.3 Restart behavior

Services MUST be resilient to transient failures.

Required settings:

```nix
Restart = "always";
RestartSec = "5s";
```

This prevents tight restart loops during network or I/O delays.

---

### 5.4 Working directory guarantees

Systemd services MUST NOT assume directories exist.

Codex MUST ensure required directories are created declaratively:

```nix
systemd.tmpfiles.rules = [
  "d /var/lib/traefik 0755 root root -"
];
```

Missing directories are a common failure mode on ARM.

---

## 6. Pre-DNS Testing on ARM64

### 6.1 Host-header-based routing

Before DNS exists:

- Routing relies on HTTP Host headers
- Access via raw IP without Host headers is NOT expected to work

Codex MUST NOT treat this as an error.

---

### 6.2 Optional health endpoints

To validate Traefik independently of backend services, enabling the following is RECOMMENDED:

```yaml
command:
  - "--ping=true"
```

This allows distinguishing platform issues from routing issues.

---

## 7. Validation Checklist (ARM64)

Before proceeding to additional services, Codex MUST verify:

- [ ] System reports `aarch64-linux`
- [ ] Docker runs without emulation
- [ ] Traefik image is ARM64-compatible
- [ ] Ports 80/443 are bound by Traefik only
- [ ] Service survives reboot
- [ ] No high CPU or memory churn at idle

Failure to meet these conditions must be addressed before continuing.

---

## 8. Summary

- ARM64 is the default and assumed architecture
- Multi-arch, pinned images only
- Conservative defaults for stability
- Strict systemd ordering and ownership
- Traefik is the permanent HTTP entrypoint

These rules ensure reliable operation on Raspberry Pi ARM64 systems and MUST be followed.
