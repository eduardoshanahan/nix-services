{lib, ...}: {
  options.services.prometheusCompose = {
    enable = lib.mkEnableOption "Prometheus service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "prometheus";
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
      default = "/var/lib/prometheus";
      description = "Persistent host path used for Prometheus TSDB data.";
    };

    retentionTime = lib.mkOption {
      type = lib.types.str;
      default = "30d";
      description = "Prometheus TSDB retention time (for example `30d`).";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "prom/prometheus";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "v2.55.1";
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

    scrape = {
      nodeTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["node-a.internal.example:9100" "node-b.internal.example:9100"];
        description = "Node exporter targets (`host:port`).";
      };

      synologyNodeTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["nas-a.internal.example:9100"];
        description = ''
          Synology NAS node-exporter targets (`host:port`), scraped under job
          `synology-nodes`.
        '';
      };

      synologySnmpTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["nas-a.internal.example" "nas-b.internal.example"];
        description = ''
          Synology SNMP device targets (`host` or `host:port`), scraped under
          job `synology-snmp`.
        '';
      };

      synologySnmpExporterAddress = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "snmp-exporter.internal.example:9116";
        description = ''
          SNMP exporter endpoint (`host:port`) used to scrape
          `services.prometheusCompose.scrape.synologySnmpTargets` via `/snmp`.
          When null, targets are scraped directly as generic Prometheus
          endpoints for backward compatibility.
        '';
      };

      synologySnmpModule = lib.mkOption {
        type = lib.types.str;
        default = "synology";
        example = "synology";
        description = "SNMP exporter module used for Synology SNMP scrape requests.";
      };

      synologySnmpAuth = lib.mkOption {
        type = lib.types.str;
        default = "public_v2";
        example = "public_v2";
        description = "SNMP exporter auth profile used for Synology SNMP scrape requests.";
      };

      synologySnmpSystemTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["nas-b.internal.example"];
        description = ''
          Synology SNMP targets scraped under job `synology-snmp-system` for
          CPU/system metrics (for example `ssCpuIdle`).
        '';
      };

      synologySnmpSystemModule = lib.mkOption {
        type = lib.types.str;
        default = "ucd_system_stats";
        example = "ucd_system_stats";
        description = "SNMP exporter module used for `synology-snmp-system`.";
      };

      synologySnmpMemoryTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["nas-b.internal.example"];
        description = ''
          Synology SNMP targets scraped under job `synology-snmp-memory` for
          memory metrics (for example `memTotalReal`, `memAvailReal`).
        '';
      };

      synologySnmpMemoryModule = lib.mkOption {
        type = lib.types.str;
        default = "ucd_memory";
        example = "ucd_memory";
        description = "SNMP exporter module used for `synology-snmp-memory`.";
      };

      synologySnmpStorageTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["nas-b.internal.example"];
        description = ''
          Synology SNMP targets scraped under job `synology-snmp-storage` for
          filesystem metrics (for example `hrStorageUsed`, `hrStorageSize`).
        '';
      };

      synologySnmpStorageModule = lib.mkOption {
        type = lib.types.str;
        default = "hrStorage";
        example = "hrStorage";
        description = "SNMP exporter module used for `synology-snmp-storage`.";
      };

      synologySnmpNetworkTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["nas-b.internal.example"];
        description = ''
          Synology SNMP targets scraped under job `synology-snmp-network` for
          interface throughput metrics (for example `ifHCInOctets`).
        '';
      };

      synologySnmpNetworkModule = lib.mkOption {
        type = lib.types.str;
        default = "if_mib";
        example = "if_mib";
        description = "SNMP exporter module used for `synology-snmp-network`.";
      };

      synologySnmpLoadTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["nas-b.internal.example"];
        description = ''
          Synology SNMP targets scraped under job `synology-snmp-load` for load
          average metrics (for example `laLoadFloat`).
        '';
      };

      synologySnmpLoadModule = lib.mkOption {
        type = lib.types.str;
        default = "ucd_la_table";
        example = "ucd_la_table";
        description = "SNMP exporter module used for `synology-snmp-load`.";
      };

      synologySnmpUptimeTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["nas-b.internal.example"];
        description = ''
          Synology SNMP targets scraped under job `synology-snmp-uptime` for
          uptime metrics (for example `hrSystemUptime`).
        '';
      };

      synologySnmpUptimeModule = lib.mkOption {
        type = lib.types.str;
        default = "hrSystem";
        example = "hrSystem";
        description = "SNMP exporter module used for `synology-snmp-uptime`.";
      };

      lokiTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["loki.internal.example:3100"];
        description = "Loki targets (`host:port`) to scrape.";
      };

      traefikTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["node-a-metrics.internal.example:8082" "node-b-metrics.internal.example:8082"];
        description = "Traefik metrics targets (`host:port`) to scrape.";
      };

      promtailTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["node-a.internal.example:9080" "node-b.internal.example:9080"];
        description = "Promtail targets (`host:port`) to scrape.";
      };

      snmpExporterTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["rpi-box-02-metrics.internal.example:9116"];
        description = "SNMP exporter targets (`host:port`) to scrape.";
      };

      postgresExporterTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["rpi-box-02-metrics.internal.example:9187"];
        description = "PostgreSQL exporter targets (`host:port`) to scrape.";
      };

      redisExporterTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["rpi-box-02-metrics.internal.example:9121"];
        description = "Redis exporter targets (`host:port`) to scrape.";
      };

      mysqlExporterTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["rpi-box-02-metrics.internal.example:9104"];
        description = "MySQL exporter targets (`host:port`) to scrape.";
      };

      mongodbExporterTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["rpi-box-02-metrics.internal.example:9216"];
        description = "MongoDB exporter targets (`host:port`) to scrape.";
      };

      doltTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["dolt.internal.example:11228"];
        description = "Dolt metrics targets (`host:port`) to scrape.";
      };

      piholeExporterTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["dns-node.internal.example:9617"];
        description = "Pi-hole exporter targets (`host:port`) to scrape.";
      };

      piholeExporterScrapeInterval = lib.mkOption {
        type = lib.types.str;
        default = "30s";
        example = "30s";
        description = "Scrape interval for job `pihole-exporter`.";
      };

      piholeExporterScrapeTimeout = lib.mkOption {
        type = lib.types.str;
        default = "25s";
        example = "25s";
        description = "Scrape timeout for job `pihole-exporter`.";
      };

      cadvisorTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["rpi-box-01-metrics.internal.example:8081"];
        description = "cAdvisor targets (`host:port`) to scrape.";
      };

      unpollerTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["rpi-box-02.internal.example:9130"];
        description = "UniFi Poller (unpoller) targets (`host:port`) to scrape.";
      };

      giteaTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["gitea.internal.example:3000"];
        description = "Gitea metrics targets (`host:port`) to scrape.";
      };

      githubProfileTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["rpi-box-02-metrics.internal.example:9145"];
        description = "GitHub profile exporter targets (`host:port`) to scrape.";
      };

      authentikTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["authentik-server:9300" "authentik-worker:9300"];
        description = "Authentik metrics targets (`host:port`) to scrape.";
      };

      authentikMetricsPath = lib.mkOption {
        type = lib.types.str;
        default = "/metrics";
        example = "/metrics";
        description = "Metrics path for job `authentik`.";
      };

      vikunjaTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["vikunja:3456"];
        description = "Vikunja metrics targets (`host:port`) to scrape.";
      };

      vikunjaMetricsPath = lib.mkOption {
        type = lib.types.str;
        default = "/api/v1/metrics";
        example = "/api/v1/metrics";
        description = "Metrics path for job `vikunja`.";
      };

      grafanaTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["grafana:3000"];
        description = "Grafana metrics targets (`host:port`) to scrape.";
      };

      alertmanagerTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["alertmanager:9093"];
        description = "Alertmanager targets (`host:port`) to scrape.";
      };
    };

    alerting = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Alertmanager integration in Prometheus config.";
      };

      targets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["alertmanager:9093"];
        description = "Alertmanager targets (`host:port`) used under `alerting.alertmanagers`.";
      };
    };

    tls = lib.mkEnableOption "TLS on the Prometheus Traefik router";
  };
}
