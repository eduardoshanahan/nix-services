{
  pkgs,
  cfg,
  dockerBin,
}: let
  waitForHealthy = pkgs.writeShellScript "uptime-kuma-wait-healthy" ''
    set -euo pipefail

    container_name=${cfg.containerName}
    # Match the container health window (start_period + interval * retries)
    # and leave a little margin for cold boots.
    timeout_seconds=180
    deadline=$((SECONDS + timeout_seconds))
    last_status=""

    while true; do
      status="$(${dockerBin} inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_name" 2>/dev/null || true)"

      if [ "$status" != "$last_status" ]; then
        echo "uptime-kuma: container health status is $status" >&2
        last_status="$status"
      fi

      case "$status" in
        healthy)
          exit 0
          ;;
        unhealthy)
          # Uptime Kuma can briefly report unhealthy during cold starts and
          # still recover without intervention. Keep waiting until timeout.
          ;;
        starting|none|"")
          ;;
        *)
          echo "uptime-kuma: unexpected health status: $status" >&2
          ;;
      esac

      if [ "$SECONDS" -ge "$deadline" ]; then
        echo "uptime-kuma: timed out waiting for a healthy container (final status: $status, timeout: ''${timeout_seconds}s)" >&2
        ${dockerBin} ps --filter "name=^/$container_name$" --format 'table {{.Names}}\t{{.Status}}' >&2 || true
        exit 1
      fi

      sleep 2
    done
  '';
in {
  inherit waitForHealthy;
}
