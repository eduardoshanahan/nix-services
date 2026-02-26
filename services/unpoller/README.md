# UniFi Poller (unpoller) Service Module

This module deploys [unpoller](https://github.com/unpoller/unpoller) as a Prometheus exporter using a checked-in Docker Compose file.

## Deployment model

- Compose file is versioned at `services/unpoller/docker-compose.yml`.
- NixOS injects runtime environment variables (container name, image/tag, network, listen address/port, timezone, controller URL/TLS mode).
- UniFi credentials are consumed from `services.unpollerCompose.secretFile` via Compose `env_file`.
- systemd runs `docker compose up -d` / `docker compose down`.
- Metrics are exposed on port `9130` (configurable host listen address/port).

## Exposed options

- `services.unpollerCompose.enable`
- `services.unpollerCompose.containerName`
- `services.unpollerCompose.network`
- `services.unpollerCompose.timezone`
- `services.unpollerCompose.listenAddress`
- `services.unpollerCompose.listenPort`
- `services.unpollerCompose.controller.url`
- `services.unpollerCompose.controller.verifySsl`
- `services.unpollerCompose.secretFile`
- `services.unpollerCompose.image.repository`
- `services.unpollerCompose.image.tag`
- `services.unpollerCompose.image.allowMutableTag`

## Runtime secret file contract

`services.unpollerCompose.secretFile` must point to a runtime-provisioned file (for example under `/run/secrets`) with:

```dotenv
UP_UNIFI_CONTROLLER_0_USER=unpoller
UP_UNIFI_CONTROLLER_0_PASS=<password>
```

## Image pinning strategy

- Default policy is pinned tags only.
- Default image is `ghcr.io/unpoller/unpoller:v2.16.0`.
- Mutable tags like `latest` are blocked unless
  `services.unpollerCompose.image.allowMutableTag = true`.

## Example

```nix
services.unpollerCompose = {
  enable = true;
  controller.url = "https://ucg-max.<homelab-domain>";
  controller.verifySsl = true;
  secretFile = "/run/secrets/unpoller.env";

  listenAddress = "0.0.0.0";
  listenPort = 9130;
};

services.prometheusCompose.scrape.unpollerTargets = [
  "rpi-box-02.internal.example:9130"
];
```
