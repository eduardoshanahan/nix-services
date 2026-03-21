# SNMP Exporter (Docker Compose)

Prometheus SNMP exporter for scraping network devices (for example Synology NAS) from a NixOS host.

## Module

- `services/snmp-exporter/snmp-exporter.nix`

## Compose Template

- `services/snmp-exporter/docker-compose.yml`

## Key options

- `services.snmpExporterCompose.enable`
- `services.snmpExporterCompose.listenAddress`
- `services.snmpExporterCompose.listenPort`
- `services.snmpExporterCompose.logLevel`
- `services.snmpExporterCompose.snmpV2Community`
- `services.snmpExporterCompose.configFile`
- `services.snmpExporterCompose.image.repository`
- `services.snmpExporterCompose.image.tag`
- `services.snmpExporterCompose.image.allowMutableTag`

## Example

```nix
services.snmpExporterCompose = {
  enable = true;
  listenAddress = "0.0.0.0";
  listenPort = 9116;
  snmpV2Community = "change-me-snmp-community";
  configFile = "/var/lib/snmp-exporter/snmp.yml";
};
```
