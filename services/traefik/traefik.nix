{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.traefikCompose;
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};

  serviceName = "traefikCompose";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";

  render = import ./render.nix {
    inherit lib pkgs cfg;
  };

  acmeEnvFile = "/run/secrets/traefik-acme.env";

  writeAcmeEnv = pkgs.writeShellScript "traefik-write-acme-env" ''
    set -euo pipefail
    umask 0077

    token_file=${lib.escapeShellArg (toString cfg.acme.cloudflareApiTokenFile)}

    if [[ ! -s "$token_file" ]]; then
      echo "traefik: missing or empty Cloudflare API token file: $token_file" >&2
      exit 1
    fi

    token="$(cat "$token_file")"
    token="''${token%$'\n'}"
    token="''${token%$'\r'}"

    if [[ -z "$token" ]]; then
      echo "traefik: Cloudflare API token file is empty after trimming" >&2
      exit 1
    fi

    install -d -m 0700 /run/secrets
    tmp="$(mktemp -p /run/secrets '.traefik-acme.env.XXXXXX')"
    printf 'CF_DNS_API_TOKEN=%s\n' "$token" > "$tmp"
    chmod 0600 "$tmp"
    mv -f "$tmp" "${acmeEnvFile}"
  '';

  inherit
    (render)
    tlsEnabled
    httpToHttpsRedirectEnabled
    acmeEnabled
    tlsFilesCheck
    composeText
    tlsConfigText
    ;
in {
  imports = [
    ./options.nix
  ];
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !tlsEnabled || cfg.tls.certFile != null;
        message = "services.traefik.tls.certFile must be set when TLS is enabled.";
      }
      {
        assertion = !tlsEnabled || cfg.tls.keyFile != null;
        message = "services.traefik.tls.keyFile must be set when TLS is enabled.";
      }
      {
        assertion = !(tlsEnabled && acmeEnabled);
        message = "services.traefik.tls.enable and services.traefik.acme.enable are mutually exclusive.";
      }
      {
        assertion = !httpToHttpsRedirectEnabled || tlsEnabled || acmeEnabled;
        message = "services.traefik.httpToHttpsRedirect requires either tls.enable or acme.enable.";
      }
      {
        assertion = !acmeEnabled || cfg.acme.email != "";
        message = "services.traefik.acme.email must be set when ACME is enabled.";
      }
      {
        assertion = !acmeEnabled || cfg.acme.cloudflareApiTokenFile != null;
        message = "services.traefik.acme.cloudflareApiTokenFile must be set when ACME is enabled.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".text = composeText;
    environment.etc = lib.mkIf tlsEnabled {
      "${serviceName}/tls.yml".text = tlsConfigText;
    };

    systemd.services.${serviceName} = {
      description = "Traefik ingress (Docker Compose)";

      wantedBy = ["multi-user.target"];
      after = ["docker.service" "network-online.target"];
      wants = ["network-online.target"];
      restartTriggers = [
        config.environment.etc."${serviceName}/docker-compose.yml".source
      ] ++ lib.optionals tlsEnabled [
        config.environment.etc."${serviceName}/tls.yml".source
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;

        WorkingDirectory = composeDir;

        Environment =
          [
            "TRAEFIK_CONTAINER_NAME=${cfg.containerName}"
            "TRAEFIK_NETWORK=${cfg.network}"
            "TRAEFIK_ACME_ENV_FILE=${if acmeEnabled then acmeEnvFile else "/dev/null"}"
          ]
          ++ runtimeSecrets.mkSecretFileEnvVar {
            envVar = "TRAEFIK_ENV_FILE";
            inherit (cfg) secretFile;
            fallback = "/dev/null";
          };

        ExecStartPre =
          [
            "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
          ]
          ++ lib.optionals tlsEnabled [
            tlsFilesCheck
          ]
          ++ lib.optionals acmeEnabled [
            "${pkgs.runtimeShell} -c 'mkdir -p /var/lib/traefik && touch /var/lib/traefik/acme.json && chmod 600 /var/lib/traefik/acme.json'"
            writeAcmeEnv
          ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
