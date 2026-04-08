{
  lib,
  ...
}: let
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};
in {
  options.services.vikunjaCompose = {
    enable = lib.mkEnableOption "Vikunja service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "vikunja";
      description = "Docker container name.";
    };

    hostname = lib.mkOption {
      type = lib.types.str;
      description = "Hostname used for the Traefik router `Host()` rule.";
    };

    timezone = lib.mkOption {
      type = lib.types.str;
      default = "UTC";
      description = "Timezone passed to the container via `TZ`.";
    };

    network = lib.mkOption {
      type = lib.types.str;
      default = "traefik";
      description = "External Docker network name used by Traefik and downstream services.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/vikunja";
      description = "Persistent host path used for Vikunja attachments and local application data.";
    };

    enableRegistration = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow self-service user registration.";
    };

    metrics = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Vikunja Prometheus metrics endpoint.";
      };
    };

    auth = {
      local.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable local username/password authentication.";
      };

      openid = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable OpenID Connect authentication providers.";
        };

        providerKey = lib.mkOption {
          type = lib.types.str;
          default = "authentik";
          description = "Provider key used in Vikunja's OpenID provider map.";
        };

        name = lib.mkOption {
          type = lib.types.str;
          default = "Authentik";
          description = "Display name shown on the login button.";
        };

        authUrl = lib.mkOption {
          type = lib.types.str;
          default = "https://auth.internal.example/application/o/vikunja/";
          description = "OIDC issuer/discovery URL.";
        };

        clientIdFile = runtimeSecrets.mkSecretFileOption {
          description = ''
            Absolute path to a runtime-provisioned file containing the OIDC client ID.
          '';
          example = "/run/secrets/vikunja-oidc-client-id";
        };

        clientSecretFile = runtimeSecrets.mkSecretFileOption {
          description = ''
            Absolute path to a runtime-provisioned file containing the OIDC client secret.
          '';
          example = "/run/secrets/vikunja-oidc-client-secret";
        };

        scopes = lib.mkOption {
          type = lib.types.str;
          default = "openid profile email";
          description = "Space-separated OAuth scopes requested from the provider.";
        };

        usernameFallback = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Allow deriving a username if the provider does not return one.";
        };

        emailFallback = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Allow deriving an email address if the provider does not return one.";
        };
      };
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "vikunja/vikunja";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "2.2.2";
        description = "Container image tag.";
      };

      allowMutableTag = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Allow mutable tags such as `latest`. Keep disabled to enforce pinned
          image tags by default.
        '';
      };
    };

    database = {
      type = lib.mkOption {
        type = lib.types.enum [ "sqlite" "postgres" ];
        default = "sqlite";
        description = "Database backend used by Vikunja.";
      };

      sqlite.path = lib.mkOption {
        type = lib.types.str;
        default = "/app/vikunja/files/vikunja.db";
        description = "SQLite database path inside the container (used when `database.type = \"sqlite\"`).";
      };

      postgres = {
        host = lib.mkOption {
          type = lib.types.str;
          default = "postgres.internal.example";
          description = "PostgreSQL host (used when `database.type = \"postgres\"`).";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 5433;
          description = "PostgreSQL port.";
        };

        name = lib.mkOption {
          type = lib.types.str;
          default = "vikunja";
          description = "PostgreSQL database name.";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = "vikunja";
          description = "PostgreSQL database user.";
        };

        passwordFile = runtimeSecrets.mkSecretFileOption {
          description = ''
            Absolute path to a runtime-provisioned file containing the PostgreSQL password
            (single line, no trailing newline).
          '';
          example = "/run/secrets/vikunja-db-password";
        };

        sslMode = lib.mkOption {
          type = lib.types.enum [ "disable" "require" "verify-ca" "verify-full" ];
          default = "disable";
          description = "PostgreSQL SSL mode for Vikunja.";
        };
      };
    };

    tls = lib.mkEnableOption "TLS on the Vikunja Traefik router";
  };
}
