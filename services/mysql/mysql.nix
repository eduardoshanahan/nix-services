{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.mysqlCompose;
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  runtimeEnvFile = "/run/secrets/mysql.env";
  composeEtcKey = "mysql/docker-compose.yml";
  composePath = "/etc/mysql/docker-compose.yml";
  composeDir = "/etc/mysql";

  writeRuntimeEnv = pkgs.writeShellScript "mysql-write-runtime-env" ''
    set -euo pipefail
    umask 0077

    root_secret_file=${lib.escapeShellArg (toString cfg.rootPasswordFile)}

    if [[ ! -s "$root_secret_file" ]]; then
      echo "mysql: missing or empty root password file: $root_secret_file" >&2
      exit 1
    fi

    root_password="$(cat "$root_secret_file")"
    root_password="''${root_password%$'\n'}"
    root_password="''${root_password%$'\r'}"

    if [[ -z "$root_password" ]]; then
      echo "mysql: root password file is empty after trimming" >&2
      exit 1
    fi

    escape_env() {
      local value="$1"
      value="''${value//\\/\\\\}"
      value="''${value//\"/\\\"}"
      printf '%s' "$value"
    }

    install -d -m 0700 /run/secrets
    tmp="$(mktemp -p /run/secrets '.mysql.env.XXXXXX')"

    printf 'MYSQL_ROOT_PASSWORD="%s"\n' "$(escape_env "$root_password")" > "$tmp"

    ${lib.optionalString (cfg.initDatabase.name != null) ''
      printf 'MYSQL_DATABASE="${cfg.initDatabase.name}"\n' >> "$tmp"
    ''}

    ${lib.optionalString (cfg.initDatabase.user != null) ''
      printf 'MYSQL_USER="${cfg.initDatabase.user}"\n' >> "$tmp"
    ''}

    ${lib.optionalString (cfg.initDatabase.passwordFile != null) ''
      init_pw_file=${lib.escapeShellArg (toString cfg.initDatabase.passwordFile)}

      if [[ ! -s "$init_pw_file" ]]; then
        echo "mysql: missing or empty initDatabase password file: $init_pw_file" >&2
        rm -f "$tmp"
        exit 1
      fi

      init_pw="$(cat "$init_pw_file")"
      init_pw="''${init_pw%$'\n'}"
      init_pw="''${init_pw%$'\r'}"

      if [[ -z "$init_pw" ]]; then
        echo "mysql: initDatabase password file is empty after trimming" >&2
        rm -f "$tmp"
        exit 1
      fi

      printf 'MYSQL_PASSWORD="%s"\n' "$(escape_env "$init_pw")" >> "$tmp"
    ''}

    chmod 0600 "$tmp"
    mv -f "$tmp" "${runtimeEnvFile}"
  '';

  waitForHealthy = pkgs.writeShellScript "mysql-wait-healthy" ''
    set -euo pipefail

    container_name=${cfg.containerName}
    timeout_seconds=120
    deadline=$((SECONDS + timeout_seconds))

    while true; do
      status="$(${dockerBin} inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_name" 2>/dev/null || true)"

      case "$status" in
        healthy)
          exit 0
          ;;
        unhealthy)
          echo "mysql: container became unhealthy" >&2
          ${dockerBin} ps --filter "name=^/$container_name$" --format 'table {{.Names}}\t{{.Status}}' >&2 || true
          exit 1
          ;;
        starting | none | "")
          ;;
        *)
          echo "mysql: unexpected health status: $status" >&2
          ;;
      esac

      if [ "$SECONDS" -ge "$deadline" ]; then
        echo "mysql: timed out waiting for a healthy container (''${timeout_seconds}s)" >&2
        ${dockerBin} ps --filter "name=^/$container_name$" --format 'table {{.Names}}\t{{.Status}}' >&2 || true
        exit 1
      fi

      sleep 2
    done
  '';
in {
  options.services.mysqlCompose = {
    enable = lib.mkEnableOption "MySQL (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "mysql";
      description = "Docker container name.";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "mysql";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "8.0.40";
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

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/mysql-compose";
      description = "Host path for MySQL data files.";
    };

    network = lib.mkOption {
      type = lib.types.str;
      default = "traefik";
      description = ''
        External Docker network MySQL joins. Services connecting to MySQL
        (e.g. Ghost) must be on the same network and can reach MySQL by
        its container name.
      '';
    };

    timezone = lib.mkOption {
      type = lib.types.str;
      default = "UTC";
      description = "Timezone passed to the container via TZ.";
    };

    rootPasswordFile = runtimeSecrets.mkSecretFileOption {
      description = ''
        Absolute path to a runtime-provisioned file containing the MySQL root
        password. The file must exist and be non-empty before the service starts.
      '';
      example = "/run/secrets/mysql-root-password";
    };

    initDatabase = {
      name = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Database to create on first initialisation (when the data directory
          is empty). Passed to the container as MYSQL_DATABASE. Has no effect
          on an already-initialised data directory.
        '';
        example = "ghost";
      };

      user = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Username to create on first initialisation, granted full access to
          initDatabase.name. Requires initDatabase.name to be set.
        '';
        example = "ghost";
      };

      passwordFile = runtimeSecrets.mkSecretFileOption {
        description = ''
          Absolute path to a runtime-provisioned file containing the password
          for initDatabase.user. Required when initDatabase.user is set.
        '';
        example = "/run/secrets/mysql-ghost-password";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.rootPasswordFile != null;
        message = "services.mysqlCompose.rootPasswordFile must be set when enabling MySQL.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.mysqlCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.mysqlCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.mysqlCompose.image.tag must be pinned (not `latest`) unless services.mysqlCompose.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.mysqlCompose.dataDir must be an absolute path.";
      }
      {
        assertion = cfg.initDatabase.user == null || cfg.initDatabase.name != null;
        message = "services.mysqlCompose.initDatabase.name must be set when initDatabase.user is set.";
      }
      {
        assertion = cfg.initDatabase.passwordFile == null || cfg.initDatabase.user != null;
        message = "services.mysqlCompose.initDatabase.user must be set when initDatabase.passwordFile is set.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${composeEtcKey}".source = ./docker-compose.yml;

    systemd.services.mysqlCompose = {
      description = "MySQL (Docker Compose)";

      wantedBy = ["multi-user.target"];
      requires = ["docker.service"];
      after = ["docker.service" "network-online.target"];
      wants = ["network-online.target"];
      restartTriggers = [config.environment.etc."${composeEtcKey}".source];
      startLimitBurst = 3;
      startLimitIntervalSec = 300;

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = 180;
        Restart = "on-failure";
        RestartSec = 10;
        WorkingDirectory = composeDir;

        Environment = [
          "MYSQL_CONTAINER_NAME=${cfg.containerName}"
          "MYSQL_IMAGE_REPOSITORY=${cfg.image.repository}"
          "MYSQL_IMAGE_TAG=${cfg.image.tag}"
          "MYSQL_DATA_DIR=${cfg.dataDir}"
          "MYSQL_NETWORK=${cfg.network}"
          "MYSQL_RUNTIME_ENV_FILE=${runtimeEnvFile}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${cfg.dataDir}'"
          "${pkgs.runtimeShell} -c 'test -s ${composePath}'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"mysql: docker daemon is not ready\" >&2; exit 1'"
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
