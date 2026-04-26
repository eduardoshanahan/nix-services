{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.ankiSyncCompose;
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};
  serviceName = "anki-sync";
  composeDir = "/var/lib/${serviceName}-compose";
  staticDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  composeCmd = "${dockerBin} compose --project-directory ${composeDir} -f ${composeDir}/docker-compose.yml";
  defaultGeneratedPasswordFile = "${cfg.dataDir}/auth/sync-password";
  effectivePasswordFile =
    if cfg.account.passwordFile == null
    then defaultGeneratedPasswordFile
    else toString cfg.account.passwordFile;
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
  runtimeEnvScript = pkgs.writeShellScript "${serviceName}-runtime-env" ''
    set -euo pipefail
    umask 0077

    password_file=${lib.escapeShellArg effectivePasswordFile}
    auto_generate_password=${
      if cfg.account.passwordFile == null
      then "1"
      else "0"
    }

    install -d -m 0700 /run/secrets
    chmod 0700 /run/secrets
    install -d -m 0700 ${lib.escapeShellArg "${cfg.dataDir}/auth"}

    if [ "$auto_generate_password" = "1" ] && [ ! -s "$password_file" ]; then
      ${pkgs.openssl}/bin/openssl rand -base64 24 > "$password_file"
      chmod 0600 "$password_file"
    fi

    if [ ! -s "$password_file" ]; then
      echo "${serviceName}: password file does not exist or is empty: $password_file" >&2
      exit 1
    fi

    password="$(cat "$password_file")"
    password="''${password%$'\n'}"
    password="''${password%$'\r'}"

    if [[ -z "$password" ]]; then
      echo "${serviceName}: password file is empty after trimming newline: $password_file" >&2
      exit 1
    fi

    if [[ "$password" == *$'\n'* || "$password" == *$'\r'* ]]; then
      echo "${serviceName}: password file must contain a single line: $password_file" >&2
      exit 1
    fi

    escaped="$password"
    escaped="''${escaped//\\/\\\\}"
    escaped="''${escaped//\"/\\\"}"

    tmp="$(mktemp -p /run/secrets ".${serviceName}.env.XXXXXX")"
    {
      printf 'SYNC_USER1="%s:%s"\n' ${lib.escapeShellArg cfg.account.username} "$escaped"
      printf 'SYNC_HOST="%s"\n' "0.0.0.0"
      ${lib.optionalString cfg.account.passwordsHashed ''
      printf 'PASSWORDS_HASHED="%s"\n' "1"
    ''}
    } > "$tmp"
    chmod 0600 "$tmp"
    mv -f "$tmp" /run/secrets/${serviceName}.env
  '';
in {
  options.services.ankiSyncCompose = {
    enable = lib.mkEnableOption "Anki self-hosted sync server (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = serviceName;
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
      default = "/var/lib/anki-sync";
      description = "Persistent host path used for Anki sync data.";
    };

    tls = lib.mkEnableOption "TLS on the Anki sync Traefik router";

    version = lib.mkOption {
      type = lib.types.str;
      default = "25.09.2";
      description = "Pinned upstream Anki version used to build the official sync server.";
    };

    uid = lib.mkOption {
      type = lib.types.int;
      default = 1000;
      description = "Container runtime UID passed to the official entrypoint.";
    };

    gid = lib.mkOption {
      type = lib.types.int;
      default = 1000;
      description = "Container runtime GID passed to the official entrypoint.";
    };

    account = {
      username = lib.mkOption {
        type = lib.types.str;
        default = "admin";
        description = "Sync account username exposed as `SYNC_USER1`.";
      };

      passwordFile = runtimeSecrets.mkSecretFileOption {
        description = ''
          Optional absolute path to a runtime-provisioned single-line password file.

          When unset, startup generates a password once at
          `''${dataDir}/auth/sync-password` and reuses it on later restarts.
        '';
        example = "/run/secrets/anki-sync-password";
      };

      passwordsHashed = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether the password file contains a PHC-format hash instead of plaintext.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.ankiSyncCompose.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.ankiSyncCompose.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.ankiSyncCompose.dataDir must be an absolute path.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.version != null;
        message = "services.ankiSyncCompose.version must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]:]+$" cfg.account.username != null;
        message = "services.ankiSyncCompose.account.username must not contain whitespace or ':'.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;
    environment.etc."${serviceName}/Dockerfile".source = ./Dockerfile;
    environment.etc."${serviceName}/entrypoint.sh".source = ./entrypoint.sh;

    systemd.services.${serviceName} = {
      description = "Anki self-hosted sync server (Docker Compose)";
      wantedBy = ["multi-user.target"];
      requires = ["docker.service"];
      after = ["docker.service" "network-online.target"];
      wants = ["network-online.target"];
      restartTriggers = [
        config.environment.etc."${serviceName}/docker-compose.yml".source
        config.environment.etc."${serviceName}/Dockerfile".source
        config.environment.etc."${serviceName}/entrypoint.sh".source
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = "/";
        TimeoutStartSec = 3600;
        Restart = "on-failure";
        RestartSec = 10;

        Environment = [
          "ANKI_SYNC_CONTAINER_NAME=${cfg.containerName}"
          "ANKI_SYNC_HOSTNAME=${cfg.hostname}"
          "ANKI_SYNC_NETWORK=${cfg.network}"
          "ANKI_SYNC_ENTRYPOINTS=${
            if cfg.tls
            then "websecure"
            else "web"
          }"
          "ANKI_SYNC_TLS=${
            if cfg.tls
            then "true"
            else "false"
          }"
          "ANKI_SYNC_DATA_DIR=${cfg.dataDir}"
          "ANKI_SYNC_VERSION=${cfg.version}"
          "ANKI_SYNC_RUNTIME_ENV_FILE=/run/secrets/${serviceName}.env"
          "ANKI_SYNC_PUID=${toString cfg.uid}"
          "ANKI_SYNC_PGID=${toString cfg.gid}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${composeDir}'"
          "${pkgs.runtimeShell} -c 'cp -f ${staticDir}/docker-compose.yml ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'cp -f ${staticDir}/Dockerfile ${composeDir}/Dockerfile'"
          "${pkgs.runtimeShell} -c 'cp -f ${staticDir}/entrypoint.sh ${composeDir}/entrypoint.sh && chmod 0755 ${composeDir}/entrypoint.sh'"
          "${pkgs.runtimeShell} -c 'mkdir -p ${lib.escapeShellArg cfg.dataDir} ${lib.escapeShellArg "${cfg.dataDir}/auth"}'"
          "${runtimeEnvScript}"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/Dockerfile'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/entrypoint.sh'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"${serviceName}: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${composeCmd} config >/dev/null'"
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${composeCmd} up -d --build";
        ExecStop = "${composeCmd} down";
      };
    };
  };
}
