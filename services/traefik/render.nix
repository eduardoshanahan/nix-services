{
  lib,
  pkgs,
  cfg,
}: let
  tlsEnabled = cfg.tls.enable;
  httpToHttpsRedirectEnabled = cfg.httpToHttpsRedirect;
  metricsEnabled = cfg.metrics.enable;
  plainHttpEnabled = cfg.plainHttp.enable;
  acmeEnabled = cfg.acme.enable;
  mkYamlList = {
    indent,
    items,
  }:
    lib.concatStringsSep "\n" (map (item: "${indent}- \"${item}\"") items);

  commandFlags =
    [
      "--log.level=INFO"
      "--accesslog=false"
      "--api=false"
      "--ping=true"
      "--providers.docker=true"
      "--providers.docker.exposedByDefault=false"
      "--providers.docker.network=\${TRAEFIK_NETWORK}"
      "--entryPoints.web.address=:80"
      "--entryPoints.websecure.address=:443"
    ]
    ++ lib.optionals tlsEnabled [
      "--providers.file.filename=/etc/traefik/tls.yml"
    ]
    ++ lib.optionals httpToHttpsRedirectEnabled [
      "--entryPoints.web.http.redirections.entryPoint.to=websecure"
      "--entryPoints.web.http.redirections.entryPoint.scheme=https"
      "--entryPoints.web.http.redirections.entryPoint.permanent=true"
    ]
    ++ lib.optionals metricsEnabled [
      "--entryPoints.metrics.address=:${toString cfg.metrics.port}"
      "--metrics.prometheus=true"
      "--metrics.prometheus.entryPoint=metrics"
      "--metrics.prometheus.addEntryPointsLabels=true"
      "--metrics.prometheus.addRoutersLabels=true"
      "--metrics.prometheus.addServicesLabels=true"
    ]
    ++ lib.optionals plainHttpEnabled [
      "--entryPoints.webplain.address=:${toString cfg.plainHttp.port}"
    ]
    ++ lib.optionals acmeEnabled [
      "--certificatesResolvers.letsencrypt.acme.email=${cfg.acme.email}"
      "--certificatesResolvers.letsencrypt.acme.storage=/etc/traefik/acme.json"
      "--certificatesResolvers.letsencrypt.acme.dnsChallenge=true"
      "--certificatesResolvers.letsencrypt.acme.dnsChallenge.provider=cloudflare"
      "--entryPoints.websecure.http.tls.certResolver=letsencrypt"
    ]
    ++ lib.optionals (acmeEnabled && cfg.acme.staging) [
      "--certificatesResolvers.letsencrypt.acme.caServer=https://acme-staging-v02.api.letsencrypt.org/directory"
    ];

  volumeMappings =
    [
      "/var/run/docker.sock:/var/run/docker.sock:ro"
      "/run/secrets:/run/secrets:ro"
    ]
    ++ lib.optionals tlsEnabled [
      "/etc/traefikCompose/tls.yml:/etc/traefik/tls.yml:ro"
    ]
    ++ lib.optionals acmeEnabled [
      "/var/lib/traefik/acme.json:/etc/traefik/acme.json"
    ];

  portMappings =
    [
      "80:80"
      "443:443"
    ]
    ++ lib.optionals metricsEnabled [
      "${toString cfg.metrics.port}:${toString cfg.metrics.port}"
    ]
    ++ lib.optionals plainHttpEnabled [
      "${toString cfg.plainHttp.port}:${toString cfg.plainHttp.port}"
    ];

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
            image: traefik:v3.6.13
            container_name: ''${TRAEFIK_CONTAINER_NAME}
            restart: unless-stopped

            env_file:
              - ''${TRAEFIK_ENV_FILE}
              - ''${TRAEFIK_ACME_ENV_FILE}

            command:
    ${mkYamlList {
      indent = "          ";
      items = commandFlags;
    }}

            ports:
    ${mkYamlList {
      indent = "          ";
      items = portMappings;
    }}

            volumes:
    ${mkYamlList {
      indent = "          ";
      items = volumeMappings;
    }}

            extra_hosts:
              - "host.docker.internal:host-gateway"

            logging:
              driver: "json-file"

            networks:
              - traefik

        networks:
          traefik:
            external: true
            name: ''${TRAEFIK_NETWORK}
  '';

  tlsBlock =
    if tlsEnabled
    then ''
      tls:
        certificates:
          - certFile: ${tlsCertFile}
            keyFile: ${tlsKeyFile}
    ''
    else ''
      tls: {}
    '';

  tlsConfigText = lib.concatStringsSep "\n" (
    lib.filter (block: block != "") [
      tlsBlock
    ]
  );
in {
  inherit
    tlsEnabled
    httpToHttpsRedirectEnabled
    metricsEnabled
    plainHttpEnabled
    acmeEnabled
    tlsFilesCheck
    composeText
    tlsConfigText
    ;
}
