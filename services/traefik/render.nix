{
  lib,
  pkgs,
  cfg,
}: let
  tlsEnabled = cfg.tls.enable;
  httpToHttpsRedirectEnabled = cfg.httpToHttpsRedirect;
  metricsEnabled = cfg.metrics.enable;

  redirectEntryPointFlags =
    lib.optionalString httpToHttpsRedirectEnabled
    "\n            - \"--entryPoints.web.http.redirections.entryPoint.to=websecure\"\n            - \"--entryPoints.web.http.redirections.entryPoint.scheme=https\"\n            - \"--entryPoints.web.http.redirections.entryPoint.permanent=true\"";

  metricsFlags =
    lib.optionalString metricsEnabled
    "\n            - \"--entryPoints.metrics.address=:${toString cfg.metrics.port}\"\n            - \"--metrics.prometheus=true\"\n            - \"--metrics.prometheus.entryPoint=metrics\"\n            - \"--metrics.prometheus.addEntryPointsLabels=true\"\n            - \"--metrics.prometheus.addRoutersLabels=true\"\n            - \"--metrics.prometheus.addServicesLabels=true\"";

  tlsCertFile =
    if cfg.tls.certFile == null
    then ""
    else toString cfg.tls.certFile;

  tlsKeyFile =
    if cfg.tls.keyFile == null
    then ""
    else toString cfg.tls.keyFile;

  tlsFilesCheck = pkgs.writeShellScript "traefik-tls-files-check" ''
    set -euo pipefail

    cert_file=${lib.escapeShellArg tlsCertFile}
    key_file=${lib.escapeShellArg tlsKeyFile}

    if [[ ! -s "$cert_file" ]]; then
      echo "traefik: missing TLS cert file: $cert_file" >&2
      exit 1
    fi

    if [[ ! -s "$key_file" ]]; then
      echo "traefik: missing TLS key file: $key_file" >&2
      exit 1
    fi
  '';

  composeText = ''
        services:
          traefik:
            image: traefik:v3.6.7
            container_name: ''${TRAEFIK_CONTAINER_NAME}
            restart: unless-stopped

            env_file:
              - ''${TRAEFIK_ENV_FILE}

            command:
              - "--log.level=INFO"
              - "--accesslog=false"

              - "--api=false"
              - "--ping=true"

              - "--providers.docker=true"
              - "--providers.docker.exposedByDefault=false"
              - "--providers.docker.network=''${TRAEFIK_NETWORK}"
              - "--providers.file.filename=/etc/traefik/tls.yml"

              - "--entryPoints.web.address=:80"
              - "--entryPoints.websecure.address=:443"
    ${redirectEntryPointFlags}
    ${metricsFlags}

            ports:
              - "80:80"
              - "443:443"
    ${lib.optionalString metricsEnabled "          - \"${toString cfg.metrics.port}:${toString cfg.metrics.port}\""}

            volumes:
              - "/var/run/docker.sock:/var/run/docker.sock:ro"
              - "/etc/traefik/tls.yml:/etc/traefik/tls.yml:ro"
              - "/run/secrets:/run/secrets:ro"

            networks:
              - traefik

        networks:
          traefik:
            external: true
            name: ''${TRAEFIK_NETWORK}
  '';

  tlsConfigText = ''
    ${
      if tlsEnabled
      then ''
        tls:
          certificates:
            - certFile: ${tlsCertFile}
              keyFile: ${tlsKeyFile}
      ''
      else "tls: {}"
    }
  '';
in {
  inherit
    tlsEnabled
    httpToHttpsRedirectEnabled
    metricsEnabled
    tlsFilesCheck
    composeText
    tlsConfigText
    ;
}
