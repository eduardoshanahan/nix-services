{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.traefik;
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};

  serviceName = "traefik";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  tlsEnabled = cfg.tls.enable;
  httpToHttpsRedirectEnabled = cfg.httpToHttpsRedirect;
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
in {
  options.services.traefik = {
    uiHostname = lib.mkOption {
      type = lib.types.str;
      default = "traefik.local";
      description = ''
        Reserved hostname for future operator-validated UI exposure (not used while API/dashboard are disabled).
      '';
    };

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "traefik";
      description = "Docker container name.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/traefik";
      description = "Legacy persistent Traefik state directory path (not used; no `/data` mount is configured).";
    };

    network = lib.mkOption {
      type = lib.types.str;
      default = "traefik";
      description = "External Docker network name used by Traefik and downstream services.";
    };

    secretFile = runtimeSecrets.mkSecretFileOption {
      description = ''
        Absolute path to a runtime-provisioned env file (e.g. `/run/secrets/traefik.env`) that Docker Compose loads via `env_file`.

        This repo never materializes secrets; the host must provision the file before enabling the service.
      '';
      example = "/run/secrets/traefik.env";
    };

    tls = {
      enable = lib.mkEnableOption "TLS termination in Traefik for routed services";

      certFile = runtimeSecrets.mkSecretFileOption {
        description = ''
          Absolute path to a runtime-provisioned TLS certificate file for Traefik.
        '';
        example = "/run/secrets/traefik/tls.crt";
      };

      keyFile = runtimeSecrets.mkSecretFileOption {
        description = ''
          Absolute path to a runtime-provisioned TLS private key file for Traefik.
        '';
        example = "/run/secrets/traefik/tls.key";
      };
    };

    httpToHttpsRedirect = lib.mkEnableOption "global HTTP to HTTPS redirection on Traefik entrypoint `web`";
  };

  config = {
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
        assertion = !httpToHttpsRedirectEnabled || tlsEnabled;
        message = "services.traefik.httpToHttpsRedirect requires services.traefik.tls.enable = true.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;
    environment.etc."traefik/tls.yml".text = ''
      ${if tlsEnabled
      then ''
        tls:
          certificates:
            - certFile: ${tlsCertFile}
              keyFile: ${tlsKeyFile}
      ''
      else "tls: {}"}

      ${if httpToHttpsRedirectEnabled
      then ''
        http:
          routers:
            redirect-to-https:
              entryPoints:
                - web
              rule: HostRegexp(`{host:.+}`)
              middlewares:
                - redirect-to-https
              service: noop@internal
          middlewares:
            redirect-to-https:
              redirectScheme:
                scheme: https
                permanent: true
      ''
      else "http: {}"}
    '';

    systemd.services.${serviceName} = {
      description = "Traefik ingress (Docker Compose)";

      wantedBy = ["multi-user.target"];
      after = ["docker.service" "network-online.target"];
      wants = ["network-online.target"];
      restartTriggers = [
        config.environment.etc."${serviceName}/docker-compose.yml".source
        config.environment.etc."traefik/tls.yml".source
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;

        WorkingDirectory = composeDir;

        Environment =
          [
            "TRAEFIK_CONTAINER_NAME=${cfg.containerName}"
            "TRAEFIK_NETWORK=${cfg.network}"
          ]
          ++ runtimeSecrets.mkSecretFileEnvVar {
            envVar = "TRAEFIK_ENV_FILE";
            inherit (cfg) secretFile;
            fallback = "/dev/null";
          };

        ExecStartPre = [
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ]
        ++ lib.optionals tlsEnabled [
          tlsFilesCheck
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
