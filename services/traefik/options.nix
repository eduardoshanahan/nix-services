{lib, ...}: let
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};
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

    metrics = {
      enable = lib.mkEnableOption "Prometheus metrics endpoint on Traefik";

      port = lib.mkOption {
        type = lib.types.port;
        default = 8082;
        description = "Host/container TCP port used by Traefik Prometheus metrics entrypoint.";
      };
    };
  };
}
