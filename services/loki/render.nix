{
  lib,
  pkgs,
  cfg,
}: let
  backupScript = pkgs.writeShellScript "loki-backup" ''
    set -euo pipefail

    src=${lib.escapeShellArg cfg.dataDir}
    dst=${lib.escapeShellArg cfg.backup.targetDir}
    keep_days=${toString cfg.backup.keepDays}

    if [[ ! -d "$src" ]]; then
      echo "loki-backup: source directory not found: $src" >&2
      exit 1
    fi

    install -d -m 0750 "$dst"

    stamp="$(${pkgs.coreutils}/bin/date -u +%Y%m%dT%H%M%SZ)"
    archive="$dst/loki-$stamp.tar.zst"

    ${pkgs.gnutar}/bin/tar \
      --use-compress-program="${pkgs.zstd}/bin/zstd -T0 -19" \
      -cf "$archive" \
      -C "$src" .

    ${pkgs.findutils}/bin/find "$dst" -maxdepth 1 -type f -name 'loki-*.tar.zst' -mtime "+$keep_days" -delete
  '';

  configYaml = ''
    auth_enabled: false

    server:
      http_listen_port: 3100

    common:
      path_prefix: /loki
      storage:
        filesystem:
          chunks_directory: /loki/chunks
          rules_directory: /loki/rules
      replication_factor: 1
      ring:
        kvstore:
          store: inmemory

    schema_config:
      configs:
        - from: 2024-01-01
          store: tsdb
          object_store: filesystem
          schema: v13
          index:
            prefix: index_
            period: 24h

    limits_config:
      retention_period: ${cfg.retentionPeriod}

    compactor:
      working_directory: /loki/compactor
      retention_enabled: true
      delete_request_store: filesystem
  '';
in {
  inherit backupScript configYaml;
}
