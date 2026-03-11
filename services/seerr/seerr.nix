{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.seerr;
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};
  serviceName = "seerr";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";

  runtimeEnvScript = pkgs.writeShellScript "${serviceName}-runtime-env" ''
    set -euo pipefail
    umask 0077

    db_secret_file=${lib.escapeShellArg (toString cfg.database.postgres.passwordFile)}

    install -d -m 0700 /run/secrets

    env_file="/run/secrets/${serviceName}.env"
    tmp="$(mktemp -p /run/secrets ".${serviceName}.env.XXXXXX")"

    if [[ ! -s "$db_secret_file" ]]; then
      echo "seerr: missing or empty database password file: $db_secret_file" >&2
      exit 1
    fi

    db_password="$(tr -d '\r\n' < "$db_secret_file")"
    if [[ -z "$db_password" ]]; then
      echo "seerr: database password file is empty after trimming: $db_secret_file" >&2
      exit 1
    fi

    db_password="''${db_password//\\/\\\\}"
    db_password="''${db_password//\"/\\\"}"

    printf 'DB_PASS="%s"\n' "$db_password" > "$tmp"

    chmod 0600 "$tmp"
    mv -f "$tmp" "$env_file"
  '';
in {
  options.services.seerr = {
    enable = lib.mkEnableOption "Seerr service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "seerr";
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
      default = "/var/lib/seerr";
      description = "Persistent host path used for Seerr state.";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "ghcr.io/seerr-team/seerr";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "v3.1.0";
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

    database.postgres = {
      host = lib.mkOption {
        type = lib.types.str;
        default = "postgres.<homelab-domain>";
        description = "PostgreSQL host for Seerr.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 5433;
        description = "PostgreSQL port for Seerr.";
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "seerr";
        description = "PostgreSQL database name for Seerr.";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "seerr";
        description = "PostgreSQL username for Seerr.";
      };

      passwordFile = runtimeSecrets.mkSecretFileOption {
        description = "Absolute path to a runtime-provisioned file containing the PostgreSQL password for Seerr.";
        example = "/run/secrets/seerr-db-password";
      };
    };

    tls = lib.mkEnableOption "TLS on the Seerr Traefik router";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.seerr.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.seerr.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.seerr.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.seerr.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.seerr.image.tag must be pinned (not `latest`) unless services.seerr.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.seerr.dataDir must be an absolute path.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.database.postgres.host != null;
        message = "services.seerr.database.postgres.host must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.database.postgres.name != null;
        message = "services.seerr.database.postgres.name must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.database.postgres.user != null;
        message = "services.seerr.database.postgres.user must not contain whitespace.";
      }
      {
        assertion = cfg.database.postgres.passwordFile != null;
        message = "services.seerr.database.postgres.passwordFile must be set.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "Seerr (Docker Compose)";
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
          "SEERR_CONTAINER_NAME=${cfg.containerName}"
          "SEERR_IMAGE_REPOSITORY=${cfg.image.repository}"
          "SEERR_IMAGE_TAG=${cfg.image.tag}"
          "SEERR_NETWORK=${cfg.network}"
          "SEERR_HOST=${cfg.hostname}"
          "SEERR_ENTRYPOINTS=${if cfg.tls then "websecure" else "web"}"
          "SEERR_TLS=${if cfg.tls then "true" else "false"}"
          "SEERR_DATA_DIR=${cfg.dataDir}"
          "SEERR_RUNTIME_ENV_FILE=/run/secrets/${serviceName}.env"
          "SEERR_DB_HOST=${cfg.database.postgres.host}"
          "SEERR_DB_PORT=${toString cfg.database.postgres.port}"
          "SEERR_DB_NAME=${cfg.database.postgres.name}"
          "SEERR_DB_USER=${cfg.database.postgres.user}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${lib.escapeShellArg cfg.dataDir} && chown 1000:1000 ${lib.escapeShellArg cfg.dataDir} && chmod 0750 ${lib.escapeShellArg cfg.dataDir}'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'test -s /etc/ssl/certs/homelab-root-ca.crt'"
          runtimeEnvScript
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"seerr: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
