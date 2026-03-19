# Alertmanager Service Module

This module deploys Alertmanager behind Traefik using a checked-in Docker Compose file.

## Deployment model

- Compose file is versioned at `services/alertmanager/docker-compose.yml`.
- NixOS injects runtime environment variables (container name, image/tag, network, hostname, TLS mode, timezone, data path).
- NixOS renders a config template at `/etc/alertmanager/alertmanager.yml.tmpl`.
- systemd renders runtime config at `/run/alertmanager/alertmanager.yml` (injecting secret values from runtime-provisioned files).
- systemd runs `docker compose up -d` / `docker compose down`.
- Data persists under `services.alertmanager.dataDir` (default `/var/lib/alertmanager`).

## Exposed options

- `services.alertmanager.enable`
- `services.alertmanager.containerName`
- `services.alertmanager.hostname`
- `services.alertmanager.timezone`
- `services.alertmanager.network`
- `services.alertmanager.dataDir`
- `services.alertmanager.image.repository`
- `services.alertmanager.image.tag`
- `services.alertmanager.image.allowMutableTag`
- `services.alertmanager.tls`
- `services.alertmanager.notifications.email.enable`
- `services.alertmanager.notifications.email.smarthost`
- `services.alertmanager.notifications.email.from`
- `services.alertmanager.notifications.email.to`
- `services.alertmanager.notifications.email.authUsername`
- `services.alertmanager.notifications.email.authPasswordFile`
- `services.alertmanager.notifications.email.requireTls`
- `services.alertmanager.notifications.telegram.enable`
- `services.alertmanager.notifications.telegram.botTokenFile`
- `services.alertmanager.notifications.telegram.chatId`
- `services.alertmanager.notifications.telegram.parseMode`

## Image pinning strategy

- Default policy is pinned tags only.
- Default image is `prom/alertmanager:v0.27.0`.
- Mutable tags like `latest` are blocked unless
  `services.alertmanager.image.allowMutableTag = true`.

## Host-side monitoring note

- Host-managed Uptime Kuma monitor policy for deployed Alertmanager checks is
  canonical in:
  - `../nix-pi/docs/policy/UPTIME_KUMA_MONITOR_POLICY.md`

## Example

```nix
services.alertmanager = {
  enable = true;
  hostname = "alertmanager.${config.lab.domain}";
  dataDir = "/var/lib/alertmanager";
  tls = true;

  notifications = {
    email = {
      enable = true;
      from = "homelab-alerts@example.com";
      to = "you@example.com";
      authUsername = "homelab-alerts@example.com";
      authPasswordFile = "/run/secrets/alertmanager-smtp-password";
    };
    telegram = {
      enable = true;
      botTokenFile = "/run/secrets/alertmanager-telegram-bot-token";
      chatId = 123456789;
    };
  };
};
```
