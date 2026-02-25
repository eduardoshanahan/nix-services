{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.grafanaCompose;
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};
  runtimeSecretEnv = import ../../lib/runtime-secret-env.nix {inherit lib pkgs;};
  serviceName = "grafana";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
  backupScript = pkgs.writeShellScript "grafana-backup" ''
    set -euo pipefail

    src=${lib.escapeShellArg cfg.dataDir}
    dst=${lib.escapeShellArg cfg.backup.targetDir}
    keep_days=${toString cfg.backup.keepDays}

    if [[ ! -d "$src" ]]; then
      echo "grafana-backup: source directory not found: $src" >&2
      exit 1
    fi

    install -d -m 0750 "$dst"

    stamp="$(${pkgs.coreutils}/bin/date -u +%Y%m%dT%H%M%SZ)"
    archive="$dst/grafana-$stamp.tar.zst"

    ${pkgs.gnutar}/bin/tar \
      --use-compress-program="${pkgs.zstd}/bin/zstd -T0 -19" \
      -cf "$archive" \
      -C "$src" .

    ${pkgs.findutils}/bin/find "$dst" -maxdepth 1 -type f -name 'grafana-*.tar.zst' -mtime "+$keep_days" -delete
  '';
  datasourcesYaml =
    lib.concatStringsSep "\n" (
      [
        "apiVersion: 1"
        "datasources:"
        "  - name: Prometheus"
        "    uid: prometheus"
        "    type: prometheus"
        "    access: proxy"
        "    url: ${cfg.provisioning.datasources.prometheus.url}"
        "    isDefault: true"
        "    editable: false"
        "    jsonData:"
        "      timeInterval: 15s"
      ]
      ++ lib.optionals (cfg.provisioning.datasources.loki.url != null) [
        "  - name: Loki"
        "    uid: loki"
        "    type: loki"
        "    access: proxy"
        "    url: ${cfg.provisioning.datasources.loki.url}"
        "    editable: false"
      ]
    )
    + "\n";
  dashboardsProviderYaml = ''
    apiVersion: 1
    providers:
      - name: Homelab
        orgId: 1
        folder: Homelab
        type: file
        disableDeletion: false
        editable: true
        options:
          path: /etc/grafana/provisioning/dashboards
  '';
  starterDashboardJson = builtins.toJSON {
    id = null;
    uid = "homelab-overview";
    title = "Homelab Overview";
    tags = [ "homelab" "starter" ];
    timezone = "browser";
    schemaVersion = 39;
    version = 1;
    refresh = "30s";
    time = {
      from = "now-6h";
      to = "now";
    };
    editable = true;
    panels = [
      {
        id = 1;
        type = "stat";
        title = "Targets Up";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 0;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          justifyMode = "auto";
          orientation = "auto";
          reduceOptions = {
            calcs = [ "lastNotNull" ];
            fields = "";
            values = false;
          };
          textMode = "auto";
        };
        targets = [
          {
            expr = "sum(up)";
            refId = "A";
          }
        ];
      }
      {
        id = 5;
        type = "stat";
        title = "Node Targets Up";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 4;
          x = 4;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          justifyMode = "auto";
          orientation = "auto";
          reduceOptions = {
            calcs = [ "lastNotNull" ];
            fields = "";
            values = false;
          };
          textMode = "auto";
        };
        targets = [
          {
            expr = "sum(up{job=\"nodes\"})";
            refId = "A";
          }
        ];
      }
      {
        id = 6;
        type = "stat";
        title = "Promtail Targets Up";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 4;
          x = 8;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          justifyMode = "auto";
          orientation = "auto";
          reduceOptions = {
            calcs = [ "lastNotNull" ];
            fields = "";
            values = false;
          };
          textMode = "auto";
        };
        targets = [
          {
            expr = "sum(up{job=\"promtail\"})";
            refId = "A";
          }
        ];
      }
      {
        id = 2;
        type = "timeseries";
        title = "HTTP 5xx Rate (Traefik)";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 8;
          x = 16;
          y = 0;
        };
        targets = [
          {
            expr = "sum(rate(traefik_service_requests_total{code=~\"5..\"}[5m])) by (instance, code)";
            legendFormat = "{{instance}} {{code}}";
            refId = "A";
          }
        ];
      }
      {
        id = 11;
        type = "stat";
        title = "Gitea Targets Up";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 4;
          x = 12;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          justifyMode = "auto";
          orientation = "auto";
          reduceOptions = {
            calcs = [ "lastNotNull" ];
            fields = "";
            values = false;
          };
          textMode = "auto";
        };
        targets = [
          {
            expr = "sum(up{job=\"gitea\"})";
            refId = "A";
          }
        ];
      }
      {
        id = 3;
        type = "timeseries";
        title = "CPU Usage % (Nodes)";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 6;
        };
        targets = [
          {
            expr = "(100 - (avg by (instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)) or (100 - avg by (instance) (ssCpuIdle{job=\"synology-snmp-system\"}))";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
      }
      {
        id = 4;
        type = "timeseries";
        title = "Memory Available % (Nodes)";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 6;
        };
        targets = [
          {
            expr = "((node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100) or (100 * (memAvailReal{job=\"synology-snmp-memory\"} / memTotalReal{job=\"synology-snmp-memory\"}))";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
      }
      {
        id = 7;
        type = "timeseries";
        title = "Root Disk Used % (Nodes)";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 14;
        };
        targets = [
          {
            expr = "(100 * (1 - (node_filesystem_avail_bytes{mountpoint=\"/\",fstype!~\"tmpfs|overlay\"} / node_filesystem_size_bytes{mountpoint=\"/\",fstype!~\"tmpfs|overlay\"}))) or (100 * (hrStorageUsed{job=\"synology-snmp-storage\",hrStorageDescr=\"/volume1\"} / hrStorageSize{job=\"synology-snmp-storage\",hrStorageDescr=\"/volume1\"}))";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
      }
      {
        id = 8;
        type = "timeseries";
        title = "Node Temperature C";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 14;
        };
        targets = [
          {
            expr = "max by (instance) (node_hwmon_temp_celsius)";
            legendFormat = "{{instance}} hwmon";
            refId = "A";
          }
          {
            expr = "max by (instance) (temperature{job=\"synology-snmp\"})";
            legendFormat = "{{instance}} system";
            refId = "B";
          }
          {
            expr = "max by (instance) (diskTemperature{job=\"synology-snmp\"})";
            legendFormat = "{{instance}} disk";
            refId = "C";
          }
        ];
      }
      {
        id = 9;
        type = "timeseries";
        title = "Promtail Processed Lines/s";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 24;
          x = 0;
          y = 22;
        };
        targets = [
          {
            expr = "sum by (instance) (rate(promtail_journal_target_lines_total[5m]) or rate(promtail_syslog_target_entries_total[5m]))";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
      }
      {
        id = 10;
        type = "timeseries";
        title = "HTTP 5xx by Service (Traefik)";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 24;
          x = 0;
          y = 30;
        };
        targets = [
          {
            expr = "sum by (instance, service, code) (rate(traefik_service_requests_total{code=~\"5..\"}[5m]))";
            legendFormat = "{{instance}} {{service}} {{code}}";
            refId = "A";
          }
        ];
      }
    ];
  };
  nodesDetailDashboardJson = builtins.toJSON {
    id = null;
    uid = "nodes-detail";
    title = "Nodes Detail";
    tags = [ "homelab" "nodes" ];
    timezone = "browser";
    schemaVersion = 39;
    version = 1;
    refresh = "30s";
    time = {
      from = "now-6h";
      to = "now";
    };
    editable = true;
    panels = [
      {
        id = 1;
        type = "timeseries";
        title = "CPU Usage %";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 0;
        };
        targets = [
          {
            expr = "(100 - (avg by (instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)) or (100 - avg by (instance) (ssCpuIdle{job=\"synology-snmp-system\"}))";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
      }
      {
        id = 2;
        type = "timeseries";
        title = "Memory Available %";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 0;
        };
        targets = [
          {
            expr = "((node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100) or (100 * (memAvailReal{job=\"synology-snmp-memory\"} / memTotalReal{job=\"synology-snmp-memory\"}))";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
      }
      {
        id = 3;
        type = "timeseries";
        title = "Root Disk Used %";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 8;
        };
        targets = [
          {
            expr = "(100 * (1 - (node_filesystem_avail_bytes{mountpoint=\"/\",fstype!~\"tmpfs|overlay\"} / node_filesystem_size_bytes{mountpoint=\"/\",fstype!~\"tmpfs|overlay\"}))) or (100 * (hrStorageUsed{job=\"synology-snmp-storage\",hrStorageDescr=\"/volume1\"} / hrStorageSize{job=\"synology-snmp-storage\",hrStorageDescr=\"/volume1\"}))";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
      }
      {
        id = 4;
        type = "timeseries";
        title = "Load Average (1m)";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 8;
        };
        targets = [
          {
            expr = "node_load1 or laLoadFloat{job=\"synology-snmp-load\",laNames=\"Load-1\"}";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
      }
      {
        id = 5;
        type = "timeseries";
        title = "Node Temperature C";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 16;
        };
        targets = [
          {
            expr = "max by (instance) (node_hwmon_temp_celsius)";
            legendFormat = "{{instance}} hwmon";
            refId = "A";
          }
          {
            expr = "max by (instance) (temperature{job=\"synology-snmp\"})";
            legendFormat = "{{instance}} system";
            refId = "B";
          }
          {
            expr = "max by (instance) (diskTemperature{job=\"synology-snmp\"})";
            legendFormat = "{{instance}} disk";
            refId = "C";
          }
        ];
      }
      {
        id = 6;
        type = "timeseries";
        title = "Uptime (hours)";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 16;
        };
        targets = [
          {
            expr = "((node_time_seconds - node_boot_time_seconds) / 3600) or ((hrSystemUptime{job=\"synology-snmp-uptime\"} / 100) / 3600)";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
        fieldConfig = {
          defaults = {
            unit = "h";
          };
          overrides = [ ];
        };
      }
      {
        id = 7;
        type = "timeseries";
        title = "Network Receive Bytes/s";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 24;
        };
        targets = [
          {
            expr = "(sum by (instance) (rate(node_network_receive_bytes_total{device!=\"lo\"}[5m]))) or (sum by (instance) (rate(ifHCInOctets{job=\"synology-snmp-network\",ifName!~\"lo|sit0\"}[5m])))";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
      }
      {
        id = 8;
        type = "timeseries";
        title = "Network Transmit Bytes/s";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 24;
        };
        targets = [
          {
            expr = "(sum by (instance) (rate(node_network_transmit_bytes_total{device!=\"lo\"}[5m]))) or (sum by (instance) (rate(ifHCOutOctets{job=\"synology-snmp-network\",ifName!~\"lo|sit0\"}[5m])))";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
      }
      {
        id = 9;
        type = "timeseries";
        title = "Pi Storage Used % (rpi-box-02/03)";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 32;
        };
        targets = [
          {
            expr = "100 * (1 - (node_filesystem_avail_bytes{instance=~\"rpi-box-0[23].*\",mountpoint=\"/\",fstype!~\"tmpfs|overlay\"} / node_filesystem_size_bytes{instance=~\"rpi-box-0[23].*\",mountpoint=\"/\",fstype!~\"tmpfs|overlay\"}))";
            legendFormat = "{{instance}} /";
            refId = "A";
          }
        ];
      }
      {
        id = 10;
        type = "timeseries";
        title = "Pi Disk IO by Device (rpi-box-02/03)";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 32;
        };
        targets = [
          {
            expr = "sum by (instance, device) (rate(node_disk_read_bytes_total{instance=~\"rpi-box-0[23].*\",device!~\"loop.*|ram.*|zram.*|dm-.*|md.*\"}[5m]))";
            legendFormat = "{{instance}} {{device}} read";
            refId = "A";
          }
          {
            expr = "sum by (instance, device) (rate(node_disk_written_bytes_total{instance=~\"rpi-box-0[23].*\",device!~\"loop.*|ram.*|zram.*|dm-.*|md.*\"}[5m]))";
            legendFormat = "{{instance}} {{device}} write";
            refId = "B";
          }
        ];
      }
    ];
  };
  dnsEdgeDashboardJson = builtins.toJSON {
    id = null;
    uid = "dns-edge";
    title = "DNS & Edge";
    tags = [ "homelab" "dns" "edge" ];
    timezone = "browser";
    schemaVersion = 39;
    version = 1;
    refresh = "30s";
    time = {
      from = "now-6h";
      to = "now";
    };
    editable = true;
    panels = [
      {
        id = 1;
        type = "stat";
        title = "Traefik Targets Up";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 5;
          w = 6;
          x = 0;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = [ "lastNotNull" ];
            fields = "";
            values = false;
          };
        };
        targets = [
          {
            expr = "sum(up{job=\"traefik\"})";
            refId = "A";
          }
        ];
      }
      {
        id = 2;
        type = "stat";
        title = "Pi-hole Exporter Targets Up";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 5;
          w = 6;
          x = 6;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = [ "lastNotNull" ];
            fields = "";
            values = false;
          };
        };
        targets = [
          {
            expr = "sum(up{job=\"pihole-exporter\"})";
            refId = "A";
          }
        ];
      }
      {
        id = 3;
        type = "stat";
        title = "Promtail Targets Up";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 5;
          w = 6;
          x = 12;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = [ "lastNotNull" ];
            fields = "";
            values = false;
          };
        };
        targets = [
          {
            expr = "sum(up{job=\"promtail\"})";
            refId = "A";
          }
        ];
      }
      {
        id = 4;
        type = "stat";
        title = "Blocked Domains";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 5;
          w = 6;
          x = 18;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = [ "lastNotNull" ];
            fields = "";
            values = false;
          };
        };
        targets = [
          {
            expr = "sum(pihole_domains_being_blocked)";
            refId = "A";
          }
        ];
      }
      {
        id = 5;
        type = "timeseries";
        title = "Traefik Request Rate (req/s)";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 5;
        };
        targets = [
          {
            expr = "sum by (instance) (rate(traefik_service_requests_total[5m]))";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
      }
      {
        id = 6;
        type = "timeseries";
        title = "Traefik 5xx Rate (req/s)";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 5;
        };
        targets = [
          {
            expr = "sum by (instance) (rate(traefik_service_requests_total{code=~\"5..\"}[5m]))";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
      }
      {
        id = 7;
        type = "timeseries";
        title = "Pi-hole Queries Today";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 8;
          x = 0;
          y = 13;
        };
        targets = [
          {
            expr = "sum by (instance) (pihole_dns_queries_today)";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
      }
      {
        id = 8;
        type = "timeseries";
        title = "Pi-hole Ads Blocked Today";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 8;
          x = 8;
          y = 13;
        };
        targets = [
          {
            expr = "sum by (instance) (pihole_ads_blocked_today)";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
      }
      {
        id = 9;
        type = "timeseries";
        title = "Pi-hole Ads Blocked %";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 8;
          x = 16;
          y = 13;
        };
        targets = [
          {
            expr = "avg by (instance) (pihole_ads_percentage_today)";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
      }
      {
        id = 10;
        type = "timeseries";
        title = "Promtail Processed Lines/s";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 24;
          x = 0;
          y = 21;
        };
        targets = [
          {
            expr = "sum by (instance) (rate(promtail_journal_target_lines_total[5m]) or rate(promtail_syslog_target_entries_total[5m]))";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
      }
      {
        id = 11;
        type = "timeseries";
        title = "Gitea Metrics Endpoint Rate (req/s)";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 24;
          x = 0;
          y = 29;
        };
        targets = [
          {
            expr = "sum by (instance) (rate(promhttp_metric_handler_requests_total{job=\"gitea\"}[5m]))";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
      }
    ];
  };
  nasDetailDashboardJson = builtins.toJSON {
    id = null;
    uid = "nas-detail";
    title = "NAS Detail";
    tags = [ "homelab" "nas" "synology" ];
    timezone = "browser";
    schemaVersion = 39;
    version = 1;
    refresh = "30s";
    time = {
      from = "now-6h";
      to = "now";
    };
    editable = true;
    panels = [
      {
        id = 1;
        type = "stat";
        title = "Synology Targets Up (Node + SNMP)";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 5;
          w = 6;
          x = 0;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = [ "lastNotNull" ];
            fields = "";
            values = false;
          };
        };
        targets = [
          {
            expr = "sum(max by (instance) (up{job=~\"synology-nodes|synology-snmp\"}))";
            refId = "A";
          }
        ];
      }
      {
        id = 2;
        type = "timeseries";
        title = "NAS CPU Usage %";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 9;
          x = 6;
          y = 0;
        };
        targets = [
          {
            expr = "(100 - (avg by (instance) (rate(node_cpu_seconds_total{job=\"synology-nodes\",mode=\"idle\"}[5m])) * 100)) or (100 - avg by (instance) (ssCpuIdle{job=\"synology-snmp-system\"}))";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
      }
      {
        id = 3;
        type = "timeseries";
        title = "NAS Memory Available %";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 9;
          x = 15;
          y = 0;
        };
        targets = [
          {
            expr = "((node_memory_MemAvailable_bytes{job=\"synology-nodes\"} / node_memory_MemTotal_bytes{job=\"synology-nodes\"}) * 100) or (100 * (memAvailReal{job=\"synology-snmp-memory\"} / memTotalReal{job=\"synology-snmp-memory\"}))";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
      }
      {
        id = 4;
        type = "timeseries";
        title = "NAS Root Disk Used %";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 8;
        };
        targets = [
          {
            expr = "(100 * (1 - (node_filesystem_avail_bytes{job=\"synology-nodes\",mountpoint=\"/\",fstype!~\"tmpfs|overlay\"} / node_filesystem_size_bytes{job=\"synology-nodes\",mountpoint=\"/\",fstype!~\"tmpfs|overlay\"}))) or (100 * (hrStorageUsed{job=\"synology-snmp-storage\",hrStorageDescr=\"/volume1\"} / hrStorageSize{job=\"synology-snmp-storage\",hrStorageDescr=\"/volume1\"}))";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
      }
      {
        id = 5;
        type = "timeseries";
        title = "NAS Disk IO (Bytes/s)";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 8;
        };
        targets = [
          {
            expr = "sum by (instance) (rate(node_disk_read_bytes_total{job=\"synology-nodes\"}[5m]))";
            legendFormat = "{{instance}} read";
            refId = "A";
          }
          {
            expr = "sum by (instance) (rate(node_disk_written_bytes_total{job=\"synology-nodes\"}[5m]))";
            legendFormat = "{{instance}} write";
            refId = "B";
          }
          {
            expr = "sum by (instance) (rate(storageIONReadX{job=\"synology-snmp\"}[5m]))";
            legendFormat = "{{instance}} read (snmp)";
            refId = "C";
          }
          {
            expr = "sum by (instance) (rate(storageIONWrittenX{job=\"synology-snmp\"}[5m]))";
            legendFormat = "{{instance}} write (snmp)";
            refId = "D";
          }
        ];
      }
      {
        id = 6;
        type = "timeseries";
        title = "NAS Network Throughput (Bytes/s)";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 16;
        };
        targets = [
          {
            expr = "sum by (instance) (rate(node_network_receive_bytes_total{job=\"synology-nodes\",device!=\"lo\"}[5m]))";
            legendFormat = "{{instance}} rx";
            refId = "A";
          }
          {
            expr = "sum by (instance) (rate(node_network_transmit_bytes_total{job=\"synology-nodes\",device!=\"lo\"}[5m]))";
            legendFormat = "{{instance}} tx";
            refId = "B";
          }
          {
            expr = "sum by (instance) (rate(ifHCInOctets{job=\"synology-snmp-network\",ifName!~\"lo|sit0\"}[5m]))";
            legendFormat = "{{instance}} rx (snmp)";
            refId = "C";
          }
          {
            expr = "sum by (instance) (rate(ifHCOutOctets{job=\"synology-snmp-network\",ifName!~\"lo|sit0\"}[5m]))";
            legendFormat = "{{instance}} tx (snmp)";
            refId = "D";
          }
        ];
      }
      {
        id = 7;
        type = "timeseries";
        title = "NAS Temperature C";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 16;
        };
        targets = [
          {
            expr = "max by (instance) (node_hwmon_temp_celsius{job=\"synology-nodes\"})";
            legendFormat = "{{instance}} hwmon";
            refId = "A";
          }
          {
            expr = "max by (instance) (temperature{job=\"synology-snmp\"})";
            legendFormat = "{{instance}} system";
            refId = "B";
          }
          {
            expr = "max by (instance) (diskTemperature{job=\"synology-snmp\"})";
            legendFormat = "{{instance}} disk";
            refId = "C";
          }
        ];
      }
    ];
  };
  nasFileActivityDashboardJson = builtins.toJSON {
    id = null;
    uid = "nas-file-activity";
    title = "NAS File Activity";
    tags = [ "homelab" "nas" "logs" "loki" ];
    timezone = "browser";
    schemaVersion = 39;
    version = 1;
    refresh = "30s";
    time = {
      from = "now-6h";
      to = "now";
    };
    editable = true;
    panels = [
      {
        id = 1;
        type = "logs";
        title = "DSM File Activity (Raw)";
        datasource = {
          type = "loki";
          uid = "loki";
        };
        gridPos = {
          h = 12;
          w = 24;
          x = 0;
          y = 0;
        };
        options = {
          showCommonLabels = false;
          showLabels = true;
          showTime = true;
          sortOrder = "Descending";
        };
        targets = [
          {
            expr = "{job=\"synology-file-activity\"}";
            refId = "A";
          }
        ];
      }
      {
        id = 2;
        type = "timeseries";
        title = "File Activity Events/s";
        datasource = {
          type = "loki";
          uid = "loki";
        };
        gridPos = {
          h = 8;
          w = 24;
          x = 0;
          y = 12;
        };
        targets = [
          {
            expr = "(sum by (host) (rate({job=\"synology-file-activity\"}[5m]))) or on() vector(0)";
            legendFormat = "{{host}}";
            refId = "A";
          }
        ];
      }
      {
        id = 3;
        type = "stat";
        title = "Events (Last 1h)";
        datasource = {
          type = "loki";
          uid = "loki";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 0;
          y = 20;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = [ "lastNotNull" ];
            fields = "";
            values = false;
          };
        };
        targets = [
          {
            expr = "sum(count_over_time({job=\"synology-file-activity\"}[1h])) or on() vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 4;
        type = "timeseries";
        title = "Auth/Permission Failures (events/s)";
        datasource = {
          type = "loki";
          uid = "loki";
        };
        gridPos = {
          h = 6;
          w = 18;
          x = 6;
          y = 20;
        };
        targets = [
          {
            expr = "sum by (host) (rate({job=\"synology-file-activity\"} |~ \"(?i)(fail|denied|unauthorized|permission)\"[5m]))";
            legendFormat = "{{host}}";
            refId = "A";
          }
        ];
      }
      {
        id = 5;
        type = "timeseries";
        title = "File Change Activity (events/s)";
        datasource = {
          type = "loki";
          uid = "loki";
        };
        gridPos = {
          h = 8;
          w = 16;
          x = 0;
          y = 26;
        };
        targets = [
          {
            expr = "sum by (host) (rate({job=\"synology-file-activity\"} |~ \"(?i)(create|delete|rename|write|modify|moved|copied)\"[5m]))";
            legendFormat = "{{host}}";
            refId = "A";
          }
        ];
      }
      {
        id = 6;
        type = "bargauge";
        title = "Top Noisy Hosts (15m)";
        datasource = {
          type = "loki";
          uid = "loki";
        };
        gridPos = {
          h = 8;
          w = 8;
          x = 16;
          y = 26;
        };
        options = {
          orientation = "horizontal";
          reduceOptions = {
            calcs = [ "lastNotNull" ];
            fields = "";
            values = false;
          };
          showUnfilled = true;
        };
        targets = [
          {
            expr = "topk(10, sum by (host) (count_over_time({job=\"synology-file-activity\"}[15m])))";
            legendFormat = "{{host}}";
            refId = "A";
          }
        ];
      }
      {
        id = 7;
        type = "logs";
        title = "Gitea Container Logs (Raw)";
        datasource = {
          type = "loki";
          uid = "loki";
        };
        gridPos = {
          h = 10;
          w = 24;
          x = 0;
          y = 34;
        };
        options = {
          showCommonLabels = false;
          showLabels = true;
          showTime = true;
          sortOrder = "Descending";
        };
        targets = [
          {
            expr = "{job=\"synology-gitea\"}";
            refId = "A";
          }
        ];
      }
    ];
  };
  healthcheckScript = pkgs.writeShellScript "grafana-healthcheck" ''
    set -euo pipefail

    service_name=${serviceName}
    container_name=${cfg.containerName}

    if ! systemctl is-active --quiet "$service_name"; then
      echo "grafana-healthcheck: systemd service $service_name is not active" >&2
      exit 1
    fi

    status="$(${dockerBin} inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_name" 2>/dev/null || true)"
    if [ "$status" != "healthy" ]; then
      echo "grafana-healthcheck: container health is '$status' (expected 'healthy')" >&2
      ${dockerBin} ps --filter "name=^/$container_name$" --format 'table {{.Names}}\t{{.Status}}' >&2 || true
      exit 1
    fi
  '';

  waitForHealthy = pkgs.writeShellScript "grafana-wait-healthy" ''
    set -euo pipefail

    container_name=${cfg.containerName}
    timeout_seconds=120
    deadline=$((SECONDS + timeout_seconds))

    while true; do
      status="$(${dockerBin} inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_name" 2>/dev/null || true)"

      case "$status" in
        healthy)
          exit 0
          ;;
        unhealthy)
          echo "grafana: container became unhealthy" >&2
          ${dockerBin} ps --filter "name=^/$container_name$" --format 'table {{.Names}}\t{{.Status}}' >&2 || true
          exit 1
          ;;
        starting|none|"")
          ;;
        *)
          echo "grafana: unexpected health status: $status" >&2
          ;;
      esac

      if [ "$SECONDS" -ge "$deadline" ]; then
        echo "grafana: timed out waiting for a healthy container (''${timeout_seconds}s)" >&2
        ${dockerBin} ps --filter "name=^/$container_name$" --format 'table {{.Names}}\t{{.Status}}' >&2 || true
        exit 1
      fi

      sleep 2
    done
  '';
