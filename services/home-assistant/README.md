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

## Validation

- `systemctl status home-assistant`
- `docker ps --filter name=home-assistant`
- `curl -skI https://homeassistant.<domain>/`

## Notes

- This module uses bridge networking + Traefik routing for consistency with the
  existing service pattern in this repository.
- Some auto-discovery integrations in Home Assistant may work best with host
  networking or additional network configuration.
