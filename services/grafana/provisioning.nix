{
  lib,
  cfg,
}: {
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
}
