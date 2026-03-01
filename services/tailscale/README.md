# Tailscale Service Module

This module deploys Tailscale as a Docker Compose service managed by systemd.
It supports subnet routing for remote access to a home LAN.

## Deployment model

- Compose file is versioned at `services/tailscale/docker-compose.yml`.
- NixOS injects runtime environment variables (container name, hostname,
  state dir, socket path, image/tag, and tailscale flags).
- Optional auth key is consumed from
  `services.tailscaleCompose.authKeyFile` and converted to a runtime env file.
- systemd runs `docker compose up -d` / `docker compose down`.

## Exposed options

- `services.tailscaleCompose.enable`
- `services.tailscaleCompose.containerName`
- `services.tailscaleCompose.hostname`
- `services.tailscaleCompose.stateDir`
- `services.tailscaleCompose.socketPath`
- `services.tailscaleCompose.authKeyFile`
- `services.tailscaleCompose.advertiseRoutes`
- `services.tailscaleCompose.acceptRoutes`
- `services.tailscaleCompose.acceptDns`
- `services.tailscaleCompose.extraUpFlags`
- `services.tailscaleCompose.firewallMode`
- `services.tailscaleCompose.openFirewall`
- `services.tailscaleCompose.udpPort`
- `services.tailscaleCompose.enableIpForwarding`
- `services.tailscaleCompose.image.repository`
- `services.tailscaleCompose.image.tag`
- `services.tailscaleCompose.image.allowMutableTag`

## Runtime secret file contract

`services.tailscaleCompose.authKeyFile` must point to a runtime-provisioned
file containing a single-line auth key:

```text
tskey-auth-...
```

Leave it unset when the node is already authenticated and state is persisted
under `services.tailscaleCompose.stateDir`.

## Firewall backend note

If the Tailscale container is used as a subnet router and reports iptables
errors while the host uses an nftables-based firewall stack, set:

```nix
services.tailscaleCompose.firewallMode = "nftables";
```

This forces the container to use `TS_DEBUG_FIREWALL_MODE=nftables`, which can
fix cases where direct access to the subnet router works but forwarded traffic
to other LAN hosts times out.

## Image pinning strategy

- Default policy is pinned tags only.
- Default image is `tailscale/tailscale:v1.84.2`.
- Mutable tags like `latest` are blocked unless
  `services.tailscaleCompose.image.allowMutableTag = true`.

## Example

```nix
services.tailscaleCompose = {
  enable = true;
  hostname = "rpi-box-01";
  advertiseRoutes = [ "198.51.100.0/24" ];
  acceptRoutes = true;
  acceptDns = false;
  firewallMode = "nftables";
};
```
