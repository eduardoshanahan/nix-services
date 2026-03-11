{
  starterDashboardJson = builtins.toJSON {
    id = null;
    uid = "homelab-overview";
    title = "Homelab Overview";
    tags = ["homelab" "starter"];
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
            calcs = ["lastNotNull"];
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
            calcs = ["lastNotNull"];
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
            calcs = ["lastNotNull"];
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
            calcs = ["lastNotNull"];
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
            expr = "sum by (instance) (rate(promtail_sent_entries_total[5m]))";
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
      {
        id = 12;
        type = "stat";
        title = "Platform Health - Alertmanager";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 8;
          x = 0;
          y = 38;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          justifyMode = "auto";
          orientation = "auto";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
          textMode = "auto";
        };
        targets = [
          {
            expr = "sum(up{job=\"alertmanager\"})";
            refId = "A";
          }
        ];
      }
      {
        id = 13;
        type = "stat";
        title = "Platform Health - Grafana";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 8;
          x = 8;
          y = 38;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          justifyMode = "auto";
          orientation = "auto";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
          textMode = "auto";
        };
        targets = [
          {
            expr = "sum(up{job=\"grafana\"})";
            refId = "A";
          }
        ];
      }
      {
        id = 14;
        type = "stat";
        title = "Platform Health - SNMP Exporter";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 8;
          x = 16;
          y = 38;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          justifyMode = "auto";
          orientation = "auto";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
          textMode = "auto";
        };
        targets = [
          {
            expr = "sum(up{job=\"snmp-exporter\"})";
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
    tags = ["homelab" "nodes"];
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
          overrides = [];
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
  containerFleetDashboardJson = builtins.toJSON {
    id = null;
    uid = "container-fleet";
    title = "Container Fleet";
    tags = ["homelab" "containers" "cadvisor"];
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
        type = "table";
        title = "Container Capacity by Host";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 14;
          w = 24;
          x = 0;
          y = 0;
        };
        options = {
          cellHeight = "sm";
          footer = {
            enablePagination = false;
            reducer = [];
            show = false;
          };
          showHeader = true;
          sortBy = [
            {
              desc = false;
              displayName = "Hostname";
            }
          ];
        };
        fieldConfig = {
          defaults = {
            custom = {
              align = "auto";
              cellOptions = {
                type = "auto";
              };
              inspect = false;
            };
          };
          overrides = [
            {
              matcher = {
                id = "byName";
                options = "CPU load";
              };
              properties = [
                {
                  id = "unit";
                  value = "percent";
                }
                {
                  id = "decimals";
                  value = 1;
                }
              ];
            }
            {
              matcher = {
                id = "byName";
                options = "Memory %";
              };
              properties = [
                {
                  id = "unit";
                  value = "percent";
                }
                {
                  id = "decimals";
                  value = 1;
                }
              ];
            }
            {
              matcher = {
                id = "byName";
                options = "Disk %";
              };
              properties = [
                {
                  id = "unit";
                  value = "percent";
                }
                {
                  id = "decimals";
                  value = 1;
                }
              ];
            }
            {
              matcher = {
                id = "byName";
                options = "Containers";
              };
              properties = [
                {
                  id = "decimals";
                  value = 0;
                }
              ];
            }
          ];
        };
        transformations = [
          {
            id = "joinByField";
            options = {
              byField = "hostname";
              mode = "outer";
            };
          }
          {
            id = "organize";
            options = {
              excludeByName = {
                "Time" = true;
                "Time #A" = true;
                "Time #B" = true;
                "Time #C" = true;
                "Time #D" = true;
                "Time #E" = true;
                "Value #A" = true;
              };
              indexByName = {
                "hostname" = 0;
                "Value #B" = 1;
                "Value #C" = 2;
                "Value #D" = 3;
                "Value #E" = 4;
              };
              renameByName = {
                "hostname" = "Hostname";
                "Value #B" = "Containers";
                "Value #C" = "CPU load";
                "Value #D" = "Memory %";
                "Value #E" = "Disk %";
              };
            };
          }
        ];
        targets = [
          {
            expr = "sum by (hostname) (label_replace(up{job=\"nodes\"}, \"hostname\", \"$1\", \"instance\", \"([^.:]+).*\"))";
            format = "table";
            instant = true;
            refId = "A";
          }
          {
            expr = "sum by (hostname) (label_replace(count by (instance) (container_last_seen{job=\"cadvisor\",name!=\"\",image!=\"\"}), \"hostname\", \"$1\", \"instance\", \"([^.:]+).*\"))";
            format = "table";
            instant = true;
            refId = "B";
          }
          {
            expr = "sum by (hostname) (label_replace(100 - (avg by (instance) (rate(node_cpu_seconds_total{job=\"nodes\",mode=\"idle\"}[5m])) * 100), \"hostname\", \"$1\", \"instance\", \"([^.:]+).*\"))";
            format = "table";
            instant = true;
            refId = "C";
          }
          {
            expr = "sum by (hostname) (label_replace(100 * (1 - (node_memory_MemAvailable_bytes{job=\"nodes\"} / node_memory_MemTotal_bytes{job=\"nodes\"})), \"hostname\", \"$1\", \"instance\", \"([^.:]+).*\"))";
            format = "table";
            instant = true;
            refId = "D";
          }
          {
            expr = "sum by (hostname) (label_replace(100 * (1 - (node_filesystem_avail_bytes{job=\"nodes\",mountpoint=\"/\",fstype!~\"tmpfs|overlay\"} / node_filesystem_size_bytes{job=\"nodes\",mountpoint=\"/\",fstype!~\"tmpfs|overlay\"})), \"hostname\", \"$1\", \"instance\", \"([^.:]+).*\"))";
            format = "table";
            instant = true;
            refId = "E";
          }
        ];
      }
      {
        id = 2;
        type = "table";
        title = "Container Usage by Container";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 18;
          w = 24;
          x = 0;
          y = 14;
        };
        options = {
          cellHeight = "sm";
          footer = {
            enablePagination = true;
            reducer = [];
            show = false;
          };
          showHeader = true;
          sortBy = [
            {
              desc = false;
              displayName = "Hostname";
            }
          ];
        };
        fieldConfig = {
          defaults = {
            custom = {
              align = "auto";
              cellOptions = {
                type = "auto";
              };
              inspect = false;
            };
          };
          overrides = [
            {
              matcher = {
                id = "byName";
                options = "CPU %";
              };
              properties = [
                {
                  id = "unit";
                  value = "percent";
                }
                {
                  id = "decimals";
                  value = 1;
                }
              ];
            }
            {
              matcher = {
                id = "byName";
                options = "Memory %";
              };
              properties = [
                {
                  id = "unit";
                  value = "percent";
                }
                {
                  id = "decimals";
                  value = 1;
                }
              ];
            }
            {
              matcher = {
                id = "byName";
                options = "Disk %";
              };
              properties = [
                {
                  id = "unit";
                  value = "percent";
                }
                {
                  id = "decimals";
                  value = 1;
                }
              ];
            }
          ];
        };
        transformations = [
          {
            id = "joinByField";
            options = {
              byField = "container_key";
              mode = "outer";
            };
          }
          {
            id = "organize";
            options = {
              excludeByName = {
                "Time" = true;
                "Time #A" = true;
                "Time #B" = true;
                "Time #C" = true;
                "Time #D" = true;
                "Value #A" = true;
                "container_key" = true;
              };
              indexByName = {
                "hostname" = 0;
                "name" = 1;
                "Value #B" = 2;
                "Value #C" = 3;
                "Value #D" = 4;
              };
              renameByName = {
                "hostname" = "Hostname";
                "name" = "Container";
                "Value #B" = "CPU %";
                "Value #C" = "Memory %";
                "Value #D" = "Disk %";
              };
            };
          }
        ];
        targets = [
          {
            expr = "max by (container_key, hostname, name) (label_join(label_replace(container_last_seen{job=\"cadvisor\",name!=\"\",image!=\"\"}, \"hostname\", \"$1\", \"instance\", \"([^.:]+).*\"), \"container_key\", \" / \", \"hostname\", \"name\"))";
            format = "table";
            instant = true;
            refId = "A";
          }
          {
            expr = "sum by (container_key) (label_join(label_replace(sum by (instance, name) (rate(container_cpu_usage_seconds_total{job=\"cadvisor\",name!=\"\",image!=\"\"}[5m])) * 100, \"hostname\", \"$1\", \"instance\", \"([^.:]+).*\"), \"container_key\", \" / \", \"hostname\", \"name\"))";
            format = "table";
            instant = true;
            refId = "B";
          }
          {
            expr = "sum by (container_key) (label_join((100 * sum by (hostname, name) (label_replace(container_memory_working_set_bytes{job=\"cadvisor\",name!=\"\",image!=\"\"}, \"hostname\", \"$1\", \"instance\", \"([^.:]+).*\")) / on(hostname) group_left max by (hostname) (label_replace(node_memory_MemTotal_bytes{job=\"nodes\"}, \"hostname\", \"$1\", \"instance\", \"([^.:]+).*\"))), \"container_key\", \" / \", \"hostname\", \"name\"))";
            format = "table";
            instant = true;
            refId = "C";
          }
          {
            expr = "sum by (container_key) (label_join((100 * sum by (hostname, name) (label_replace(container_fs_usage_bytes{job=\"cadvisor\",name!=\"\",image!=\"\"}, \"hostname\", \"$1\", \"instance\", \"([^.:]+).*\")) / on(hostname) group_left max by (hostname) (label_replace(node_filesystem_size_bytes{job=\"nodes\",mountpoint=\"/\",fstype!~\"tmpfs|overlay\"}, \"hostname\", \"$1\", \"instance\", \"([^.:]+).*\"))), \"container_key\", \" / \", \"hostname\", \"name\"))";
            format = "table";
            instant = true;
            refId = "D";
          }
        ];
      }
    ];
  };
  dnsEdgeDashboardJson = builtins.toJSON {
    id = null;
    uid = "dns-edge";
    title = "DNS & Edge";
    tags = ["homelab" "dns" "edge"];
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
            calcs = ["lastNotNull"];
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
            calcs = ["lastNotNull"];
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
            calcs = ["lastNotNull"];
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
            calcs = ["lastNotNull"];
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
            expr = "sum by (instance) (rate(promtail_sent_entries_total[5m]))";
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
    tags = ["homelab" "nas" "synology"];
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
            calcs = ["lastNotNull"];
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
    tags = ["homelab" "nas" "logs" "loki"];
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
            expr = "sum by (host) (rate({job=\"synology-file-activity\"}[5m]))";
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
            calcs = ["lastNotNull"];
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
            expr = "sum by (host) (rate({job=\"synology-file-activity\"} |~ \"(?i)(fail|denied|unauthorized|permission)\"[5m])) or label_replace(vector(0), \"host\", \"nas2\", \"\", \"\") or label_replace(vector(0), \"host\", \"hhnas4\", \"\", \"\")";
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
            calcs = ["lastNotNull"];
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
  giteaOverviewDashboardJson = builtins.toJSON {
    id = null;
    uid = "gitea-overview";
    title = "Gitea Overview";
    tags = ["homelab" "gitea"];
    timezone = "browser";
    schemaVersion = 39;
    version = 1;
    refresh = "30s";
    time = {
      from = "now-24h";
      to = "now";
    };
    editable = true;
    panels = [
      {
        id = 1;
        type = "stat";
        title = "Gitea Target Up";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 5;
          w = 4;
          x = 0;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
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
        id = 2;
        type = "stat";
        title = "Repositories";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 5;
          w = 4;
          x = 4;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
          textMode = "auto";
        };
        targets = [
          {
            expr = "sum(gitea_repositories{job=\"gitea\"})";
            refId = "A";
          }
        ];
      }
      {
        id = 3;
        type = "stat";
        title = "Users";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 5;
          w = 4;
          x = 8;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
          textMode = "auto";
        };
        targets = [
          {
            expr = "sum(gitea_users{job=\"gitea\"})";
            refId = "A";
          }
        ];
      }
      {
        id = 4;
        type = "stat";
        title = "Organizations";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 5;
          w = 4;
          x = 12;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
          textMode = "auto";
        };
        targets = [
          {
            expr = "sum(gitea_organizations{job=\"gitea\"})";
            refId = "A";
          }
        ];
      }
      {
        id = 5;
        type = "stat";
        title = "Open Issues";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 5;
          w = 4;
          x = 16;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
          textMode = "auto";
        };
        targets = [
          {
            expr = "sum(gitea_issues_open{job=\"gitea\"})";
            refId = "A";
          }
        ];
      }
      {
        id = 6;
        type = "stat";
        title = "Closed Issues";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 5;
          w = 4;
          x = 20;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
          textMode = "auto";
        };
        targets = [
          {
            expr = "sum(gitea_issues_closed{job=\"gitea\"})";
            refId = "A";
          }
        ];
      }
      {
        id = 7;
        type = "timeseries";
        title = "Repositories (Trend)";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 8;
          x = 0;
          y = 5;
        };
        targets = [
          {
            expr = "sum(gitea_repositories{job=\"gitea\"})";
            legendFormat = "repositories";
            refId = "A";
          }
        ];
      }
      {
        id = 8;
        type = "timeseries";
        title = "Users (Trend)";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 8;
          x = 8;
          y = 5;
        };
        targets = [
          {
            expr = "sum(gitea_users{job=\"gitea\"})";
            legendFormat = "users";
            refId = "A";
          }
        ];
      }
      {
        id = 9;
        type = "timeseries";
        title = "Issues Open vs Closed";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 8;
          x = 16;
          y = 5;
        };
        targets = [
          {
            expr = "sum(gitea_issues_open{job=\"gitea\"})";
            legendFormat = "open";
            refId = "A";
          }
          {
            expr = "sum(gitea_issues_closed{job=\"gitea\"})";
            legendFormat = "closed";
            refId = "B";
          }
        ];
      }
      {
        id = 10;
        type = "timeseries";
        title = "Gitea Metrics Scrape Rate (req/s)";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 13;
        };
        targets = [
          {
            expr = "sum by (instance) (rate(promhttp_metric_handler_requests_total{job=\"gitea\"}[5m]))";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
      }
      {
        id = 11;
        type = "timeseries";
        title = "Stars vs Watches";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 13;
        };
        targets = [
          {
            expr = "sum(gitea_stars{job=\"gitea\"})";
            legendFormat = "stars";
            refId = "A";
          }
          {
            expr = "sum(gitea_watches{job=\"gitea\"})";
            legendFormat = "watches";
            refId = "B";
          }
        ];
      }
      {
        id = 12;
        type = "timeseries";
        title = "GitHub Profile Stats";
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
            expr = "max by (username) (github_profile_followers{job=\"github-profile\"})";
            legendFormat = "{{username}} followers";
            refId = "A";
          }
          {
            expr = "max by (username) (github_profile_public_repos{job=\"github-profile\"})";
            legendFormat = "{{username}} public repos";
            refId = "B";
          }
          {
            expr = "max by (username) (github_profile_total_stars{job=\"github-profile\"})";
            legendFormat = "{{username}} stars";
            refId = "C";
          }
          {
            expr = "max by (username) (github_profile_total_open_issues{job=\"github-profile\"})";
            legendFormat = "{{username}} open issues";
            refId = "D";
          }
        ];
      }
      {
        id = 13;
        type = "timeseries";
        title = "GitHub Commits (1d/7d/30d/365d)";
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
            expr = "max by (username) (github_profile_commits_1d{job=\"github-profile\"})";
            legendFormat = "{{username}} commits 1d";
            refId = "A";
          }
          {
            expr = "max by (username) (github_profile_commits_7d{job=\"github-profile\"})";
            legendFormat = "{{username}} commits 7d";
            refId = "B";
          }
          {
            expr = "max by (username) (github_profile_commits_30d{job=\"github-profile\"})";
            legendFormat = "{{username}} commits 30d";
            refId = "C";
          }
          {
            expr = "max by (username) (github_profile_commits_365d{job=\"github-profile\"})";
            legendFormat = "{{username}} commits 365d";
            refId = "D";
          }
        ];
      }
    ];
  };
  sharedInfraDashboardJson = builtins.toJSON {
    id = null;
    uid = "shared-infra";
    title = "Shared Infra";
    tags = ["homelab" "shared-infra" "postgres" "redis" "mysql" "mongo" "dolt"];
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
        title = "Postgres DB Up";
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
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            decimals = 0;
            min = 0;
            max = 1;
            mappings = [
              {
                type = "value";
                options = {
                  "0" = {
                    text = "DOWN";
                  };
                  "1" = {
                    text = "UP";
                  };
                };
              }
            ];
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = null;
                }
                {
                  color = "green";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "max(pg_up{job=\"postgres-exporter\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 2;
        type = "stat";
        title = "Redis DB Up";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 6;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            decimals = 0;
            min = 0;
            max = 1;
            mappings = [
              {
                type = "value";
                options = {
                  "0" = {
                    text = "DOWN";
                  };
                  "1" = {
                    text = "UP";
                  };
                };
              }
            ];
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = null;
                }
                {
                  color = "green";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "max(redis_up{job=\"redis-exporter\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 3;
        type = "stat";
        title = "MySQL DB Up";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 12;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            decimals = 0;
            min = 0;
            max = 1;
            mappings = [
              {
                type = "value";
                options = {
                  "0" = {
                    text = "DOWN";
                  };
                  "1" = {
                    text = "UP";
                  };
                };
              }
            ];
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = null;
                }
                {
                  color = "green";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "max(mysql_up{job=\"mysql-exporter\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 34;
        type = "stat";
        title = "Mongo DB Up";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 18;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            decimals = 0;
            min = 0;
            max = 1;
            mappings = [
              {
                type = "value";
                options = {
                  "0" = {
                    text = "DOWN";
                  };
                  "1" = {
                    text = "UP";
                  };
                };
              }
            ];
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = null;
                }
                {
                  color = "green";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "max(mongodb_up{job=\"mongodb-exporter\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 4;
        type = "timeseries";
        title = "Postgres Connections by DB";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 8;
          x = 0;
          y = 6;
        };
        targets = [
          {
            expr = "sum by (datname) (pg_stat_database_numbackends{job=\"postgres-exporter\",datname!~\"template0|template1\"})";
            legendFormat = "{{datname}}";
            refId = "A";
          }
        ];
        fieldConfig = {
          defaults = {
            min = 0;
            unit = "short";
          };
          overrides = [];
        };
      }
      {
        id = 5;
        type = "timeseries";
        title = "Redis Connected Clients";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 8;
          x = 8;
          y = 6;
        };
        targets = [
          {
            expr = "max by (instance) (redis_connected_clients{job=\"redis-exporter\"})";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
        fieldConfig = {
          defaults = {
            min = 0;
            unit = "short";
          };
          overrides = [];
        };
      }
      {
        id = 6;
        type = "timeseries";
        title = "MySQL Threads Connected";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 8;
          x = 16;
          y = 6;
        };
        targets = [
          {
            expr = "max by (instance) (mysql_global_status_threads_connected{job=\"mysql-exporter\"})";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
        fieldConfig = {
          defaults = {
            min = 0;
            unit = "short";
          };
          overrides = [];
        };
      }
      {
        id = 7;
        type = "timeseries";
        title = "Postgres TPS by DB";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 8;
          x = 0;
          y = 14;
        };
        targets = [
          {
            expr = "sum by (datname) (rate(pg_stat_database_xact_commit{job=\"postgres-exporter\",datname!~\"template0|template1\"}[5m]) + rate(pg_stat_database_xact_rollback{job=\"postgres-exporter\",datname!~\"template0|template1\"}[5m]))";
            legendFormat = "{{datname}}";
            refId = "A";
          }
        ];
        fieldConfig = {
          defaults = {
            min = 0;
            unit = "reqps";
          };
          overrides = [];
        };
      }
      {
        id = 8;
        type = "timeseries";
        title = "Redis Commands Processed/s";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 8;
          x = 8;
          y = 14;
        };
        targets = [
          {
            expr = "sum by (instance) (rate(redis_commands_processed_total{job=\"redis-exporter\"}[5m]))";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
        fieldConfig = {
          defaults = {
            min = 0;
            unit = "reqps";
          };
          overrides = [];
        };
      }
      {
        id = 9;
        type = "timeseries";
        title = "MySQL Queries/s";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 8;
          x = 16;
          y = 14;
        };
        targets = [
          {
            expr = "sum by (instance) ((rate(mysql_global_status_queries{job=\"mysql-exporter\"}[5m])) or (rate(mysql_global_status_questions{job=\"mysql-exporter\"}[5m])))";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
        fieldConfig = {
          defaults = {
            min = 0;
            unit = "reqps";
          };
          overrides = [];
        };
      }
      {
        id = 10;
        type = "timeseries";
        title = "Postgres DB Size";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 8;
          x = 0;
          y = 22;
        };
        fieldConfig = {
          defaults = {
            unit = "bytes";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum by (datname) (pg_database_size_bytes{job=\"postgres-exporter\",datname!~\"template0|template1\"})";
            legendFormat = "{{datname}}";
            refId = "A";
          }
        ];
      }
      {
        id = 11;
        type = "timeseries";
        title = "Redis Memory Used";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 8;
          x = 8;
          y = 22;
        };
        fieldConfig = {
          defaults = {
            unit = "bytes";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "max by (instance) (redis_memory_used_bytes{job=\"redis-exporter\"})";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
      }
      {
        id = 12;
        type = "timeseries";
        title = "MySQL Threads Running";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 8;
          x = 16;
          y = 22;
        };
        targets = [
          {
            expr = "max by (instance) (mysql_global_status_threads_running{job=\"mysql-exporter\"})";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
        fieldConfig = {
          defaults = {
            min = 0;
            unit = "short";
          };
          overrides = [];
        };
      }
      {
        id = 13;
        type = "stat";
        title = "SMTP Relay Container Seen (last 2m)";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 12;
          x = 0;
          y = 30;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            decimals = 0;
            min = 0;
            max = 1;
            mappings = [
              {
                type = "value";
                options = {
                  "0" = {
                    text = "NOT SEEN";
                  };
                  "1" = {
                    text = "SEEN";
                  };
                };
              }
            ];
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = null;
                }
                {
                  color = "green";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "max((time() - container_last_seen{job=\"cadvisor\",container_label_com_docker_compose_service=\"smtp-relay\"}) < bool 120)";
            refId = "A";
          }
        ];
      }
      {
        id = 14;
        type = "stat";
        title = "SMTP Relay systemd Active";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 12;
          x = 12;
          y = 30;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            decimals = 0;
            min = 0;
            max = 1;
            mappings = [
              {
                type = "value";
                options = {
                  "0" = {
                    text = "INACTIVE";
                  };
                  "1" = {
                    text = "ACTIVE";
                  };
                };
              }
            ];
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = null;
                }
                {
                  color = "green";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "max(node_systemd_unit_state{job=\"nodes\",name=\"smtp-relay.service\",state=\"active\"})";
            refId = "A";
          }
        ];
      }
      {
        id = 15;
        type = "stat";
        title = "Shared Infra DB Conditions Active";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 12;
          x = 0;
          y = 36;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            decimals = 0;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "red";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "((max(pg_up{job=\"postgres-exporter\"} == bool 0) or vector(0)) + (max(redis_up{job=\"redis-exporter\"} == bool 0) or vector(0)) + (max(mysql_up{job=\"mysql-exporter\"} == bool 0) or vector(0)) + (max(mongodb_up{job=\"mongodb-exporter\"} == bool 0) or vector(0)))";
            refId = "A";
          }
        ];
      }
      {
        id = 16;
        type = "timeseries";
        title = "Shared Infra DB Conditions by Type";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 12;
          x = 12;
          y = 36;
        };
        fieldConfig = {
          defaults = {
            min = 0;
            max = 1;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "red";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "max(pg_up{job=\"postgres-exporter\"} == bool 0) or vector(0)";
            legendFormat = "postgres";
            refId = "A";
          }
          {
            expr = "max(redis_up{job=\"redis-exporter\"} == bool 0) or vector(0)";
            legendFormat = "redis";
            refId = "B";
          }
          {
            expr = "max(mysql_up{job=\"mysql-exporter\"} == bool 0) or vector(0)";
            legendFormat = "mysql";
            refId = "C";
          }
          {
            expr = "max(mongodb_up{job=\"mongodb-exporter\"} == bool 0) or vector(0)";
            legendFormat = "mongo";
            refId = "D";
          }
        ];
      }
      {
        id = 17;
        type = "stat";
        title = "SMTP Relay Conditions Active";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 12;
          x = 0;
          y = 42;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            decimals = 0;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "red";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "(((max(node_systemd_unit_state{job=\"nodes\",name=\"smtp-relay.service\",state=\"active\"}) or vector(0)) == bool 0) + ((max((time() - container_last_seen{job=\"cadvisor\",container_label_com_docker_compose_service=\"smtp-relay\"}) < bool 120) or vector(0)) == bool 0))";
            refId = "A";
          }
        ];
      }
      {
        id = 18;
        type = "timeseries";
        title = "SMTP Relay Conditions by Type";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 12;
          x = 12;
          y = 42;
        };
        fieldConfig = {
          defaults = {
            min = 0;
            max = 1;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "red";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "(max(node_systemd_unit_state{job=\"nodes\",name=\"smtp-relay.service\",state=\"active\"}) or vector(0)) == bool 0";
            legendFormat = "systemd_inactive";
            refId = "A";
          }
          {
            expr = "(max((time() - container_last_seen{job=\"cadvisor\",container_label_com_docker_compose_service=\"smtp-relay\"}) < bool 120) or vector(0)) == bool 0";
            legendFormat = "container_not_seen";
            refId = "B";
          }
        ];
      }
      {
        id = 19;
        type = "timeseries";
        title = "Shared Infra Exporter Scrape Up";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 24;
          x = 0;
          y = 48;
        };
        fieldConfig = {
          defaults = {
            min = 0;
            max = 1;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = null;
                }
                {
                  color = "green";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "max(up{job=\"postgres-exporter\"}) or vector(0)";
            legendFormat = "postgres-exporter scrape";
            refId = "A";
          }
          {
            expr = "max(up{job=\"redis-exporter\"}) or vector(0)";
            legendFormat = "redis-exporter scrape";
            refId = "B";
          }
          {
            expr = "max(up{job=\"mysql-exporter\"}) or vector(0)";
            legendFormat = "mysql-exporter scrape";
            refId = "C";
          }
          {
            expr = "max(up{job=\"mongodb-exporter\"}) or vector(0)";
            legendFormat = "mongodb-exporter scrape";
            refId = "D";
          }
        ];
      }
      {
        id = 20;
        type = "stat";
        title = "Shared Infra Degraded (Scrape Up, DB Down)";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 12;
          x = 0;
          y = 54;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            decimals = 0;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "red";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "(((max(up{job=\"postgres-exporter\"}) or vector(0)) * (max(pg_up{job=\"postgres-exporter\"} == bool 0) or vector(0))) + ((max(up{job=\"redis-exporter\"}) or vector(0)) * (max(redis_up{job=\"redis-exporter\"} == bool 0) or vector(0))) + ((max(up{job=\"mysql-exporter\"}) or vector(0)) * (max(mysql_up{job=\"mysql-exporter\"} == bool 0) or vector(0))) + ((max(up{job=\"mongodb-exporter\"}) or vector(0)) * (max(mongodb_up{job=\"mongodb-exporter\"} == bool 0) or vector(0))))";
            refId = "A";
          }
        ];
      }
      {
        id = 21;
        type = "timeseries";
        title = "Shared Infra Degraded by Service";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 12;
          x = 12;
          y = 54;
        };
        fieldConfig = {
          defaults = {
            min = 0;
            max = 1;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "red";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "(max(up{job=\"postgres-exporter\"}) or vector(0)) * (max(pg_up{job=\"postgres-exporter\"} == bool 0) or vector(0))";
            legendFormat = "postgres";
            refId = "A";
          }
          {
            expr = "(max(up{job=\"redis-exporter\"}) or vector(0)) * (max(redis_up{job=\"redis-exporter\"} == bool 0) or vector(0))";
            legendFormat = "redis";
            refId = "B";
          }
          {
            expr = "(max(up{job=\"mysql-exporter\"}) or vector(0)) * (max(mysql_up{job=\"mysql-exporter\"} == bool 0) or vector(0))";
            legendFormat = "mysql";
            refId = "C";
          }
          {
            expr = "(max(up{job=\"mongodb-exporter\"}) or vector(0)) * (max(mongodb_up{job=\"mongodb-exporter\"} == bool 0) or vector(0))";
            legendFormat = "mongo";
            refId = "D";
          }
        ];
      }
      {
        id = 22;
        type = "stat";
        title = "Shared Infra Exporters Down";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 12;
          x = 0;
          y = 60;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            decimals = 0;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "red";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "((max(up{job=\"postgres-exporter\"} == bool 0) or vector(0)) + (max(up{job=\"redis-exporter\"} == bool 0) or vector(0)) + (max(up{job=\"mysql-exporter\"} == bool 0) or vector(0)) + (max(up{job=\"mongodb-exporter\"} == bool 0) or vector(0)))";
            refId = "A";
          }
        ];
      }
      {
        id = 23;
        type = "timeseries";
        title = "Shared Infra Exporters Down by Service";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 12;
          x = 12;
          y = 60;
        };
        fieldConfig = {
          defaults = {
            min = 0;
            max = 1;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "red";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "max(up{job=\"postgres-exporter\"} == bool 0) or vector(0)";
            legendFormat = "postgres-exporter";
            refId = "A";
          }
          {
            expr = "max(up{job=\"redis-exporter\"} == bool 0) or vector(0)";
            legendFormat = "redis-exporter";
            refId = "B";
          }
          {
            expr = "max(up{job=\"mysql-exporter\"} == bool 0) or vector(0)";
            legendFormat = "mysql-exporter";
            refId = "C";
          }
          {
            expr = "max(up{job=\"mongodb-exporter\"} == bool 0) or vector(0)";
            legendFormat = "mongodb-exporter";
            refId = "D";
          }
        ];
      }
      {
        id = 24;
        type = "stat";
        title = "Postgres Service State";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 8;
          x = 0;
          y = 66;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            decimals = 0;
            mappings = [
              {
                type = "value";
                options = {
                  "0" = {
                    text = "DOWN";
                  };
                  "1" = {
                    text = "DEGRADED";
                  };
                  "2" = {
                    text = "HEALTHY";
                  };
                };
              }
            ];
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = null;
                }
                {
                  color = "yellow";
                  value = 1;
                }
                {
                  color = "green";
                  value = 2;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "(2 * ((max(up{job=\"postgres-exporter\"}) or vector(0)) * (max(pg_up{job=\"postgres-exporter\"}) or vector(0)))) + ((max(up{job=\"postgres-exporter\"}) or vector(0)) * (max(pg_up{job=\"postgres-exporter\"} == bool 0) or vector(0)))";
            refId = "A";
          }
        ];
      }
      {
        id = 25;
        type = "stat";
        title = "Redis Service State";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 8;
          x = 8;
          y = 66;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            decimals = 0;
            mappings = [
              {
                type = "value";
                options = {
                  "0" = {
                    text = "DOWN";
                  };
                  "1" = {
                    text = "DEGRADED";
                  };
                  "2" = {
                    text = "HEALTHY";
                  };
                };
              }
            ];
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = null;
                }
                {
                  color = "yellow";
                  value = 1;
                }
                {
                  color = "green";
                  value = 2;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "(2 * ((max(up{job=\"redis-exporter\"}) or vector(0)) * (max(redis_up{job=\"redis-exporter\"}) or vector(0)))) + ((max(up{job=\"redis-exporter\"}) or vector(0)) * (max(redis_up{job=\"redis-exporter\"} == bool 0) or vector(0)))";
            refId = "A";
          }
        ];
      }
      {
        id = 26;
        type = "stat";
        title = "MySQL Service State";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 8;
          x = 16;
          y = 66;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            decimals = 0;
            mappings = [
              {
                type = "value";
                options = {
                  "0" = {
                    text = "DOWN";
                  };
                  "1" = {
                    text = "DEGRADED";
                  };
                  "2" = {
                    text = "HEALTHY";
                  };
                };
              }
            ];
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = null;
                }
                {
                  color = "yellow";
                  value = 1;
                }
                {
                  color = "green";
                  value = 2;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "(2 * ((max(up{job=\"mysql-exporter\"}) or vector(0)) * (max(mysql_up{job=\"mysql-exporter\"}) or vector(0)))) + ((max(up{job=\"mysql-exporter\"}) or vector(0)) * (max(mysql_up{job=\"mysql-exporter\"} == bool 0) or vector(0)))";
            refId = "A";
          }
        ];
      }
      {
        id = 27;
        type = "stat";
        title = "Overall Shared Infra State";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 24;
          x = 0;
          y = 72;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            decimals = 0;
            mappings = [
              {
                type = "value";
                options = {
                  "0" = {
                    text = "DOWN";
                  };
                  "1" = {
                    text = "DEGRADED";
                  };
                  "2" = {
                    text = "HEALTHY";
                  };
                };
              }
            ];
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = null;
                }
                {
                  color = "yellow";
                  value = 1;
                }
                {
                  color = "green";
                  value = 2;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "(2 * ((((max(up{job=\"postgres-exporter\"} == bool 0) or vector(0)) + (max(up{job=\"redis-exporter\"} == bool 0) or vector(0)) + (max(up{job=\"mysql-exporter\"} == bool 0) or vector(0)) + (max(up{job=\"mongodb-exporter\"} == bool 0) or vector(0))) == bool 0) * ((((max(up{job=\"postgres-exporter\"}) or vector(0)) * (max(pg_up{job=\"postgres-exporter\"} == bool 0) or vector(0))) + ((max(up{job=\"redis-exporter\"}) or vector(0)) * (max(redis_up{job=\"redis-exporter\"} == bool 0) or vector(0))) + ((max(up{job=\"mysql-exporter\"}) or vector(0)) * (max(mysql_up{job=\"mysql-exporter\"} == bool 0) or vector(0))) + ((max(up{job=\"mongodb-exporter\"}) or vector(0)) * (max(mongodb_up{job=\"mongodb-exporter\"} == bool 0) or vector(0)))) == bool 0))) + ((((max(up{job=\"postgres-exporter\"} == bool 0) or vector(0)) + (max(up{job=\"redis-exporter\"} == bool 0) or vector(0)) + (max(up{job=\"mysql-exporter\"} == bool 0) or vector(0)) + (max(up{job=\"mongodb-exporter\"} == bool 0) or vector(0))) == bool 0) * ((((max(up{job=\"postgres-exporter\"}) or vector(0)) * (max(pg_up{job=\"postgres-exporter\"} == bool 0) or vector(0))) + ((max(up{job=\"redis-exporter\"}) or vector(0)) * (max(redis_up{job=\"redis-exporter\"} == bool 0) or vector(0))) + ((max(up{job=\"mysql-exporter\"}) or vector(0)) * (max(mysql_up{job=\"mysql-exporter\"} == bool 0) or vector(0))) + ((max(up{job=\"mongodb-exporter\"}) or vector(0)) * (max(mongodb_up{job=\"mongodb-exporter\"} == bool 0) or vector(0)))) > bool 0))";
            refId = "A";
          }
        ];
      }
      {
        id = 28;
        type = "stat";
        title = "Any Exporter Down";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 12;
          x = 0;
          y = 78;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            decimals = 0;
            mappings = [
              {
                type = "value";
                options = {
                  "0" = {
                    text = "NO";
                  };
                };
              }
            ];
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "red";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "((max(up{job=\"postgres-exporter\"} == bool 0) or vector(0)) + (max(up{job=\"redis-exporter\"} == bool 0) or vector(0)) + (max(up{job=\"mysql-exporter\"} == bool 0) or vector(0)) + (max(up{job=\"mongodb-exporter\"} == bool 0) or vector(0)))";
            refId = "A";
          }
        ];
      }
      {
        id = 29;
        type = "stat";
        title = "Any Shared DB Degraded";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 12;
          x = 12;
          y = 78;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            decimals = 0;
            mappings = [
              {
                type = "value";
                options = {
                  "0" = {
                    text = "NO";
                  };
                };
              }
            ];
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "red";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "(((max(up{job=\"postgres-exporter\"}) or vector(0)) * (max(pg_up{job=\"postgres-exporter\"} == bool 0) or vector(0))) + ((max(up{job=\"redis-exporter\"}) or vector(0)) * (max(redis_up{job=\"redis-exporter\"} == bool 0) or vector(0))) + ((max(up{job=\"mysql-exporter\"}) or vector(0)) * (max(mysql_up{job=\"mysql-exporter\"} == bool 0) or vector(0))) + ((max(up{job=\"mongodb-exporter\"}) or vector(0)) * (max(mongodb_up{job=\"mongodb-exporter\"} == bool 0) or vector(0))))";
            refId = "A";
          }
        ];
      }
      {
        id = 35;
        type = "stat";
        title = "Dolt Metrics Scrape Up";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 8;
          x = 0;
          y = 84;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            decimals = 0;
            min = 0;
            max = 1;
            mappings = [
              {
                type = "value";
                options = {
                  "0" = {
                    text = "DOWN";
                  };
                  "1" = {
                    text = "UP";
                  };
                };
              }
            ];
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = null;
                }
                {
                  color = "green";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "max(up{job=\"dolt\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 36;
        type = "stat";
        title = "Dolt Concurrent Connections";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 8;
          x = 8;
          y = 84;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            decimals = 0;
            min = 0;
            unit = "short";
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "yellow";
                  value = 25;
                }
                {
                  color = "red";
                  value = 75;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "max(dss_concurrent_connections{job=\"dolt\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 37;
        type = "timeseries";
        title = "Dolt Concurrent Queries";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 8;
          x = 16;
          y = 84;
        };
        targets = [
          {
            expr = "max by (instance) (dss_concurrent_queries{job=\"dolt\"})";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
        fieldConfig = {
          defaults = {
            min = 0;
            unit = "short";
          };
          overrides = [];
        };
      }
      {
        id = 38;
        type = "timeseries";
        title = "Dolt Query Duration P95";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 24;
          x = 0;
          y = 90;
        };
        targets = [
          {
            expr = "histogram_quantile(0.95, sum by (le, instance) (rate(dss_query_duration_bucket{job=\"dolt\"}[5m])))";
            legendFormat = "{{instance}} p95";
            refId = "A";
          }
        ];
        fieldConfig = {
          defaults = {
            min = 0;
            unit = "s";
          };
          overrides = [];
        };
      }
    ];
  };
  monitoringControlPlaneDashboardJson = builtins.toJSON {
    id = null;
    uid = "monitoring-control-plane";
    title = "Monitoring Control Plane";
    tags = ["homelab" "monitoring" "control-plane"];
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
        title = "Prometheus Up";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 4;
          x = 0;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            min = 0;
            max = 1;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = null;
                }
                {
                  color = "green";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "max(up{job=\"prometheus\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 2;
        type = "stat";
        title = "Alertmanager Up";
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
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            min = 0;
            max = 1;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = null;
                }
                {
                  color = "green";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "max(up{job=\"alertmanager\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 3;
        type = "stat";
        title = "Grafana Up";
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
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            min = 0;
            max = 1;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = null;
                }
                {
                  color = "green";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "max(up{job=\"grafana\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 4;
        type = "stat";
        title = "Loki Up";
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
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            min = 0;
            max = 1;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = null;
                }
                {
                  color = "green";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "max(up{job=\"loki\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 5;
        type = "stat";
        title = "SNMP Exporter Up";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 4;
          x = 16;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            min = 0;
            max = 1;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = null;
                }
                {
                  color = "green";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "max(up{job=\"snmp-exporter\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 6;
        type = "stat";
        title = "Unpoller Up";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 4;
          x = 20;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            min = 0;
            max = 1;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = null;
                }
                {
                  color = "green";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "max(up{job=\"unpoller\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 7;
        type = "stat";
        title = "Node Targets Up";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 4;
          x = 0;
          y = 6;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        targets = [
          {
            expr = "sum(up{job=\"nodes\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 8;
        type = "stat";
        title = "Traefik Targets Up";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 4;
          x = 4;
          y = 6;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        targets = [
          {
            expr = "sum(up{job=\"traefik\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 9;
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
          y = 6;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        targets = [
          {
            expr = "sum(up{job=\"promtail\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 10;
        type = "stat";
        title = "cAdvisor Targets Up";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 4;
          x = 12;
          y = 6;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        targets = [
          {
            expr = "sum(up{job=\"cadvisor\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 11;
        type = "stat";
        title = "Pi-hole Exporter Targets Up";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 4;
          x = 16;
          y = 6;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        targets = [
          {
            expr = "sum(up{job=\"pihole-exporter\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 12;
        type = "stat";
        title = "Gitea Up";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 4;
          x = 20;
          y = 6;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            min = 0;
            max = 1;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = null;
                }
                {
                  color = "green";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "max(up{job=\"gitea\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 13;
        type = "stat";
        title = "Shared Exporters Up";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 8;
          x = 0;
          y = 12;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        targets = [
          {
            expr = "(sum(up{job=\"postgres-exporter\"}) or vector(0)) + (sum(up{job=\"redis-exporter\"}) or vector(0)) + (sum(up{job=\"mysql-exporter\"}) or vector(0)) + (sum(up{job=\"mongodb-exporter\"}) or vector(0))";
            refId = "A";
          }
        ];
      }
      {
        id = 14;
        type = "stat";
        title = "Core Jobs Down Count";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 8;
          x = 8;
          y = 12;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            decimals = 0;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "red";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum(up{job=~\"prometheus|alertmanager|grafana|loki|traefik|nodes|promtail|cadvisor|snmp-exporter|pihole-exporter|gitea|unpoller|postgres-exporter|redis-exporter|mysql-exporter|mongodb-exporter|github-profile|authentik|vikunja\"} == bool 0) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 15;
        type = "stat";
        title = "Core Alerts Firing";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 8;
          x = 16;
          y = 12;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            decimals = 0;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "red";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum(ALERTS{alertstate=\"firing\",severity=~\"warning|critical\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 16;
        type = "timeseries";
        title = "Core Target Up by Job";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 24;
          x = 0;
          y = 18;
        };
        fieldConfig = {
          defaults = {
            min = 0;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = null;
                }
                {
                  color = "green";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum by (job) (up{job=~\"prometheus|alertmanager|grafana|loki|traefik|nodes|promtail|cadvisor|snmp-exporter|pihole-exporter|gitea|unpoller|postgres-exporter|redis-exporter|mysql-exporter|mongodb-exporter|github-profile|authentik|vikunja\"})";
            legendFormat = "{{job}}";
            refId = "A";
          }
        ];
      }
    ];
  };
  edgeServiceReliabilityDashboardJson = builtins.toJSON {
    id = null;
    uid = "edge-service-reliability";
    title = "Edge Service Reliability";
    tags = ["homelab" "edge" "traefik" "availability"];
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
        title = "Edge Request Rate (req/s)";
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
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            unit = "reqps";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum(rate(traefik_service_requests_total{service!=\"noop@internal\"}[5m])) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 2;
        type = "stat";
        title = "Edge 5xx Rate (req/s)";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 6;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            unit = "reqps";
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "yellow";
                  value = 0.01;
                }
                {
                  color = "red";
                  value = 0.1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum(rate(traefik_service_requests_total{service!=\"noop@internal\",code=~\"5..\"}[5m])) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 3;
        type = "stat";
        title = "Services Receiving Traffic";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 12;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        targets = [
          {
            expr = "sum(sum by (service) (rate(traefik_service_requests_total{service!=\"noop@internal\"}[5m])) > bool 0) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 4;
        type = "stat";
        title = "Services with 5xx";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 18;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "red";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum(sum by (service) (rate(traefik_service_requests_total{service!=\"noop@internal\",code=~\"5..\"}[5m])) > bool 0) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 5;
        type = "timeseries";
        title = "Request Rate by Service (top 12)";
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
        fieldConfig = {
          defaults = {
            unit = "reqps";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "topk(12, sum by (service) (rate(traefik_service_requests_total{service!=\"noop@internal\"}[5m])))";
            legendFormat = "{{service}}";
            refId = "A";
          }
        ];
      }
      {
        id = 6;
        type = "timeseries";
        title = "5xx Rate by Service (top 12)";
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
        fieldConfig = {
          defaults = {
            unit = "reqps";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "topk(12, sum by (service) (rate(traefik_service_requests_total{service!=\"noop@internal\",code=~\"5..\"}[5m])))";
            legendFormat = "{{service}}";
            refId = "A";
          }
        ];
      }
      {
        id = 7;
        type = "timeseries";
        title = "5xx Percentage by Service (top 12)";
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
        fieldConfig = {
          defaults = {
            unit = "percent";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "topk(12, 100 * (sum by (service) (rate(traefik_service_requests_total{service!=\"noop@internal\",code=~\"5..\"}[5m])) / clamp_min(sum by (service) (rate(traefik_service_requests_total{service!=\"noop@internal\"}[5m])), 0.001)))";
            legendFormat = "{{service}}";
            refId = "A";
          }
        ];
      }
      {
        id = 8;
        type = "timeseries";
        title = "HTTP Response Codes (all services)";
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
        fieldConfig = {
          defaults = {
            unit = "reqps";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum by (code) (rate(traefik_service_requests_total{service!=\"noop@internal\"}[5m]))";
            legendFormat = "{{code}}";
            refId = "A";
          }
        ];
      }
      {
        id = 9;
        type = "timeseries";
        title = "Top Services by 4xx Rate";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 22;
        };
        fieldConfig = {
          defaults = {
            unit = "reqps";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "topk(10, sum by (service) (rate(traefik_service_requests_total{service!=\"noop@internal\",code=~\"4..\"}[5m])))";
            legendFormat = "{{service}}";
            refId = "A";
          }
        ];
      }
      {
        id = 10;
        type = "timeseries";
        title = "Total Traffic by Status Class";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 22;
        };
        fieldConfig = {
          defaults = {
            unit = "reqps";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum(rate(traefik_service_requests_total{service!=\"noop@internal\",code=~\"2..\"}[5m]))";
            legendFormat = "2xx";
            refId = "A";
          }
          {
            expr = "sum(rate(traefik_service_requests_total{service!=\"noop@internal\",code=~\"3..\"}[5m]))";
            legendFormat = "3xx";
            refId = "B";
          }
          {
            expr = "sum(rate(traefik_service_requests_total{service!=\"noop@internal\",code=~\"4..\"}[5m]))";
            legendFormat = "4xx";
            refId = "C";
          }
          {
            expr = "sum(rate(traefik_service_requests_total{service!=\"noop@internal\",code=~\"5..\"}[5m]))";
            legendFormat = "5xx";
            refId = "D";
          }
        ];
      }
    ];
  };
  alertingTriageDashboardJson = builtins.toJSON {
    id = null;
    uid = "alerting-triage";
    title = "Alerting Triage";
    tags = ["homelab" "alerts" "alertmanager" "operations"];
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
        title = "Firing Alerts";
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
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            decimals = 0;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "red";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum(ALERTS{alertstate=\"firing\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 2;
        type = "stat";
        title = "Pending Alerts";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 6;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            decimals = 0;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "yellow";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum(ALERTS{alertstate=\"pending\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 3;
        type = "stat";
        title = "Critical Alerts";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 12;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            decimals = 0;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "red";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum(ALERTS{alertstate=\"firing\",severity=\"critical\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 4;
        type = "stat";
        title = "Warning Alerts";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 18;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            decimals = 0;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "yellow";
                  value = 1;
                }
                {
                  color = "red";
                  value = 3;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum(ALERTS{alertstate=\"firing\",severity=\"warning\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 5;
        type = "bargauge";
        title = "Firing Alerts by Name";
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
        options = {
          orientation = "horizontal";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
          showUnfilled = true;
        };
        targets = [
          {
            expr = "sum by (alertname) (ALERTS{alertstate=\"firing\"}) or label_replace(vector(0), \"alertname\", \"none\", \"\", \"\")";
            legendFormat = "{{alertname}}";
            refId = "A";
          }
        ];
      }
      {
        id = 6;
        type = "timeseries";
        title = "Firing Alerts by Severity";
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
        fieldConfig = {
          defaults = {
            min = 0;
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum by (severity) (ALERTS{alertstate=\"firing\"})";
            legendFormat = "{{severity}}";
            refId = "A";
          }
        ];
      }
      {
        id = 7;
        type = "timeseries";
        title = "Top Firing Alert Instances";
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
        fieldConfig = {
          defaults = {
            min = 0;
          };
          overrides = [];
        };
        targets = [
          {
            expr = "topk(10, sum by (instance) (ALERTS{alertstate=\"firing\",instance!=\"\"}))";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
      }
      {
        id = 8;
        type = "timeseries";
        title = "Target Down by Job";
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
        fieldConfig = {
          defaults = {
            min = 0;
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum by (job) (up{job!=\"pihole-exporter\"} == bool 0)";
            legendFormat = "{{job}}";
            refId = "A";
          }
          {
            expr = "sum by (job) (up{job=\"pihole-exporter\"} == bool 0)";
            legendFormat = "{{job}}";
            refId = "B";
          }
        ];
      }
      {
        id = 9;
        type = "timeseries";
        title = "Alertmanager Notifications Sent/s";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 22;
        };
        fieldConfig = {
          defaults = {
            min = 0;
            unit = "ops";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum(rate(alertmanager_notifications_total{job=\"alertmanager\"}[5m])) or vector(0)";
            legendFormat = "sent";
            refId = "A";
          }
          {
            expr = "sum(rate(alertmanager_notifications_failed_total{job=\"alertmanager\"}[5m])) or vector(0)";
            legendFormat = "failed";
            refId = "B";
          }
        ];
      }
      {
        id = 10;
        type = "timeseries";
        title = "Prometheus Rule Evaluations / Failures";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 22;
        };
        fieldConfig = {
          defaults = {
            min = 0;
            unit = "ops";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum(rate(prometheus_rule_evaluations_total{job=\"prometheus\"}[5m])) or vector(0)";
            legendFormat = "evaluations";
            refId = "A";
          }
          {
            expr = "sum(rate(prometheus_rule_evaluation_failures_total{job=\"prometheus\"}[5m])) or vector(0)";
            legendFormat = "evaluation_failures";
            refId = "B";
          }
        ];
      }
    ];
  };
  logsPipelineDashboardJson = builtins.toJSON {
    id = null;
    uid = "logs-pipeline";
    title = "Logs Pipeline";
    tags = ["homelab" "logs" "loki" "promtail"];
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
        title = "Promtail Sent Entries/s";
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
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        targets = [
          {
            expr = "sum(rate(promtail_sent_entries_total[5m])) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 2;
        type = "stat";
        title = "Promtail Dropped Entries/s";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 6;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "red";
                  value = 0.001;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum(rate(promtail_dropped_entries_total[5m])) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 3;
        type = "stat";
        title = "Promtail Retry Rate/s";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 12;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "yellow";
                  value = 0.01;
                }
                {
                  color = "red";
                  value = 0.1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum(rate(promtail_batch_retries_total[5m])) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 4;
        type = "stat";
        title = "Loki Received Lines/s";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 18;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        targets = [
          {
            expr = "sum(rate(loki_distributor_lines_received_total[5m])) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 5;
        type = "timeseries";
        title = "Promtail Sent vs Dropped Entries/s";
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
            expr = "sum(rate(promtail_sent_entries_total[5m]))";
            legendFormat = "sent";
            refId = "A";
          }
          {
            expr = "sum(rate(promtail_dropped_entries_total[5m]))";
            legendFormat = "dropped";
            refId = "B";
          }
        ];
      }
      {
        id = 6;
        type = "timeseries";
        title = "Promtail Retry Rate/s";
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
            expr = "sum(rate(promtail_batch_retries_total[5m]))";
            legendFormat = "retries";
            refId = "A";
          }
        ];
      }
      {
        id = 7;
        type = "timeseries";
        title = "Promtail Push Request Duration p95";
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
        fieldConfig = {
          defaults = {
            unit = "s";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "histogram_quantile(0.95, sum(rate(promtail_request_duration_seconds_bucket[5m])) by (le))";
            legendFormat = "p95";
            refId = "A";
          }
        ];
      }
      {
        id = 8;
        type = "timeseries";
        title = "Loki Lines Received vs Discarded";
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
            expr = "sum(rate(loki_distributor_lines_received_total[5m]))";
            legendFormat = "received";
            refId = "A";
          }
          {
            expr = "sum(rate(loki_discarded_samples_total[5m]))";
            legendFormat = "discarded";
            refId = "B";
          }
        ];
      }
      {
        id = 9;
        type = "timeseries";
        title = "Gitea Log Volume (events/s)";
        datasource = {
          type = "loki";
          uid = "loki";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 22;
        };
        targets = [
          {
            expr = "sum(rate({job=\"synology-gitea\"}[5m])) or on() vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 10;
        type = "timeseries";
        title = "Gitea Error-like Logs (events/s)";
        datasource = {
          type = "loki";
          uid = "loki";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 22;
        };
        targets = [
          {
            expr = "sum(rate({job=\"synology-gitea\"} |~ \"(?i)(error|fatal|panic|exception|fail)\"[5m])) or on() vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 11;
        type = "logs";
        title = "Gitea Logs (Raw)";
        datasource = {
          type = "loki";
          uid = "loki";
        };
        gridPos = {
          h = 12;
          w = 24;
          x = 0;
          y = 30;
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
  smtpRelayOperationsDashboardJson = builtins.toJSON {
    id = null;
    uid = "smtp-relay-operations";
    title = "SMTP Relay Operations";
    tags = ["homelab" "smtp" "relay" "operations"];
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
        title = "SMTP Relay systemd Active";
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
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            min = 0;
            max = 1;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = null;
                }
                {
                  color = "green";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "max(node_systemd_unit_state{job=\"nodes\",name=\"smtp-relay.service\",state=\"active\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 2;
        type = "stat";
        title = "SMTP Relay Container Seen (last 2m)";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 6;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            min = 0;
            max = 1;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = null;
                }
                {
                  color = "green";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "max((time() - container_last_seen{job=\"cadvisor\",container_label_com_docker_compose_service=\"smtp-relay\"}) < bool 120) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 3;
        type = "stat";
        title = "SMTP Relay Alerts Firing";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 12;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "red";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum(ALERTS{alertname=~\"SmtpRelaySystemdDown|SmtpRelayContainerNotSeen\",alertstate=\"firing\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 4;
        type = "stat";
        title = "SMTP Relay CPU %";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 18;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            unit = "percent";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum(rate(container_cpu_usage_seconds_total{job=\"cadvisor\",container_label_com_docker_compose_service=\"smtp-relay\"}[5m])) * 100";
            refId = "A";
          }
        ];
      }
      {
        id = 5;
        type = "timeseries";
        title = "SMTP Relay CPU %";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 8;
          x = 0;
          y = 6;
        };
        fieldConfig = {
          defaults = {
            unit = "percent";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum(rate(container_cpu_usage_seconds_total{job=\"cadvisor\",container_label_com_docker_compose_service=\"smtp-relay\"}[5m])) * 100";
            refId = "A";
          }
        ];
      }
      {
        id = 6;
        type = "timeseries";
        title = "SMTP Relay Memory Working Set";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 8;
          x = 8;
          y = 6;
        };
        fieldConfig = {
          defaults = {
            unit = "bytes";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum(container_memory_working_set_bytes{job=\"cadvisor\",container_label_com_docker_compose_service=\"smtp-relay\"})";
            refId = "A";
          }
        ];
      }
      {
        id = 7;
        type = "timeseries";
        title = "SMTP Relay Network Throughput";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 8;
          x = 16;
          y = 6;
        };
        fieldConfig = {
          defaults = {
            unit = "Bps";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum(rate(container_network_receive_bytes_total{job=\"cadvisor\",container_label_com_docker_compose_service=\"smtp-relay\"}[5m]))";
            legendFormat = "rx";
            refId = "A";
          }
          {
            expr = "sum(rate(container_network_transmit_bytes_total{job=\"cadvisor\",container_label_com_docker_compose_service=\"smtp-relay\"}[5m]))";
            legendFormat = "tx";
            refId = "B";
          }
        ];
      }
      {
        id = 8;
        type = "timeseries";
        title = "SMTP Relay Conditions by Type";
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
        fieldConfig = {
          defaults = {
            min = 0;
            max = 1;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "red";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "(max(node_systemd_unit_state{job=\"nodes\",name=\"smtp-relay.service\",state=\"active\"}) or vector(0)) == bool 0";
            legendFormat = "systemd_inactive";
            refId = "A";
          }
          {
            expr = "(max((time() - container_last_seen{job=\"cadvisor\",container_label_com_docker_compose_service=\"smtp-relay\"}) < bool 120) or vector(0)) == bool 0";
            legendFormat = "container_not_seen";
            refId = "B";
          }
        ];
      }
      {
        id = 9;
        type = "timeseries";
        title = "SMTP Relay Alerts by Name";
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
        fieldConfig = {
          defaults = {
            min = 0;
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum by (alertname) (ALERTS{alertname=~\"SmtpRelaySystemdDown|SmtpRelayContainerNotSeen\",alertstate=\"firing\"}) or label_replace(vector(0), \"alertname\", \"none\", \"\", \"\")";
            legendFormat = "{{alertname}}";
            refId = "A";
          }
        ];
      }
      {
        id = 10;
        type = "timeseries";
        title = "SMTP Relay Condition Count";
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
        fieldConfig = {
          defaults = {
            min = 0;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "red";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "(((max(node_systemd_unit_state{job=\"nodes\",name=\"smtp-relay.service\",state=\"active\"}) or vector(0)) == bool 0) + ((max((time() - container_last_seen{job=\"cadvisor\",container_label_com_docker_compose_service=\"smtp-relay\"}) < bool 120) or vector(0)) == bool 0))";
            refId = "A";
          }
        ];
      }
    ];
  };
  serviceSliDashboardJson = builtins.toJSON {
    id = null;
    uid = "service-sli";
    title = "Service SLI";
    tags = ["homelab" "sli" "traefik" "reliability"];
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
        title = "Global Request Rate (req/s)";
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
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            unit = "reqps";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum(rate(traefik_service_requests_total{service!=\"noop@internal\"}[5m])) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 2;
        type = "stat";
        title = "Global Success % (non-5xx)";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 6;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            unit = "percent";
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = null;
                }
                {
                  color = "yellow";
                  value = 95;
                }
                {
                  color = "green";
                  value = 99;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "100 * (1 - ((sum(rate(traefik_service_requests_total{service!=\"noop@internal\",code=~\"5..\"}[5m])) or vector(0)) / clamp_min((sum(rate(traefik_service_requests_total{service!=\"noop@internal\"}[5m])) or vector(0)), 0.001)))";
            refId = "A";
          }
        ];
      }
      {
        id = 3;
        type = "stat";
        title = "Global 5xx %";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 12;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            unit = "percent";
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "yellow";
                  value = 0.1;
                }
                {
                  color = "red";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "100 * ((sum(rate(traefik_service_requests_total{service!=\"noop@internal\",code=~\"5..\"}[5m])) or vector(0)) / clamp_min((sum(rate(traefik_service_requests_total{service!=\"noop@internal\"}[5m])) or vector(0)), 0.001))";
            refId = "A";
          }
        ];
      }
      {
        id = 4;
        type = "stat";
        title = "Global p95 Latency";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 18;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            unit = "s";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "histogram_quantile(0.95, sum(rate(traefik_service_request_duration_seconds_bucket{service!=\"noop@internal\"}[5m])) by (le))";
            refId = "A";
          }
        ];
      }
      {
        id = 5;
        type = "timeseries";
        title = "Request Rate by Service (top 12)";
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
        fieldConfig = {
          defaults = {
            unit = "reqps";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "topk(12, sum by (service) (rate(traefik_service_requests_total{service!=\"noop@internal\"}[5m])))";
            legendFormat = "{{service}}";
            refId = "A";
          }
        ];
      }
      {
        id = 6;
        type = "timeseries";
        title = "Global Request Rate by Status Class";
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
        fieldConfig = {
          defaults = {
            unit = "reqps";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum(rate(traefik_service_requests_total{service!=\"noop@internal\",code=~\"2..\"}[5m]))";
            legendFormat = "2xx";
            refId = "A";
          }
          {
            expr = "sum(rate(traefik_service_requests_total{service!=\"noop@internal\",code=~\"3..\"}[5m]))";
            legendFormat = "3xx";
            refId = "B";
          }
          {
            expr = "sum(rate(traefik_service_requests_total{service!=\"noop@internal\",code=~\"4..\"}[5m]))";
            legendFormat = "4xx";
            refId = "C";
          }
          {
            expr = "sum(rate(traefik_service_requests_total{service!=\"noop@internal\",code=~\"5..\"}[5m]))";
            legendFormat = "5xx";
            refId = "D";
          }
        ];
      }
      {
        id = 9;
        type = "timeseries";
        title = "Global Success % / 5xx %";
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
        fieldConfig = {
          defaults = {
            unit = "percent";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "100 * (1 - ((sum(rate(traefik_service_requests_total{service!=\"noop@internal\",code=~\"5..\"}[5m])) or vector(0)) / clamp_min((sum(rate(traefik_service_requests_total{service!=\"noop@internal\"}[5m])) or vector(0)), 0.001)))";
            legendFormat = "success_pct";
            refId = "A";
          }
          {
            expr = "100 * ((sum(rate(traefik_service_requests_total{service!=\"noop@internal\",code=~\"5..\"}[5m])) or vector(0)) / clamp_min((sum(rate(traefik_service_requests_total{service!=\"noop@internal\"}[5m])) or vector(0)), 0.001))";
            legendFormat = "error_5xx_pct";
            refId = "B";
          }
        ];
      }
      {
        id = 10;
        type = "timeseries";
        title = "Global p95 Latency (top 12 services)";
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
        fieldConfig = {
          defaults = {
            unit = "s";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "topk(12, histogram_quantile(0.95, sum by (service, le) (rate(traefik_service_request_duration_seconds_bucket{service!=\"noop@internal\"}[5m]))))";
            legendFormat = "{{service}}";
            refId = "A";
          }
        ];
      }
    ];
  };
  piholeOperationsDashboardJson = builtins.toJSON {
    id = null;
    uid = "pihole-operations";
    title = "Pi-hole Operations";
    tags = ["homelab" "dns" "pihole"];
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
        title = "Pi-hole Exporter Targets Up";
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
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        targets = [
          {
            expr = "sum(up{job=\"pihole-exporter\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 2;
        type = "stat";
        title = "Pi-hole Status Up";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 6;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            min = 0;
            max = 1;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = null;
                }
                {
                  color = "green";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "avg(pihole_status) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 3;
        type = "stat";
        title = "Total Queries Today";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 12;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        targets = [
          {
            expr = "sum(pihole_dns_queries_today) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 4;
        type = "stat";
        title = "Ads Blocked % (avg)";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 18;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            unit = "percent";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "avg(pihole_ads_percentage_today) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 5;
        type = "timeseries";
        title = "Request Rate by Pi-hole";
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
        fieldConfig = {
          defaults = {
            unit = "reqps";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "max by (instance) (pihole_request_rate)";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
      }
      {
        id = 6;
        type = "timeseries";
        title = "Queries Cached vs Forwarded";
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
        fieldConfig = {
          defaults = {
            unit = "short";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum by (instance) (pihole_queries_cached)";
            legendFormat = "{{instance}} cached";
            refId = "A";
          }
          {
            expr = "sum by (instance) (pihole_queries_forwarded)";
            legendFormat = "{{instance}} forwarded";
            refId = "B";
          }
        ];
      }
      {
        id = 7;
        type = "timeseries";
        title = "Unique Clients / Domains";
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
            expr = "sum(pihole_unique_clients)";
            legendFormat = "unique_clients";
            refId = "A";
          }
          {
            expr = "sum(pihole_unique_domains)";
            legendFormat = "unique_domains";
            refId = "B";
          }
        ];
      }
      {
        id = 8;
        type = "timeseries";
        title = "Blocked Domains / Ads Blocked Today";
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
            expr = "sum(pihole_domains_being_blocked)";
            legendFormat = "domains_blocked";
            refId = "A";
          }
          {
            expr = "sum(pihole_ads_blocked_today)";
            legendFormat = "ads_blocked_today";
            refId = "B";
          }
        ];
      }
      {
        id = 9;
        type = "timeseries";
        title = "Upstream Response Time by Destination";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 22;
        };
        fieldConfig = {
          defaults = {
            unit = "ms";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "avg by (destination) (pihole_forward_destinations_responsetime)";
            legendFormat = "{{destination}}";
            refId = "A";
          }
        ];
      }
      {
        id = 10;
        type = "timeseries";
        title = "Upstream Response Variance by Destination";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 22;
        };
        targets = [
          {
            expr = "avg by (destination) (pihole_forward_destinations_responsevariance)";
            legendFormat = "{{destination}}";
            refId = "A";
          }
        ];
      }
    ];
  };
  synologySnmpOperationsDashboardJson = builtins.toJSON {
    id = null;
    uid = "synology-snmp-operations";
    title = "Synology SNMP Operations";
    tags = ["homelab" "synology" "snmp" "nas"];
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
        title = "SNMP Targets Up (all jobs)";
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
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        targets = [
          {
            expr = "sum(up{job=~\"synology-snmp|synology-snmp-system|synology-snmp-memory|synology-snmp-storage|synology-snmp-network|synology-snmp-load|synology-snmp-uptime\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 2;
        type = "stat";
        title = "CPU Usage %";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 6;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            unit = "percent";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "avg(100 - ssCpuIdle{job=\"synology-snmp-system\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 3;
        type = "stat";
        title = "Memory Available %";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 12;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            unit = "percent";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "avg(100 * (memAvailReal{job=\"synology-snmp-memory\"} / memTotalReal{job=\"synology-snmp-memory\"})) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 4;
        type = "stat";
        title = "Root Volume Used %";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 18;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            unit = "percent";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "avg(100 * (hrStorageUsed{job=\"synology-snmp-storage\",hrStorageDescr=\"/volume1\"} / hrStorageSize{job=\"synology-snmp-storage\",hrStorageDescr=\"/volume1\"})) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 5;
        type = "timeseries";
        title = "SNMP Job Up by Module";
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
        fieldConfig = {
          defaults = {
            min = 0;
            max = 1;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = null;
                }
                {
                  color = "green";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "max(up{job=\"synology-snmp\"}) or vector(0)";
            legendFormat = "synology-snmp";
            refId = "A";
          }
          {
            expr = "max(up{job=\"synology-snmp-system\"}) or vector(0)";
            legendFormat = "synology-snmp-system";
            refId = "B";
          }
          {
            expr = "max(up{job=\"synology-snmp-memory\"}) or vector(0)";
            legendFormat = "synology-snmp-memory";
            refId = "C";
          }
          {
            expr = "max(up{job=\"synology-snmp-storage\"}) or vector(0)";
            legendFormat = "synology-snmp-storage";
            refId = "D";
          }
          {
            expr = "max(up{job=\"synology-snmp-network\"}) or vector(0)";
            legendFormat = "synology-snmp-network";
            refId = "E";
          }
          {
            expr = "max(up{job=\"synology-snmp-load\"}) or vector(0)";
            legendFormat = "synology-snmp-load";
            refId = "F";
          }
          {
            expr = "max(up{job=\"synology-snmp-uptime\"}) or vector(0)";
            legendFormat = "synology-snmp-uptime";
            refId = "G";
          }
        ];
      }
      {
        id = 6;
        type = "timeseries";
        title = "CPU / Memory by Instance";
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
        fieldConfig = {
          defaults = {
            unit = "percent";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "100 - ssCpuIdle{job=\"synology-snmp-system\"}";
            legendFormat = "{{instance}} cpu_used";
            refId = "A";
          }
          {
            expr = "100 * (memAvailReal{job=\"synology-snmp-memory\"} / memTotalReal{job=\"synology-snmp-memory\"})";
            legendFormat = "{{instance}} mem_avail";
            refId = "B";
          }
        ];
      }
      {
        id = 7;
        type = "timeseries";
        title = "Disk Used % by Volume";
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
        fieldConfig = {
          defaults = {
            unit = "percent";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "100 * (hrStorageUsed{job=\"synology-snmp-storage\"} / hrStorageSize{job=\"synology-snmp-storage\"})";
            legendFormat = "{{instance}} {{hrStorageDescr}}";
            refId = "A";
          }
        ];
      }
      {
        id = 8;
        type = "timeseries";
        title = "Network Throughput (bytes/s)";
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
        fieldConfig = {
          defaults = {
            unit = "Bps";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum by (instance) (rate(ifHCInOctets{job=\"synology-snmp-network\",ifName!~\"lo|sit0\"}[5m]))";
            legendFormat = "{{instance}} rx";
            refId = "A";
          }
          {
            expr = "sum by (instance) (rate(ifHCOutOctets{job=\"synology-snmp-network\",ifName!~\"lo|sit0\"}[5m]))";
            legendFormat = "{{instance}} tx";
            refId = "B";
          }
        ];
      }
      {
        id = 9;
        type = "timeseries";
        title = "Load Average (1m) by Instance";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 22;
        };
        targets = [
          {
            expr = "laLoadFloat{job=\"synology-snmp-load\",laNames=\"Load-1\"}";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
      }
      {
        id = 10;
        type = "timeseries";
        title = "System Uptime (hours) by Instance";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 22;
        };
        targets = [
          {
            expr = "(hrSystemUptime{job=\"synology-snmp-uptime\"} / 100) / 3600";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
      }
    ];
  };
  githubProfileOperationsDashboardJson = builtins.toJSON {
    id = null;
    uid = "github-profile-operations";
    title = "GitHub Profile Operations";
    tags = ["homelab" "github" "profile" "operations"];
    timezone = "browser";
    schemaVersion = 39;
    version = 1;
    refresh = "30s";
    time = {
      from = "now-30d";
      to = "now";
    };
    editable = true;
    panels = [
      {
        id = 1;
        type = "stat";
        title = "Exporter Up";
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
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            min = 0;
            max = 1;
            mappings = [
              {
                type = "value";
                options = {
                  "0" = {
                    text = "DOWN";
                  };
                  "1" = {
                    text = "UP";
                  };
                };
              }
            ];
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = null;
                }
                {
                  color = "green";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "max(github_profile_up{job=\"github-profile\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 2;
        type = "stat";
        title = "Last Fetch Age (seconds)";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 6;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            min = 0;
            unit = "s";
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "orange";
                  value = 3600;
                }
                {
                  color = "red";
                  value = 7200;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "time() - max(github_profile_last_fetch_unixtime{job=\"github-profile\"})";
            refId = "A";
          }
        ];
      }
      {
        id = 3;
        type = "stat";
        title = "Followers";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 12;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        targets = [
          {
            expr = "max(github_profile_followers{job=\"github-profile\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 4;
        type = "stat";
        title = "Public Repositories";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 18;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        targets = [
          {
            expr = "max(github_profile_public_repos{job=\"github-profile\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 5;
        type = "timeseries";
        title = "Followers / Following / Public Repos";
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
        fieldConfig = {
          defaults = {
            min = 0;
            unit = "short";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "max by (username) (github_profile_followers{job=\"github-profile\"})";
            legendFormat = "{{username}} followers";
            refId = "A";
          }
          {
            expr = "max by (username) (github_profile_following{job=\"github-profile\"})";
            legendFormat = "{{username}} following";
            refId = "B";
          }
          {
            expr = "max by (username) (github_profile_public_repos{job=\"github-profile\"})";
            legendFormat = "{{username}} repos";
            refId = "C";
          }
        ];
      }
      {
        id = 6;
        type = "timeseries";
        title = "Stars / Forks / Watchers";
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
        fieldConfig = {
          defaults = {
            min = 0;
            unit = "short";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "max by (username) (github_profile_total_stars{job=\"github-profile\"})";
            legendFormat = "{{username}} stars";
            refId = "A";
          }
          {
            expr = "max by (username) (github_profile_total_forks{job=\"github-profile\"})";
            legendFormat = "{{username}} forks";
            refId = "B";
          }
          {
            expr = "max by (username) (github_profile_total_watchers{job=\"github-profile\"})";
            legendFormat = "{{username}} watchers";
            refId = "C";
          }
        ];
      }
      {
        id = 7;
        type = "timeseries";
        title = "Commit Counts (1d/7d/30d/365d)";
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
        fieldConfig = {
          defaults = {
            min = 0;
            unit = "short";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "max by (username) (github_profile_commits_1d{job=\"github-profile\"})";
            legendFormat = "{{username}} commits 1d";
            refId = "A";
          }
          {
            expr = "max by (username) (github_profile_commits_7d{job=\"github-profile\"})";
            legendFormat = "{{username}} commits 7d";
            refId = "B";
          }
          {
            expr = "max by (username) (github_profile_commits_30d{job=\"github-profile\"})";
            legendFormat = "{{username}} commits 30d";
            refId = "C";
          }
          {
            expr = "max by (username) (github_profile_commits_365d{job=\"github-profile\"})";
            legendFormat = "{{username}} commits 365d";
            refId = "D";
          }
        ];
      }
      {
        id = 8;
        type = "timeseries";
        title = "Commit Stats Backend Readiness";
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
        fieldConfig = {
          defaults = {
            min = 0;
            unit = "short";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "max by (username) (github_profile_commit_repos_ready{job=\"github-profile\"})";
            legendFormat = "{{username}} repos_ready";
            refId = "A";
          }
          {
            expr = "max by (username) (github_profile_commit_repos_pending{job=\"github-profile\"})";
            legendFormat = "{{username}} repos_pending";
            refId = "B";
          }
        ];
      }
    ];
  };
  applicationsReliabilityDashboardJson = builtins.toJSON {
    id = null;
    uid = "applications-reliability";
    title = "Applications Reliability";
    tags = ["homelab" "applications" "reliability" "sli"];
    timezone = "browser";
    schemaVersion = 39;
    version = 1;
    refresh = "30s";
    time = {
      from = "now-24h";
      to = "now";
    };
    editable = true;
    panels = [
      {
        id = 1;
        type = "stat";
        title = "Apps Receiving Traffic (15m)";
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
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            min = 0;
            decimals = 0;
            unit = "short";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum(sum by (service) (rate(traefik_service_requests_total{service=~\"authentik@docker|vikunja@docker|timetagger@docker|homepage@docker|ghost-blog@docker|uptime-kuma@docker|n8n@docker|woodpecker@docker|diagrams-net@docker|excalidraw@docker|owntracks-recorder@docker|traggo@docker|dozzle@docker|fossflow@docker|searxng@docker|d2@docker|paperless@docker\"}[15m])) > bool 0) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 2;
        type = "stat";
        title = "Services with 5xx (15m)";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 6;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            min = 0;
            decimals = 0;
            unit = "short";
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "orange";
                  value = 1;
                }
                {
                  color = "red";
                  value = 3;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum(sum by (service) (rate(traefik_service_requests_total{service=~\"authentik@docker|vikunja@docker|timetagger@docker|homepage@docker|ghost-blog@docker|uptime-kuma@docker|n8n@docker|woodpecker@docker|diagrams-net@docker|excalidraw@docker|owntracks-recorder@docker|traggo@docker|dozzle@docker|fossflow@docker|searxng@docker|d2@docker|paperless@docker\",code=~\"5..\"}[15m])) > bool 0) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 3;
        type = "stat";
        title = "App Success Rate % (5m)";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 12;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            min = 0;
            max = 100;
            unit = "percent";
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = null;
                }
                {
                  color = "orange";
                  value = 95;
                }
                {
                  color = "green";
                  value = 99;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "100 * (1 - ((sum(rate(traefik_service_requests_total{service=~\"authentik@docker|vikunja@docker|timetagger@docker|homepage@docker|ghost-blog@docker|uptime-kuma@docker|n8n@docker|woodpecker@docker|diagrams-net@docker|excalidraw@docker|owntracks-recorder@docker|traggo@docker|dozzle@docker|fossflow@docker|searxng@docker|d2@docker|paperless@docker\",code=~\"5..\"}[5m])) or vector(0)) / clamp_min((sum(rate(traefik_service_requests_total{service=~\"authentik@docker|vikunja@docker|timetagger@docker|homepage@docker|ghost-blog@docker|uptime-kuma@docker|n8n@docker|woodpecker@docker|diagrams-net@docker|excalidraw@docker|owntracks-recorder@docker|traggo@docker|dozzle@docker|fossflow@docker|searxng@docker|d2@docker|paperless@docker\"}[5m])) or vector(0)), 0.001)))";
            refId = "A";
          }
        ];
      }
      {
        id = 4;
        type = "stat";
        title = "App Alerts Firing";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 18;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            min = 0;
            decimals = 0;
            unit = "short";
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "orange";
                  value = 1;
                }
                {
                  color = "red";
                  value = 3;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum(ALERTS{alertname=~\"AppServiceHigh5xxRatio|AppServiceHighLatencyP95|AppContainerNotSeen\",alertstate=\"firing\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 5;
        type = "timeseries";
        title = "Request Rate by App Service (req/s)";
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
        fieldConfig = {
          defaults = {
            min = 0;
            unit = "reqps";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum by (service) (rate(traefik_service_requests_total{service=~\"authentik@docker|vikunja@docker|timetagger@docker|homepage@docker|ghost-blog@docker|uptime-kuma@docker|n8n@docker|woodpecker@docker|diagrams-net@docker|excalidraw@docker|owntracks-recorder@docker|traggo@docker|dozzle@docker|fossflow@docker|searxng@docker|d2@docker|paperless@docker\"}[5m]))";
            legendFormat = "{{service}}";
            refId = "A";
          }
        ];
      }
      {
        id = 7;
        type = "timeseries";
        title = "5xx Percentage by App Service";
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
        fieldConfig = {
          defaults = {
            min = 0;
            max = 100;
            unit = "percent";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "100 * (sum by (service) (rate(traefik_service_requests_total{service=~\"authentik@docker|vikunja@docker|timetagger@docker|homepage@docker|ghost-blog@docker|uptime-kuma@docker|n8n@docker|woodpecker@docker|diagrams-net@docker|excalidraw@docker|owntracks-recorder@docker|traggo@docker|dozzle@docker|fossflow@docker|searxng@docker|d2@docker|paperless@docker\",code=~\"5..\"}[5m])) / clamp_min(sum by (service) (rate(traefik_service_requests_total{service=~\"authentik@docker|vikunja@docker|timetagger@docker|homepage@docker|ghost-blog@docker|uptime-kuma@docker|n8n@docker|woodpecker@docker|diagrams-net@docker|excalidraw@docker|owntracks-recorder@docker|traggo@docker|dozzle@docker|fossflow@docker|searxng@docker|d2@docker|paperless@docker\"}[5m])), 0.001))";
            legendFormat = "{{service}}";
            refId = "A";
          }
        ];
      }
      {
        id = 8;
        type = "timeseries";
        title = "P95 Request Duration by App Service";
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
        fieldConfig = {
          defaults = {
            min = 0;
            unit = "s";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "histogram_quantile(0.95, sum by (service, le) (rate(traefik_service_request_duration_seconds_bucket{service=~\"authentik@docker|vikunja@docker|timetagger@docker|homepage@docker|ghost-blog@docker|uptime-kuma@docker|n8n@docker|woodpecker@docker|diagrams-net@docker|excalidraw@docker|owntracks-recorder@docker|traggo@docker|dozzle@docker|fossflow@docker|searxng@docker|d2@docker|paperless@docker\"}[5m])))";
            legendFormat = "{{service}}";
            refId = "A";
          }
        ];
      }
      {
        id = 9;
        type = "timeseries";
        title = "Application Container Seen Status";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 22;
        };
        fieldConfig = {
          defaults = {
            min = 0;
            max = 1;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = null;
                }
                {
                  color = "green";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "max by (container_label_com_docker_compose_service) ((time() - container_last_seen{job=\"cadvisor\",container_label_com_docker_compose_service=~\"authentik-server|authentik-worker|vikunja|timetagger|homepage|uptime-kuma|n8n|diagrams-net|excalidraw|owntracks-recorder|traggo|dozzle|fossflow|searxng|d2\"}) < bool 180)";
            legendFormat = "{{container_label_com_docker_compose_service}}";
            refId = "A";
          }
        ];
      }
      {
        id = 10;
        type = "timeseries";
        title = "App Alerts by Name";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 22;
        };
        fieldConfig = {
          defaults = {
            min = 0;
            unit = "short";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum by (alertname) (ALERTS{alertname=~\"AppServiceHigh5xxRatio|AppServiceHighLatencyP95|AppContainerNotSeen\",alertstate=\"firing\"}) or label_replace(vector(0), \"alertname\", \"none\", \"\", \"\")";
            legendFormat = "{{alertname}}";
            refId = "A";
          }
        ];
      }
    ];
  };
  appInternalsDashboardJson = builtins.toJSON {
    id = null;
    uid = "app-internals";
    title = "App Internals";
    tags = ["homelab" "applications" "internals" "authentik" "vikunja"];
    timezone = "browser";
    schemaVersion = 39;
    version = 1;
    refresh = "30s";
    time = {
      from = "now-24h";
      to = "now";
    };
    editable = true;
    panels = [
      {
        id = 1;
        type = "stat";
        title = "Authentik Request Rate";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 4;
          x = 0;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            min = 0;
            decimals = 2;
            unit = "reqps";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum(rate(django_http_responses_total_by_status_total{job=\"authentik\"}[5m])) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 2;
        type = "stat";
        title = "Authentik Auth Failure Ratio";
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
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            min = 0;
            max = 100;
            decimals = 1;
            unit = "percent";
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "orange";
                  value = 5;
                }
                {
                  color = "red";
                  value = 20;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "100 * ((sum(rate(django_http_responses_total_by_status_total{job=\"authentik\",status=~\"401|403\"}[5m])) or vector(0)) / clamp_min((sum(rate(django_http_responses_total_by_status_total{job=\"authentik\"}[5m])) or vector(0)), 0.01))";
            refId = "A";
          }
        ];
      }
      {
        id = 3;
        type = "stat";
        title = "Authentik Queue Depth";
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
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            min = 0;
            decimals = 0;
            unit = "short";
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = null;
                }
                {
                  color = "green";
                  value = 0;
                }
                {
                  color = "orange";
                  value = 10;
                }
                {
                  color = "red";
                  value = 25;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum(max by (actor_name, queue_name, instance) (authentik_tasks_queued{job=\"authentik\"})) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 4;
        type = "stat";
        title = "Authentik Tasks In Progress";
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
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            min = 0;
            decimals = 0;
            unit = "short";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum(max by (actor_name, queue_name, instance) (authentik_tasks_in_progress{job=\"authentik\"})) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 5;
        type = "stat";
        title = "Vikunja Event Throughput";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 4;
          x = 16;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            min = 0;
            decimals = 2;
            unit = "ops";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum(rate(handler_execution_time_seconds_count{job=\"vikunja\"}[5m])) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 6;
        type = "stat";
        title = "Vikunja Failed Event Ratio";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 4;
          x = 20;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            min = 0;
            max = 100;
            decimals = 1;
            unit = "percent";
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "orange";
                  value = 2;
                }
                {
                  color = "red";
                  value = 10;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "100 * ((sum(rate(handler_execution_time_seconds_count{job=\"vikunja\",success!=\"true\"}[5m])) or vector(0)) / clamp_min((sum(rate(handler_execution_time_seconds_count{job=\"vikunja\"}[5m])) or vector(0)), 0.01))";
            refId = "A";
          }
        ];
      }
      {
        id = 7;
        type = "timeseries";
        title = "Authentik Responses by Status";
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
        fieldConfig = {
          defaults = {
            min = 0;
            unit = "reqps";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum by (status) (rate(django_http_responses_total_by_status_total{job=\"authentik\"}[5m]))";
            legendFormat = "{{status}}";
            refId = "A";
          }
        ];
      }
      {
        id = 8;
        type = "timeseries";
        title = "Authentik Request Duration P95";
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
        fieldConfig = {
          defaults = {
            min = 0;
            unit = "s";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "histogram_quantile(0.95, sum by (le) (rate(django_http_requests_latency_including_middlewares_seconds_bucket{job=\"authentik\"}[5m]))) and on() (sum(rate(django_http_requests_latency_including_middlewares_seconds_count{job=\"authentik\"}[5m])) > 0)";
            legendFormat = "p95";
            refId = "A";
          }
        ];
      }
      {
        id = 9;
        type = "timeseries";
        title = "Authentik Task Queue by Queue";
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
        fieldConfig = {
          defaults = {
            min = 0;
            unit = "short";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum by (queue_name) (max by (actor_name, queue_name, instance) (authentik_tasks_queued{job=\"authentik\"}))";
            legendFormat = "{{queue_name}}";
            refId = "A";
          }
          {
            expr = "topk(8, max by (actor_name) (authentik_tasks_queued{job=\"authentik\"}))";
            legendFormat = "{{actor_name}}";
            refId = "B";
          }
        ];
      }
      {
        id = 10;
        type = "timeseries";
        title = "Vikunja Handler Duration P95";
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
        fieldConfig = {
          defaults = {
            min = 0;
            unit = "s";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "topk(8, histogram_quantile(0.95, sum by (handler_name, le) (rate(handler_execution_time_seconds_bucket{job=\"vikunja\"}[5m]))) and on(handler_name) (sum by (handler_name) (rate(handler_execution_time_seconds_count{job=\"vikunja\"}[5m])) > 0))";
            legendFormat = "{{handler_name}}";
            refId = "A";
          }
        ];
      }
      {
        id = 11;
        type = "timeseries";
        title = "Vikunja Handler Event Rate";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 22;
        };
        fieldConfig = {
          defaults = {
            min = 0;
            unit = "ops";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "topk(8, sum by (handler_name) (rate(handler_execution_time_seconds_count{job=\"vikunja\"}[5m])))";
            legendFormat = "{{handler_name}}";
            refId = "A";
          }
          {
            expr = "sum(rate(subscriber_messages_received_total{job=\"vikunja\"}[5m])) or vector(0)";
            legendFormat = "subscriber throughput";
            refId = "B";
          }
        ];
      }
      {
        id = 12;
        type = "timeseries";
        title = "Vikunja Domain Object Counts";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 22;
        };
        fieldConfig = {
          defaults = {
            min = 0;
            unit = "short";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "vikunja_task_count{job=\"vikunja\"} or vector(0)";
            legendFormat = "tasks";
            refId = "A";
          }
          {
            expr = "vikunja_project_count{job=\"vikunja\"} or vector(0)";
            legendFormat = "projects";
            refId = "B";
          }
          {
            expr = "vikunja_active_users{job=\"vikunja\"} or vector(0)";
            legendFormat = "active users";
            refId = "C";
          }
          {
            expr = "vikunja_user_count{job=\"vikunja\"} or vector(0)";
            legendFormat = "users";
            refId = "D";
          }
          {
            expr = "vikunja_team_count{job=\"vikunja\"} or vector(0)";
            legendFormat = "teams";
            refId = "E";
          }
        ];
      }
    ];
  };
  homeAssistantOperationsDashboardJson = builtins.toJSON {
    id = null;
    uid = "home-assistant-operations";
    title = "Home Assistant Operations";
    tags = ["homelab" "home-assistant" "operations" "reliability"];
    timezone = "browser";
    schemaVersion = 39;
    version = 1;
    refresh = "30s";
    time = {
      from = "now-24h";
      to = "now";
    };
    editable = true;
    panels = [
      {
        id = 1;
        type = "stat";
        title = "HA Request Rate";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 4;
          x = 0;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            min = 0;
            decimals = 2;
            unit = "reqps";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum(rate(traefik_service_requests_total{service=\"homeassistant@docker\"}[5m])) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 2;
        type = "stat";
        title = "HA 5xx Ratio";
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
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            min = 0;
            max = 100;
            decimals = 2;
            unit = "percent";
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "orange";
                  value = 1;
                }
                {
                  color = "red";
                  value = 5;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "100 * ((sum(rate(traefik_service_requests_total{service=\"homeassistant@docker\",code=~\"5..\"}[5m])) or vector(0)) / clamp_min((sum(rate(traefik_service_requests_total{service=\"homeassistant@docker\"}[5m])) or vector(0)), 0.01))";
            refId = "A";
          }
        ];
      }
      {
        id = 3;
        type = "stat";
        title = "HA P95 Request Duration";
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
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            min = 0;
            unit = "s";
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "orange";
                  value = 0.5;
                }
                {
                  color = "red";
                  value = 2;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "histogram_quantile(0.95, sum by (le) (rate(traefik_service_request_duration_seconds_bucket{service=\"homeassistant@docker\"}[5m]))) and on() (sum(rate(traefik_service_requests_total{service=\"homeassistant@docker\"}[5m])) > 0)";
            refId = "A";
          }
        ];
      }
      {
        id = 4;
        type = "stat";
        title = "HA Container Seen";
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
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            min = 0;
            max = 1;
            mappings = [
              {
                type = "value";
                options = {
                  "0" = {
                    text = "NOT SEEN";
                  };
                  "1" = {
                    text = "SEEN";
                  };
                };
              }
            ];
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = null;
                }
                {
                  color = "green";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "max((time() - container_last_seen{job=\"cadvisor\",container_label_com_docker_compose_service=\"home-assistant\"}) < bool 180) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 5;
        type = "stat";
        title = "HA systemd Active";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 4;
          x = 16;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            min = 0;
            max = 1;
            mappings = [
              {
                type = "value";
                options = {
                  "0" = {
                    text = "INACTIVE";
                  };
                  "1" = {
                    text = "ACTIVE";
                  };
                };
              }
            ];
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = null;
                }
                {
                  color = "green";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "max(node_systemd_unit_state{job=\"nodes\",name=\"home-assistant.service\",state=\"active\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 6;
        type = "stat";
        title = "Recorder DB Up";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 4;
          x = 20;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            min = 0;
            max = 1;
            mappings = [
              {
                type = "value";
                options = {
                  "0" = {
                    text = "DOWN";
                  };
                  "1" = {
                    text = "UP";
                  };
                };
              }
            ];
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = null;
                }
                {
                  color = "green";
                  value = 1;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "max(pg_up{job=\"postgres-exporter\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 7;
        type = "timeseries";
        title = "HA Requests by Status Code";
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
        fieldConfig = {
          defaults = {
            min = 0;
            unit = "reqps";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum by (code) (rate(traefik_service_requests_total{service=\"homeassistant@docker\"}[5m]))";
            legendFormat = "{{code}}";
            refId = "A";
          }
        ];
      }
      {
        id = 8;
        type = "timeseries";
        title = "HA 5xx Rate";
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
        fieldConfig = {
          defaults = {
            min = 0;
            unit = "reqps";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum by (code) (rate(traefik_service_requests_total{service=\"homeassistant@docker\",code=~\"5..\"}[5m]))";
            legendFormat = "{{code}}";
            refId = "A";
          }
        ];
      }
      {
        id = 9;
        type = "timeseries";
        title = "HA Latency (P50/P95)";
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
        fieldConfig = {
          defaults = {
            min = 0;
            unit = "s";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "histogram_quantile(0.50, sum by (le) (rate(traefik_service_request_duration_seconds_bucket{service=\"homeassistant@docker\"}[5m]))) and on() (sum(rate(traefik_service_requests_total{service=\"homeassistant@docker\"}[5m])) > 0)";
            legendFormat = "p50";
            refId = "A";
          }
          {
            expr = "histogram_quantile(0.95, sum by (le) (rate(traefik_service_request_duration_seconds_bucket{service=\"homeassistant@docker\"}[5m]))) and on() (sum(rate(traefik_service_requests_total{service=\"homeassistant@docker\"}[5m])) > 0)";
            legendFormat = "p95";
            refId = "B";
          }
        ];
      }
      {
        id = 10;
        type = "timeseries";
        title = "HA Container CPU / Memory";
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
        fieldConfig = {
          defaults = {
            min = 0;
            unit = "short";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum(rate(container_cpu_usage_seconds_total{job=\"cadvisor\",container_label_com_docker_compose_service=\"home-assistant\"}[5m]))";
            legendFormat = "cpu cores";
            refId = "A";
          }
          {
            expr = "max(container_memory_working_set_bytes{job=\"cadvisor\",container_label_com_docker_compose_service=\"home-assistant\"})";
            legendFormat = "memory working set";
            refId = "B";
          }
        ];
      }
      {
        id = 11;
        type = "stat";
        title = "HA Alerts Firing";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 22;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        fieldConfig = {
          defaults = {
            min = 0;
            decimals = 0;
            unit = "short";
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "orange";
                  value = 1;
                }
                {
                  color = "red";
                  value = 2;
                }
              ];
            };
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum(ALERTS{alertname=~\"HomeAssistantHigh5xxRatio|HomeAssistantHighLatencyP95|HomeAssistantSystemdDown|HomeAssistantRecorderRollbackRatioHigh|HomeAssistantRecorderConnectionsHigh\",alertstate=\"firing\"}) or vector(0)";
            refId = "A";
          }
        ];
      }
      {
        id = 12;
        type = "timeseries";
        title = "HA Alerts by Name";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 22;
        };
        fieldConfig = {
          defaults = {
            min = 0;
            unit = "short";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "sum by (alertname) (ALERTS{alertname=~\"HomeAssistantHigh5xxRatio|HomeAssistantHighLatencyP95|HomeAssistantSystemdDown|HomeAssistantRecorderRollbackRatioHigh|HomeAssistantRecorderConnectionsHigh\",alertstate=\"firing\"}) or label_replace(vector(0), \"alertname\", \"none\", \"\", \"\")";
            legendFormat = "{{alertname}}";
            refId = "A";
          }
        ];
      }
      {
        id = 13;
        type = "timeseries";
        title = "Recorder DB Connections";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 8;
          x = 0;
          y = 30;
        };
        fieldConfig = {
          defaults = {
            min = 0;
            unit = "short";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "max(pg_stat_database_numbackends{job=\"postgres-exporter\",datname=\"homeassistant\"}) or vector(0)";
            legendFormat = "homeassistant";
            refId = "A";
          }
        ];
      }
      {
        id = 14;
        type = "timeseries";
        title = "Recorder DB Commit/Rollback Rate";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 8;
          x = 8;
          y = 30;
        };
        fieldConfig = {
          defaults = {
            min = 0;
            unit = "ops";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "rate(pg_stat_database_xact_commit{job=\"postgres-exporter\",datname=\"homeassistant\"}[5m]) or vector(0)";
            legendFormat = "commit/s";
            refId = "A";
          }
          {
            expr = "rate(pg_stat_database_xact_rollback{job=\"postgres-exporter\",datname=\"homeassistant\"}[5m]) or vector(0)";
            legendFormat = "rollback/s";
            refId = "B";
          }
        ];
      }
      {
        id = 15;
        type = "timeseries";
        title = "Recorder DB Cache Hit Ratio";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 8;
          x = 16;
          y = 30;
        };
        fieldConfig = {
          defaults = {
            min = 0;
            max = 100;
            unit = "percent";
          };
          overrides = [];
        };
        targets = [
          {
            expr = "100 * ((rate(pg_stat_database_blks_hit{job=\"postgres-exporter\",datname=\"homeassistant\"}[5m]) or vector(0)) / clamp_min(((rate(pg_stat_database_blks_hit{job=\"postgres-exporter\",datname=\"homeassistant\"}[5m]) or vector(0)) + (rate(pg_stat_database_blks_read{job=\"postgres-exporter\",datname=\"homeassistant\"}[5m]) or vector(0))), 0.01))";
            legendFormat = "cache hit %";
            refId = "A";
          }
        ];
      }
    ];
  };
  unifiOverviewDashboardJson = builtins.toJSON {
    id = null;
    uid = "unifi-overview";
    title = "UniFi Overview";
    tags = ["homelab" "unifi" "network"];
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
        title = "Connected Clients";
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
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        targets = [
          {
            expr = "sum(unpoller_site_stations{job=\"unpoller\"})";
            refId = "A";
          }
        ];
      }
      {
        id = 2;
        type = "stat";
        title = "Gateways";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 6;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        targets = [
          {
            expr = "sum(unpoller_site_gateways{job=\"unpoller\"})";
            refId = "A";
          }
        ];
      }
      {
        id = 3;
        type = "stat";
        title = "Access Points";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 12;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        targets = [
          {
            expr = "sum(unpoller_site_aps{job=\"unpoller\"})";
            refId = "A";
          }
        ];
      }
      {
        id = 4;
        type = "stat";
        title = "Switches";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 18;
          y = 0;
        };
        options = {
          colorMode = "value";
          graphMode = "none";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        targets = [
          {
            expr = "sum(unpoller_site_switches{job=\"unpoller\"})";
            refId = "A";
          }
        ];
      }
      {
        id = 5;
        type = "timeseries";
        title = "UCG WAN Throughput (bytes/s)";
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
            expr = "sum by (name, port) (unpoller_device_wan_receive_rate_bytes{job=\"unpoller\",type=\"udm\"})";
            legendFormat = "{{name}} {{port}} rx";
            refId = "A";
          }
          {
            expr = "sum by (name, port) (unpoller_device_wan_transmit_rate_bytes{job=\"unpoller\",type=\"udm\"})";
            legendFormat = "{{name}} {{port}} tx";
            refId = "B";
          }
        ];
      }
      {
        id = 6;
        type = "timeseries";
        title = "UCG CPU / Memory (%)";
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
            expr = "100 * unpoller_device_cpu_utilization_ratio{job=\"unpoller\",type=\"udm\"}";
            legendFormat = "{{name}} cpu";
            refId = "A";
          }
          {
            expr = "100 * unpoller_device_memory_utilization_ratio{job=\"unpoller\",type=\"udm\"}";
            legendFormat = "{{name}} memory";
            refId = "B";
          }
        ];
      }
      {
        id = 7;
        type = "timeseries";
        title = "UCG Temperature (C)";
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
            expr = "unpoller_device_temperature_celsius{job=\"unpoller\",type=\"udm\"}";
            legendFormat = "{{name}}";
            refId = "A";
          }
        ];
      }
      {
        id = 8;
        type = "timeseries";
        title = "AP Connected Stations";
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
            expr = "sum by (name) (unpoller_device_stations{job=\"unpoller\",type=\"uap\"})";
            legendFormat = "{{name}}";
            refId = "A";
          }
        ];
      }
      {
        id = 9;
        type = "timeseries";
        title = "AP Avg Client Signal (dBm)";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 22;
        };
        targets = [
          {
            expr = "avg by (name) (unpoller_device_vap_average_client_signal{job=\"unpoller\"})";
            legendFormat = "{{name}}";
            refId = "A";
          }
        ];
      }
      {
        id = 10;
        type = "timeseries";
        title = "Top Clients by Throughput (bytes/s)";
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 22;
        };
        targets = [
          {
            expr = "topk(10, unpoller_client_receive_rate_bytes{job=\"unpoller\"} + unpoller_client_transmit_rate_bytes{job=\"unpoller\"})";
            legendFormat = "{{name}} {{mac}}";
            refId = "A";
          }
        ];
      }
    ];
  };
}
