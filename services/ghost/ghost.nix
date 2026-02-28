{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.ghost;
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};
  serviceName = "ghost";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
  writeRuntimeEnv = pkgs.writeShellScript "ghost-write-runtime-env" ''
    set -euo pipefail
    umask 0077

    db_secret_file=${lib.escapeShellArg (toString cfg.database.passwordFile)}
    mail_secret_file=${lib.escapeShellArg (
      if cfg.mail.passwordFile == null
      then ""
      else toString cfg.mail.passwordFile
    )}

    if [[ ! -s "$db_secret_file" ]]; then
      echo "ghost: missing or empty database password file: $db_secret_file" >&2
      exit 1
    fi

    db_password="$(cat "$db_secret_file")"
    db_password="''${db_password%$'\n'}"
    db_password="''${db_password%$'\r'}"

    if [[ -z "$db_password" ]]; then
      echo "ghost: database password file is empty after trimming" >&2
      exit 1
    fi

    escape_env() {
      local value="$1"
      value="''${value//\\/\\\\}"
      value="''${value//\"/\\\"}"
      printf '%s' "$value"
    }

    install -d -m 0700 /run/secrets
    tmp="$(mktemp -p /run/secrets '.ghost.env.XXXXXX')"

    printf 'database__connection__password="%s"\n' "$(escape_env "$db_password")" > "$tmp"

    if [[ -n "$mail_secret_file" ]]; then
      if [[ ! -s "$mail_secret_file" ]]; then
        echo "ghost: missing or empty mail password file: $mail_secret_file" >&2
        rm -f "$tmp"
        exit 1
      fi

      mail_password="$(cat "$mail_secret_file")"
      mail_password="''${mail_password%$'\n'}"
      mail_password="''${mail_password%$'\r'}"

      if [[ -z "$mail_password" ]]; then
        echo "ghost: mail password file is empty after trimming" >&2
        rm -f "$tmp"
        exit 1
      fi

      printf 'mail__options__auth__pass="%s"\n' "$(escape_env "$mail_password")" >> "$tmp"
    fi

    chmod 0600 "$tmp"
    mv -f "$tmp" /run/secrets/ghost.env
  '';
  waitForHealthy = pkgs.writeShellScript "ghost-wait-healthy" ''
    set -euo pipefail

    container_name=${cfg.containerName}
    timeout_seconds=180
    deadline=$((SECONDS + timeout_seconds))

    while true; do
      status="$(${dockerBin} inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_name" 2>/dev/null || true)"

      case "$status" in
        healthy)
          exit 0
          ;;
        unhealthy)
          echo "ghost: container became unhealthy" >&2
          ${dockerBin} ps --filter "name=^/$container_name$" --format 'table {{.Names}}\t{{.Status}}' >&2 || true
          exit 1
          ;;
        starting|none|"")
          ;;
        *)
          echo "ghost: unexpected health status: $status" >&2
          ;;
      esac

      if [ "$SECONDS" -ge "$deadline" ]; then
        echo "ghost: timed out waiting for a healthy container (''${timeout_seconds}s)" >&2
        ${dockerBin} ps --filter "name=^/$container_name$" --format 'table {{.Names}}\t{{.Status}}' >&2 || true
        exit 1
      fi

      sleep 2
    done
  '';
