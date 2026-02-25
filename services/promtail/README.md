# Promtail Service Module

This module deploys Promtail using a checked-in Docker Compose file.

## Deployment model

- Compose file is versioned at `services/promtail/docker-compose.yml`.
- NixOS injects runtime environment variables (container name, image, local ports, data dir).
- NixOS renders Promtail config at `/etc/promtail/config.yml`.
- systemd runs `docker compose up -d` / `docker compose down`.
- Promtail reads local journald logs and ships them to Loki.

## Exposed options

- `services.promtailCompose.enable`
- `services.promtailCompose.containerName`
- `services.promtailCompose.dataDir`
- `services.promtailCompose.lokiPushUrl`
- `services.promtailCompose.httpPort`
- `services.promtailCompose.journalMaxAge`
- `services.promtailCompose.syslog.enable`
- `services.promtailCompose.syslog.listenAddress`
- `services.promtailCompose.syslog.jobLabel`
- `services.promtailCompose.image.repository`
- `services.promtailCompose.image.tag`
- `services.promtailCompose.image.allowMutableTag`

## Example

```nix
services.promtailCompose = {
  enable = true;
  lokiPushUrl = "http://loki.hhlab.home.arpa:3100/loki/api/v1/push";
  syslog = {
    enable = true;
    listenAddress = "0.0.0.0:1514";
    jobLabel = "synology-file-activity";
  };
};
```
