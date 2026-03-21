{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.n8nCompose;
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};
  serviceName = "n8n";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
  protocol = if cfg.tls then "https" else "http";
  publicUrl = "${protocol}://${cfg.hostname}";

  runtimeEnvScript = pkgs.writeShellScript "${serviceName}-runtime-env" ''
    set -euo pipefail
    umask 0077

    db_secret_file=${lib.escapeShellArg (toString cfg.database.postgres.passwordFile)}
    encryption_secret_file=${lib.escapeShellArg (toString cfg.encryptionKeyFile)}

    install -d -m 0700 /run/secrets

    env_file="/run/secrets/${serviceName}.env"
    tmp="$(mktemp -p /run/secrets ".${serviceName}.env.XXXXXX")"

    read_secret_trimmed() {
      local file="$1"
      local label="$2"
      if [[ ! -s "$file" ]]; then
        echo "n8n: missing or empty $label file: $file" >&2
        exit 1
      fi
      local value
      value="$(tr -d '\r\n' < "$file")"
      if [[ -z "$value" ]]; then
        echo "n8n: $label file is empty after trimming: $file" >&2
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
    encryption_key="$(read_secret_trimmed "$encryption_secret_file" "encryption key")"

    {
      printf 'DB_POSTGRESDB_PASSWORD="%s"\n' "$(escape_env "$db_password")"
      printf 'N8N_ENCRYPTION_KEY="%s"\n' "$(escape_env "$encryption_key")"
    } > "$tmp"

    chmod 0600 "$tmp"
    mv -f "$tmp" "$env_file"
  '';
in {
  options.services.n8nCompose = {
    enable = lib.mkEnableOption "n8n service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "n8n";
      description = "Docker container name.";
    };

    hostname = lib.mkOption {
      type = lib.types.str;
      description = "Hostname used for the Traefik router `Host()` rule.";
    };

    timezone = lib.mkOption {
      type = lib.types.str;
      default = "UTC";
      description = "Timezone passed to the container via `TZ` and `GENERIC_TIMEZONE`.";
    };

    network = lib.mkOption {
      type = lib.types.str;
      default = "traefik";
      description = "External Docker network name used by Traefik and downstream services.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/n8n";
      description = "Persistent host path used for n8n state.";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "docker.n8n.io/n8nio/n8n";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "2.7.4";
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

    proxyHops = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = "Trusted proxy hops for n8n behind Traefik.";
    };

    database.postgres = {
      host = lib.mkOption {
        type = lib.types.str;
        default = "postgres.internal.example";
        description = "PostgreSQL host for n8n.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 5433;
        description = "PostgreSQL port for n8n.";
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "n8n";
        description = "PostgreSQL database name for n8n.";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "n8n";
        description = "PostgreSQL username for n8n.";
      };

      passwordFile = runtimeSecrets.mkSecretFileOption {
        description = "Absolute path to a runtime-provisioned file containing the PostgreSQL password for n8n.";
        example = "/run/secrets/n8n-db-password";
      };
    };

    encryptionKeyFile = runtimeSecrets.mkSecretFileOption {
      description = "Absolute path to a runtime-provisioned file containing `N8N_ENCRYPTION_KEY`.";
      example = "/run/secrets/n8n-encryption-key";
    };

    tls = lib.mkEnableOption "TLS on the n8n Traefik router";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.n8nCompose.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.n8nCompose.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.n8nCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.n8nCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.n8nCompose.image.tag must be pinned (not `latest`) unless services.n8nCompose.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.n8nCompose.dataDir must be an absolute path.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.database.postgres.host != null;
        message = "services.n8nCompose.database.postgres.host must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.database.postgres.name != null;
        message = "services.n8nCompose.database.postgres.name must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.database.postgres.user != null;
        message = "services.n8nCompose.database.postgres.user must not contain whitespace.";
      }
      {
        assertion = cfg.database.postgres.passwordFile != null;
        message = "services.n8nCompose.database.postgres.passwordFile must be set.";
      }
      {
        assertion = cfg.encryptionKeyFile != null;
        message = "services.n8nCompose.encryptionKeyFile must be set.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "n8n (Docker Compose)";
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
        WorkingDirectory = composeDir;
        TimeoutStartSec = 900;
        Restart = "on-failure";
        RestartSec = 10;

        Environment = [
          "N8N_CONTAINER_NAME=${cfg.containerName}"
          "N8N_IMAGE_REPOSITORY=${cfg.image.repository}"
          "N8N_IMAGE_TAG=${cfg.image.tag}"
          "N8N_NETWORK=${cfg.network}"
          "N8N_HOST=${cfg.hostname}"
          "N8N_ENTRYPOINTS=${if cfg.tls then "websecure" else "web"}"
          "N8N_TLS=${if cfg.tls then "true" else "false"}"
          "N8N_PROTOCOL=${protocol}"
          "N8N_EDITOR_BASE_URL=${publicUrl}"
          "WEBHOOK_URL=${publicUrl}/"
          "N8N_PROXY_HOPS=${toString cfg.proxyHops}"
          "N8N_SECURE_COOKIE=${if cfg.tls then "true" else "false"}"
          "N8N_DATA_DIR=${cfg.dataDir}"
          "N8N_RUNTIME_ENV_FILE=/run/secrets/${serviceName}.env"
          "N8N_DB_HOST=${cfg.database.postgres.host}"
          "N8N_DB_PORT=${toString cfg.database.postgres.port}"
          "N8N_DB_NAME=${cfg.database.postgres.name}"
          "N8N_DB_USER=${cfg.database.postgres.user}"
          "TZ=${cfg.timezone}"
          "GENERIC_TIMEZONE=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${lib.escapeShellArg cfg.dataDir} && chown 1000:1000 ${lib.escapeShellArg cfg.dataDir} && chmod 0750 ${lib.escapeShellArg cfg.dataDir}'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          runtimeEnvScript
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"n8n: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
