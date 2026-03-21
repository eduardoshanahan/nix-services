{
  pkgs,
  cfg,
  serviceName,
  dockerBin,
}: let
  healthcheckScript = pkgs.writeShellScript "excalidraw-healthcheck" ''
    set -euo pipefail

    service_name=${serviceName}
    container_name=${cfg.containerName}

    if ! systemctl is-active --quiet "$service_name"; then
      echo "excalidraw-healthcheck: systemd service $service_name is not active" >&2
      exit 1
    fi

    status="$(${dockerBin} inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_name" 2>/dev/null || true)"
    if [ "$status" != "healthy" ]; then
      echo "excalidraw-healthcheck: container health is '$status' (expected 'healthy')" >&2
      ${dockerBin} ps --filter "name=^/$container_name$" --format 'table {{.Names}}\t{{.Status}}' >&2 || true
      exit 1
    fi
  '';

  waitForHealthy = pkgs.writeShellScript "excalidraw-wait-healthy" ''
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
          echo "excalidraw: container became unhealthy" >&2
          ${dockerBin} ps --filter "name=^/$container_name$" --format 'table {{.Names}}\t{{.Status}}' >&2 || true
          exit 1
          ;;
        starting|none|"")
          ;;
        *)
          echo "excalidraw: unexpected health status: $status" >&2
          ;;
      esac

      if [ "$SECONDS" -ge "$deadline" ]; then
        echo "excalidraw: timed out waiting for a healthy container (''${timeout_seconds}s)" >&2
        ${dockerBin} ps --filter "name=^/$container_name$" --format 'table {{.Names}}\t{{.Status}}' >&2 || true
        exit 1
      fi

      sleep 2
    done
  '';
in {
  inherit healthcheckScript waitForHealthy;
}
