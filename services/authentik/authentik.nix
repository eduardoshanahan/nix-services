{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.authentikCompose;
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};
  serviceName = "authentik";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";

  runtimeEnvScript = pkgs.writeShellScript "${serviceName}-runtime-env" ''
    set -euo pipefail
    umask 0077

    db_secret_file=${lib.escapeShellArg (toString cfg.database.postgres.passwordFile)}
    key_secret_file=${lib.escapeShellArg (toString cfg.secretKeyFile)}
    bootstrap_password_file=${lib.escapeShellArg (
      if cfg.bootstrap.passwordFile == null
      then ""
      else toString cfg.bootstrap.passwordFile
    )}
    bootstrap_token_file=${lib.escapeShellArg (
      if cfg.bootstrap.tokenFile == null
      then ""
      else toString cfg.bootstrap.tokenFile
    )}

    env_file="/run/secrets/${serviceName}.env"
    tmp="$(mktemp -p /run/secrets ".${serviceName}.env.XXXXXX")"

    install -d -m 0700 /run/secrets

    read_secret_trimmed() {
      local file="$1"
      local label="$2"
      if [[ ! -s "$file" ]]; then
        echo "authentik: missing or empty $label file: $file" >&2
        exit 1
      fi
      local value
      value="$(tr -d '\r\n' < "$file")"
      if [[ -z "$value" ]]; then
        echo "authentik: $label file is empty after trimming: $file" >&2
        exit 1
      fi
      printf '%s' "$value"
    }

    escape_env() {
      local value="$1"
      value="''${value//\\/\\\\}"
      value="''${value//\"/\\\"}"
      printf '%s' "$value"
    }

    db_password="$(read_secret_trimmed "$db_secret_file" "database password")"
    secret_key="$(read_secret_trimmed "$key_secret_file" "secret key")"

    {
      printf 'AUTHENTIK_POSTGRESQL__HOST="%s"\n' "${cfg.database.postgres.host}"
      printf 'AUTHENTIK_POSTGRESQL__PORT="%s"\n' "${toString cfg.database.postgres.port}"
      printf 'AUTHENTIK_POSTGRESQL__NAME="%s"\n' "${cfg.database.postgres.name}"
      printf 'AUTHENTIK_POSTGRESQL__USER="%s"\n' "${cfg.database.postgres.user}"
      printf 'AUTHENTIK_POSTGRESQL__PASSWORD="%s"\n' "$(escape_env "$db_password")"
      printf 'AUTHENTIK_POSTGRESQL__SSLMODE="%s"\n' "${cfg.database.postgres.sslMode}"
      printf 'AUTHENTIK_SECRET_KEY="%s"\n' "$(escape_env "$secret_key")"
      printf 'AUTHENTIK_DISABLE_UPDATE_CHECK="%s"\n' "${
        if cfg.disableUpdateCheck
        then "true"
        else "false"
      }"
      printf 'AUTHENTIK_ERROR_REPORTING__ENABLED="%s"\n' "${
        if cfg.errorReporting
        then "true"
        else "false"
      }"
      printf 'AUTHENTIK_LOG_LEVEL="%s"\n' "${cfg.logLevel}"
      printf 'AUTHENTIK_BOOTSTRAP_EMAIL="%s"\n' "${cfg.bootstrap.email}"
      if [[ "${if cfg.metrics.enable then "true" else "false"}" == "true" ]]; then
        printf 'AUTHENTIK_LISTEN__METRICS="%s"\n' "${cfg.metrics.listenAddress}"
      fi
      if [[ -n "$bootstrap_password_file" ]]; then
        bootstrap_password="$(read_secret_trimmed "$bootstrap_password_file" "bootstrap password")"
        printf 'AUTHENTIK_BOOTSTRAP_PASSWORD="%s"\n' "$(escape_env "$bootstrap_password")"
      fi
      if [[ -n "$bootstrap_token_file" ]]; then
        bootstrap_token="$(read_secret_trimmed "$bootstrap_token_file" "bootstrap token")"
        printf 'AUTHENTIK_BOOTSTRAP_TOKEN="%s"\n' "$(escape_env "$bootstrap_token")"
      fi
    } > "$tmp"

    chmod 0600 "$tmp"
    mv -f "$tmp" "$env_file"
  '';
