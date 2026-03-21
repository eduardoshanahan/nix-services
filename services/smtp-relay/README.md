# SMTP Relay Service Module

This module deploys a shared SMTP relay using a checked-in Docker Compose file.

## Deployment model

- Compose file is versioned at `services/smtp-relay/docker-compose.yml`.
- NixOS injects runtime environment variables (container name, image/tag, listen address/port, hostname, upstream relay settings, sender-domain policy).
- systemd runs `docker compose up -d` / `docker compose down`.
- Upstream password is consumed from a runtime-provisioned secret file path.

## Exposed options

- `services.smtpRelayCompose.enable`
- `services.smtpRelayCompose.containerName`
- `services.smtpRelayCompose.hostname`
- `services.smtpRelayCompose.timezone`
- `services.smtpRelayCompose.listenAddress`
- `services.smtpRelayCompose.listenPort`
- `services.smtpRelayCompose.openFirewall`
- `services.smtpRelayCompose.upstream.host`
- `services.smtpRelayCompose.upstream.port`
- `services.smtpRelayCompose.upstream.username`
- `services.smtpRelayCompose.upstream.passwordFile`
- `services.smtpRelayCompose.allowedSenderDomains`
- `services.smtpRelayCompose.image.repository`
- `services.smtpRelayCompose.image.tag`
- `services.smtpRelayCompose.image.allowMutableTag`

## Runtime secret file contract

`services.smtpRelayCompose.upstream.passwordFile` must point to a runtime-provisioned file (for example `/run/secrets/smtp-relay-password`) containing only the upstream SMTP password on one line.

## Image pinning strategy

- Default policy is pinned tags only.
- Default image is `boky/postfix:4.4.0`.
- Mutable tags like `latest` are blocked unless
  `services.smtpRelayCompose.image.allowMutableTag = true`.

## Example

```nix
services.smtpRelayCompose = {
  enable = true;
  hostname = "smtp-relay.${config.lab.domain}";
  listenAddress = "0.0.0.0";
  listenPort = 2525;
  openFirewall = true;

  upstream.host = "smtp.gmail.com";
  upstream.port = 587;
  upstream.username = "alerts@example.com";
  upstream.passwordFile = "/run/secrets/smtp-relay-password";

  allowedSenderDomains = [ config.lab.domain ];
};
```
