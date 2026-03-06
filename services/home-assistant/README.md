# Home Assistant Service Module

Docker Compose-backed Home Assistant deployment managed through a NixOS module.

## Purpose

- Runs Home Assistant as a container managed by systemd.
- Exposes Home Assistant behind Traefik using host/domain routing.
- Persists Home Assistant state in a configurable host directory.

## Module

- Option path: `services.homeAssistant`
- Entrypoint module: `services/home-assistant/home-assistant.nix`

## Minimal configuration

```nix
{
  services.homeAssistant = {
    enable = true;
    hostname = "homeassistant.<homelab-domain>";
    tls = true;
    dataDir = "/srv/prometheus/home-assistant";
    reverseProxy.trustedProxies = [ "172.18.0.0/16" ];
  };
}
```

## Key options

- `services.homeAssistant.hostname`: Traefik `Host()` rule.
- `services.homeAssistant.tls`: route on `websecure` with TLS when enabled.
- `services.homeAssistant.dataDir`: persistent host directory mounted at `/config`.
- `services.homeAssistant.image.repository`
- `services.homeAssistant.image.tag`
- `services.homeAssistant.image.allowMutableTag`
- `services.homeAssistant.reverseProxy.enable`
- `services.homeAssistant.reverseProxy.useXForwardedFor`
- `services.homeAssistant.reverseProxy.trustedProxies`
- `services.homeAssistant.recorder.dbUrlFile`

## Validation

- `systemctl status home-assistant`
- `docker ps --filter name=home-assistant`
- `curl -skI https://homeassistant.<domain>/`

## Notes

- This module uses bridge networking + Traefik routing for consistency with the
  existing service pattern in this repository.
- When `reverseProxy.enable = true`, the module manages a marked reverse-proxy
  block in `configuration.yaml` unless an un-managed `http:` block already
  exists.
- When `recorder.dbUrlFile` is set, the module manages a marked `recorder`
  block in `configuration.yaml` and injects `HOME_ASSISTANT_RECORDER_DB_URL`
  from a runtime secret env file.
- Some auto-discovery integrations in Home Assistant may work best with host
  networking or additional network configuration.
