{lib, ...}: let
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};
in {
  options.services.traefikCompose = {
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

    acme = {
      enable = lib.mkEnableOption "ACME/Let's Encrypt certificate management via DNS-01 challenge";

      email = lib.mkOption {
        type = lib.types.str;
        description = "Email address for Let's Encrypt account registration and expiry notifications.";
        example = "admin@example.com";
      };

      staging = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Use Let's Encrypt staging CA. Enable during initial setup to avoid rate limits.";
      };

      cloudflareApiTokenFile = runtimeSecrets.mkSecretFileOption {
        description = ''
          Absolute path to a runtime-provisioned file containing the Cloudflare API token
          used for DNS-01 challenge. The token needs Zone → DNS → Edit permission.
        '';
        example = "/run/secrets/cloudflare-api-token";
      };
    };

    metrics = {
      enable = lib.mkEnableOption "Prometheus metrics endpoint on Traefik";

      port = lib.mkOption {
        type = lib.types.port;
        default = 8082;
        description = "Host/container TCP port used by Traefik Prometheus metrics entrypoint.";
      };
    };

    plainHttp = {
      enable = lib.mkEnableOption "additional cleartext HTTP entrypoint for selected internal-only services";

      port = lib.mkOption {
        type = lib.types.port;
        default = 8084;
        description = "Host/container TCP port used by the additional cleartext HTTP entrypoint.";
      };
    };

  };
}