in {
  options.services.ghost = {
    enable = lib.mkEnableOption "Ghost blog service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "ghost";
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
      default = "/var/lib/ghost";
      description = "Persistent host path used for Ghost content.";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "ghost";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "6.19.2";
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
      host = lib.mkOption {
        type = lib.types.str;
        description = "MySQL hostname or IP reachable from the Ghost host.";
        example = "hhnas4";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 3306;
        description = "MySQL TCP port.";
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "ghost";
        description = "MySQL database name for Ghost.";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "ghost";
        description = "MySQL username for Ghost.";
      };

      passwordFile = runtimeSecrets.mkSecretFileOption {
        description = ''
          Absolute path to a runtime-provisioned file containing the MySQL password
          for the Ghost database user.
        '';
        example = "/run/secrets/ghost-db-password";
      };
    };

    mail = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable SMTP mail delivery for Ghost.";
      };

      from = lib.mkOption {
        type = lib.types.str;
        default = "ghost@example.com";
        description = "Sender address for Ghost mail.";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "smtp.gmail.com";
        description = "SMTP host used by Ghost.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 465;
        description = "SMTP port used by Ghost.";
      };

      secure = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether Ghost uses SMTPS/TLS for the mail connection.";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "ghost@example.com";
        description = "SMTP username used by Ghost.";
      };

      passwordFile = runtimeSecrets.mkSecretFileOption {
        description = ''
          Absolute path to a runtime-provisioned file containing the SMTP password
          used by Ghost mail delivery.
        '';
        example = "/run/secrets/ghost-mail-password";
      };
    };

    tls = lib.mkEnableOption "TLS on the Ghost Traefik router";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.ghost.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.ghost.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.ghost.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.ghost.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.ghost.image.tag must be pinned (not `latest`) unless services.ghost.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.ghost.dataDir must be an absolute path.";
      }
      {
        assertion = cfg.database.host != "";
        message = "services.ghost.database.host must be set when enabling Ghost.";
      }
      {
        assertion = cfg.database.passwordFile != null;
        message = "services.ghost.database.passwordFile must be set when enabling Ghost.";
      }
      {
        assertion = !cfg.mail.enable || cfg.mail.passwordFile != null;
        message = "services.ghost.mail.passwordFile must be set when services.ghost.mail.enable = true.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "Ghost blog (Docker Compose)";

      wantedBy = ["multi-user.target"];
      requires = ["docker.service"];
      after = ["docker.service" "network-online.target"];
      wants = ["network-online.target"];
      restartTriggers = [
        config.environment.etc."${serviceName}/docker-compose.yml".source
      ];
      startLimitBurst = 3;
      startLimitIntervalSec = 300;

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = 240;
        Restart = "on-failure";
        RestartSec = 10;
        WorkingDirectory = composeDir;

        Environment = [
          "GHOST_CONTAINER_NAME=${cfg.containerName}"
          "GHOST_IMAGE_REPOSITORY=${cfg.image.repository}"
          "GHOST_IMAGE_TAG=${cfg.image.tag}"
          "GHOST_NETWORK=${cfg.network}"
          "GHOST_HOSTNAME=${cfg.hostname}"
          "GHOST_ENTRYPOINTS=${if cfg.tls then "websecure" else "web"}"
          "GHOST_TLS=${if cfg.tls then "true" else "false"}"
          "GHOST_URL=${if cfg.tls then "https" else "http"}://${cfg.hostname}"
          "GHOST_DATA_DIR=${cfg.dataDir}"
          "GHOST_DATABASE_HOST=${cfg.database.host}"
          "GHOST_DATABASE_PORT=${toString cfg.database.port}"
          "GHOST_DATABASE_NAME=${cfg.database.name}"
          "GHOST_DATABASE_USER=${cfg.database.user}"
          "GHOST_MAIL_TRANSPORT=${if cfg.mail.enable then "SMTP" else "Direct"}"
          "GHOST_MAIL_FROM=${if cfg.mail.enable then cfg.mail.from else ""}"
          "GHOST_MAIL_HOST=${if cfg.mail.enable then cfg.mail.host else ""}"
          "GHOST_MAIL_PORT=${if cfg.mail.enable then toString cfg.mail.port else ""}"
          "GHOST_MAIL_SECURE=${if cfg.mail.enable && cfg.mail.secure then "true" else "false"}"
          "GHOST_MAIL_USER=${if cfg.mail.enable then cfg.mail.user else ""}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${cfg.dataDir} && chown 1000:1000 ${cfg.dataDir} && chmod 0750 ${cfg.dataDir}'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"ghost: docker daemon is not ready\" >&2; exit 1'"
          writeRuntimeEnv
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStartPost = waitForHealthy;
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
