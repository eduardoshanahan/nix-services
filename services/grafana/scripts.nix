{
  lib,
  pkgs,
  cfg,
  serviceName,
  dockerBin,
}: let
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
  inherit backupScript healthcheckScript waitForHealthy;
}