in {
  options.services.grafanaCompose = {
    enable = lib.mkEnableOption "Grafana service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "grafana";
      description = "Docker container name.";
    };

    hostname = lib.mkOption {
      type = lib.types.str;
      description = "Hostname used for the Traefik router `Host()` rule.";
    };

    timezone = lib.mkOption {
      type = lib.types.str;
      default = "UTC";
      description = "Timezone passed to the container via `TZ`.";
    };

    network = lib.mkOption {
      type = lib.types.str;
      default = "traefik";
      description = "External Docker network name used by Traefik and downstream services.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/grafana";
      description = "Persistent host path used for Grafana data.";
    };

    adminPasswordFile = runtimeSecrets.mkSecretFileOption {
      description = ''
        Absolute path to a runtime-provisioned file containing the Grafana admin password.
      '';
      example = "/run/secrets/grafana-admin-password";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "grafana/grafana";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "11.2.0";
        description = "Container image tag.";
      };

      allowMutableTag = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Allow mutable tags such as `latest`. Keep disabled to enforce pinned
          image tags by default.
        '';
      };
    };

    tls = lib.mkEnableOption "TLS on the Grafana Traefik router";

    monitoring = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable periodic service/container health checks via systemd timer.";
      };

      interval = lib.mkOption {
        type = lib.types.str;
        default = "5m";
        description = "How often to run the Grafana healthcheck (for example `5m`).";
      };
    };

    backup = {
      enable = lib.mkEnableOption "periodic Grafana data backups";

      targetDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/backups/grafana";
        description = "Directory where compressed Grafana backup archives are written.";
      };

      schedule = lib.mkOption {
        type = lib.types.str;
        default = "daily";
        description = "Systemd OnCalendar expression for Grafana backups.";
      };

      keepDays = lib.mkOption {
        type = lib.types.ints.positive;
        default = 14;
        description = "How many days of backup archives to keep.";
      };
    };

    provisioning = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable declarative provisioning for Grafana datasources and starter dashboards.";
      };

      datasources = {
        prometheus = {
          url = lib.mkOption {
            type = lib.types.str;
            default = "http://prometheus:9090";
            description = "Prometheus URL used by provisioned Grafana datasource.";
          };
        };

        loki = {
          url = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "http://loki.internal.example:3100";
            description = "Optional Loki URL for a provisioned Grafana datasource.";
          };
        };
      };

      dashboards = {
        enableStarter = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Provision a starter Homelab overview dashboard.";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.grafanaCompose.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.grafanaCompose.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.grafanaCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.grafanaCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.grafanaCompose.image.tag must be pinned (not `latest`) unless services.grafanaCompose.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.grafanaCompose.dataDir must be an absolute path.";
      }
      {
        assertion = cfg.adminPasswordFile != null;
        message = "services.grafanaCompose.adminPasswordFile must be set when enabling Grafana.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.backup.targetDir;
        message = "services.grafanaCompose.backup.targetDir must be an absolute path.";
      }
      {
        assertion = !cfg.backup.enable || (!lib.hasPrefix "${cfg.dataDir}/" cfg.backup.targetDir && cfg.backup.targetDir != cfg.dataDir);
        message = "services.grafanaCompose.backup.targetDir must not be inside services.grafanaCompose.dataDir.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;
    environment.etc."${serviceName}/provisioning/datasources/datasources.yml" = lib.mkIf cfg.provisioning.enable {
      text = datasourcesYaml;
      mode = "0444";
    };
    environment.etc."${serviceName}/provisioning/dashboards/providers.yml" = lib.mkIf cfg.provisioning.enable {
      text = dashboardsProviderYaml;
      mode = "0444";
    };
    environment.etc."${serviceName}/provisioning/dashboards/homelab-overview.json" = lib.mkIf (cfg.provisioning.enable && cfg.provisioning.dashboards.enableStarter) {
      text = starterDashboardJson;
      mode = "0444";
    };
    environment.etc."${serviceName}/provisioning/dashboards/nodes-detail.json" = lib.mkIf (cfg.provisioning.enable && cfg.provisioning.dashboards.enableStarter) {
      text = nodesDetailDashboardJson;
      mode = "0444";
    };
    environment.etc."${serviceName}/provisioning/dashboards/dns-edge.json" = lib.mkIf (cfg.provisioning.enable && cfg.provisioning.dashboards.enableStarter) {
      text = dnsEdgeDashboardJson;
      mode = "0444";
    };
    environment.etc."${serviceName}/provisioning/dashboards/nas-detail.json" = lib.mkIf (cfg.provisioning.enable && cfg.provisioning.dashboards.enableStarter) {
      text = nasDetailDashboardJson;
      mode = "0444";
    };
    environment.etc."${serviceName}/provisioning/dashboards/nas-file-activity.json" = lib.mkIf (cfg.provisioning.enable && cfg.provisioning.dashboards.enableStarter && cfg.provisioning.datasources.loki.url != null) {
      text = nasFileActivityDashboardJson;
      mode = "0444";
    };

    systemd.services.${serviceName} = {
      description = "Grafana (Docker Compose)";

      wantedBy = ["multi-user.target"];
      requires = ["docker.service"];
      after = ["docker.service" "network-online.target"];
      wants = ["network-online.target"];
      restartTriggers = lib.optionals cfg.provisioning.enable [
        config.environment.etc."${serviceName}/provisioning/datasources/datasources.yml".source
        config.environment.etc."${serviceName}/provisioning/dashboards/providers.yml".source
      ] ++ lib.optionals (cfg.provisioning.enable && cfg.provisioning.dashboards.enableStarter) [
        config.environment.etc."${serviceName}/provisioning/dashboards/homelab-overview.json".source
        config.environment.etc."${serviceName}/provisioning/dashboards/nodes-detail.json".source
        config.environment.etc."${serviceName}/provisioning/dashboards/dns-edge.json".source
        config.environment.etc."${serviceName}/provisioning/dashboards/nas-detail.json".source
      ] ++ lib.optionals (cfg.provisioning.enable && cfg.provisioning.dashboards.enableStarter && cfg.provisioning.datasources.loki.url != null) [
        config.environment.etc."${serviceName}/provisioning/dashboards/nas-file-activity.json".source
      ] ++ [
        config.environment.etc."${serviceName}/docker-compose.yml".source
      ];
      startLimitBurst = 3;
      startLimitIntervalSec = 300;

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = 180;
        Restart = "on-failure";
        RestartSec = 10;
        WorkingDirectory = composeDir;

        Environment = [
          "GRAFANA_CONTAINER_NAME=${cfg.containerName}"
          "GRAFANA_IMAGE_REPOSITORY=${cfg.image.repository}"
          "GRAFANA_IMAGE_TAG=${cfg.image.tag}"
          "GRAFANA_NETWORK=${cfg.network}"
          "GRAFANA_HOSTNAME=${cfg.hostname}"
          "GRAFANA_ENTRYPOINTS=${if cfg.tls then "websecure" else "web"}"
          "GRAFANA_TLS=${if cfg.tls then "true" else "false"}"
          "GRAFANA_DATA_DIR=${cfg.dataDir}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${cfg.dataDir} && chown 472:472 ${cfg.dataDir} && chmod 0750 ${cfg.dataDir}'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
        ] ++ lib.optionals cfg.provisioning.enable [
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/provisioning/datasources/datasources.yml'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/provisioning/dashboards/providers.yml'"
        ] ++ lib.optionals (cfg.provisioning.enable && cfg.provisioning.dashboards.enableStarter) [
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/provisioning/dashboards/homelab-overview.json'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/provisioning/dashboards/nodes-detail.json'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/provisioning/dashboards/dns-edge.json'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/provisioning/dashboards/nas-detail.json'"
        ] ++ lib.optionals (cfg.provisioning.enable && cfg.provisioning.dashboards.enableStarter && cfg.provisioning.datasources.loki.url != null) [
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/provisioning/dashboards/nas-file-activity.json'"
        ] ++ [
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"grafana: docker daemon is not ready\" >&2; exit 1'"
          (runtimeSecretEnv.mkRuntimeSecretEnvExecStartPre {
            name = serviceName;
            secretFile = cfg.adminPasswordFile;
            envVar = "GF_SECURITY_ADMIN_PASSWORD";
          })
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStartPost = waitForHealthy;
        ExecStop = "${dockerBin} compose down";
      };
    };

    systemd.services."${serviceName}-healthcheck" = lib.mkIf cfg.monitoring.enable {
      description = "Grafana periodic healthcheck";
      after = ["${serviceName}.service"];
      requires = ["${serviceName}.service"];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = healthcheckScript;
      };
    };

    systemd.timers."${serviceName}-healthcheck" = lib.mkIf cfg.monitoring.enable {
      description = "Run Grafana periodic healthcheck";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "2m";
        OnUnitActiveSec = cfg.monitoring.interval;
        Unit = "${serviceName}-healthcheck.service";
      };
    };

    systemd.services."${serviceName}-backup" = lib.mkIf cfg.backup.enable {
      description = "Backup Grafana data";
      after = [ "${serviceName}.service" ];
      requires = [ "${serviceName}.service" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = backupScript;
      };
    };

    systemd.timers."${serviceName}-backup" = lib.mkIf cfg.backup.enable {
      description = "Periodic Grafana backup";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.backup.schedule;
        Persistent = true;
        Unit = "${serviceName}-backup.service";
      };
    };
  };
}
