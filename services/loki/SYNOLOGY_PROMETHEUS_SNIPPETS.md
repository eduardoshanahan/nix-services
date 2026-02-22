# Synology Prometheus Snippets For Loki

Use these snippets in your Synology Prometheus config to monitor Loki and the Pi nodes.

## Scrape configs

Add to `prometheus.yml` under `scrape_configs`:

```yaml
  - job_name: "loki"
    static_configs:
      - targets: ["loki.<homelab-domain>:3100"]

  - job_name: "pis-node-exporter"
    static_configs:
      - targets:
          - "rpi-box-01.<homelab-domain>:9100"
          - "rpi-box-02.<homelab-domain>:9100"
          - "rpi-box-03.<homelab-domain>:9100"
```

## Alert rules

Add to `alert.rules.yml`:

```yaml
  - name: loki
    rules:
      - alert: LokiDown
        expr: up{job="loki"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Loki is down"
          description: "Prometheus cannot scrape Loki at {{ $labels.instance }}."

      - alert: LokiDiskFillingUp
        expr: |
          (
            node_filesystem_avail_bytes{instance="rpi-box-03.<homelab-domain>:9100",mountpoint="/srv/loki",fstype!~"tmpfs|overlay"}
            /
            node_filesystem_size_bytes{instance="rpi-box-03.<homelab-domain>:9100",mountpoint="/srv/loki",fstype!~"tmpfs|overlay"}
          ) < 0.15
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "Loki disk filling up"
          description: "/srv/loki is above 85% usage on rpi-box-03."
```
