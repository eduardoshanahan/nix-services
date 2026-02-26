{
  lib,
  cfg,
}: let
  syslogScrapeConfig = lib.optionalString cfg.syslog.enable (
    lib.concatStringsSep "\n" [
      "  - job_name: syslog-receiver"
      "    syslog:"
      "      listen_address: ${cfg.syslog.listenAddress}"
      "      idle_timeout: 60s"
      "      label_structured_data: true"
      "      labels:"
      "        job: ${cfg.syslog.jobLabel}"
      "    relabel_configs:"
      "      - source_labels: ['__syslog_message_hostname']"
      "        target_label: host"
    ]
  );

  configYaml = ''
    server:
      http_listen_port: ${toString cfg.httpPort}
      grpc_listen_port: 0

    positions:
      filename: /var/lib/promtail/positions.yaml

    clients:
      - url: ${cfg.lokiPushUrl}

    scrape_configs:
      - job_name: journal
        journal:
          max_age: ${cfg.journalMaxAge}
          path: /run/log/journal
          labels:
            job: systemd-journal
        relabel_configs:
          - source_labels: ['__journal__hostname']
            target_label: host
    ${syslogScrapeConfig}
  '';
in {
  inherit configYaml;
}