in {
  options.services.authentikCompose = {
    enable = lib.mkEnableOption "Authentik service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "authentik";
      description = "Base Docker container name.";
    };

    hostname = lib.mkOption {
      type = lib.types.str;
      description = "Hostname used for the Traefik router `Host()` rule.";
    };

    timezone = lib.mkOption {
      type = lib.types.str;
      default = "UTC";
      description = "Timezone passed to containers via `TZ`.";
    };

    network = lib.mkOption {
      type = lib.types.str;
      default = "traefik";
      description = "External Docker network name used by Traefik.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/srv/prometheus/authentik";
      description = "Persistent host path used for Authentik data.";
    };

    tls = lib.mkEnableOption "TLS on the Authentik Traefik router";

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "ghcr.io/goauthentik/server";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "2026.2.2";
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
      postgres = {
        host = lib.mkOption {
          type = lib.types.str;
          default = "postgres.internal.example";
          description = "PostgreSQL host for Authentik.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 5433;
          description = "PostgreSQL port for Authentik.";
        };

        name = lib.mkOption {
          type = lib.types.str;
          default = "authentik";
          description = "PostgreSQL database name for Authentik.";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = "authentik";
          description = "PostgreSQL username for Authentik.";
        };

        passwordFile = runtimeSecrets.mkSecretFileOption {
          description = "Absolute path to a runtime-provisioned file containing the PostgreSQL password for Authentik.";
          example = "/run/secrets/authentik-db-password";
        };

        sslMode = lib.mkOption {
          type = lib.types.enum [ "disable" "require" "verify-ca" "verify-full" ];
          default = "disable";
          description = "PostgreSQL SSL mode for Authentik.";
        };
      };
    };

    secretKeyFile = runtimeSecrets.mkSecretFileOption {
      description = "Absolute path to a runtime-provisioned file containing `AUTHENTIK_SECRET_KEY`.";
      example = "/run/secrets/authentik-secret-key";
    };

    bootstrap = {
      email = lib.mkOption {
        type = lib.types.str;
        default = "admin@internal.example";
        description = "Bootstrap admin email used on first startup.";
      };

      passwordFile = runtimeSecrets.mkSecretFileOption {
        description = "Optional absolute path to a runtime-provisioned file containing `AUTHENTIK_BOOTSTRAP_PASSWORD`.";
        example = "/run/secrets/authentik-bootstrap-password";
      };

      tokenFile = runtimeSecrets.mkSecretFileOption {
        description = "Optional absolute path to a runtime-provisioned file containing `AUTHENTIK_BOOTSTRAP_TOKEN`.";
        example = "/run/secrets/authentik-bootstrap-token";
      };
    };

    disableUpdateCheck = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Disable Authentik update checks.";
    };

    errorReporting = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable or disable Authentik error reporting.";
    };

    logLevel = lib.mkOption {
      type = lib.types.enum [ "trace" "debug" "info" "warning" "error" ];
      default = "info";
      description = "Authentik log verbosity.";
    };

    metrics = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Authentik Prometheus metrics endpoint.";
      };

      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0:9300";
        example = "0.0.0.0:9300";
        description = "Listen address for `AUTHENTIK_LISTEN__METRICS` when metrics are enabled.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.authentikCompose.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.authentikCompose.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.authentikCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.authentikCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.authentikCompose.image.tag must be pinned (not `latest`) unless services.authentikCompose.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.authentikCompose.dataDir must be an absolute path.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.database.postgres.host != null;
        message = "services.authentikCompose.database.postgres.host must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.database.postgres.name != null;
        message = "services.authentikCompose.database.postgres.name must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.database.postgres.user != null;
        message = "services.authentikCompose.database.postgres.user must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.metrics.listenAddress != null;
        message = "services.authentikCompose.metrics.listenAddress must not contain whitespace.";
      }
      {
        assertion = (cfg.bootstrap.passwordFile == null) || (cfg.bootstrap.tokenFile == null);
        message = "Set at most one of services.authentikCompose.bootstrap.passwordFile or services.authentikCompose.bootstrap.tokenFile.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "Authentik (Docker Compose)";

      wantedBy = [ "multi-user.target" ];
      requires = [ "docker.service" ];
      after = [ "docker.service" "network-online.target" ];
      wants = [ "network-online.target" ];
      restartTriggers = [
        config.environment.etc."${serviceName}/docker-compose.yml".source
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = 600;
        Restart = "on-failure";
        RestartSec = 10;
        WorkingDirectory = composeDir;

        Environment = [
          "AUTHENTIK_CONTAINER_NAME=${cfg.containerName}"
          "AUTHENTIK_IMAGE_REPOSITORY=${cfg.image.repository}"
          "AUTHENTIK_IMAGE_TAG=${cfg.image.tag}"
          "AUTHENTIK_HOSTNAME=${cfg.hostname}"
          "AUTHENTIK_NETWORK=${cfg.network}"
          "AUTHENTIK_DATA_DIR=${cfg.dataDir}"
          "AUTHENTIK_RUNTIME_ENV_FILE=/run/secrets/${serviceName}.env"
          "AUTHENTIK_ENTRYPOINTS=${
            if cfg.tls
            then "websecure"
            else "web"
          }"
          "AUTHENTIK_TLS=${
            if cfg.tls
            then "true"
            else "false"
          }"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'install -d -m 0750 ${cfg.dataDir} ${cfg.dataDir}/media ${cfg.dataDir}/certs ${cfg.dataDir}/custom-templates && chown -R 1000:1000 ${cfg.dataDir}'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c '${runtimeEnvScript}'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"authentik: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
