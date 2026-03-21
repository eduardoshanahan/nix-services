{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.ghost;
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
  instanceNameRegex = "^[a-zA-Z0-9][a-zA-Z0-9-]*$";

  instanceSubmoduleOptions = name: {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable this Ghost instance.";
    };

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "ghost-${name}";
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
      default = "/var/lib/ghost-${name}";
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
        example = "mysql.internal.example";
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

  legacyInstance = {
    enable = cfg.enable;
    containerName = cfg.containerName;
    hostname = cfg.hostname;
    timezone = cfg.timezone;
    network = cfg.network;
    dataDir = cfg.dataDir;
    image = cfg.image;
    database = cfg.database;
    mail = cfg.mail;
    tls = cfg.tls;
  };

  effectiveInstances =
    if cfg.enable
    then {default = legacyInstance;}
    else lib.filterAttrs (_: instance: instance.enable) cfg.instances;

  hasEffectiveInstances = lib.length (lib.attrNames effectiveInstances) > 0;

  isLegacyInstance = name: cfg.enable && name == "default";
  instanceEtcDirName = name:
    if isLegacyInstance name
    then "ghost"
    else "ghost-${name}";
  instanceEtcComposeKey = name: "${instanceEtcDirName name}/docker-compose.yml";
  instanceServiceName = name:
    if isLegacyInstance name
    then "ghost"
    else "ghost-${name}";
  instanceComposeDir = name: "/etc/${instanceEtcDirName name}";
  instanceComposePath = name: "${instanceComposeDir name}/docker-compose.yml";
  instanceRuntimeEnvFile = name:
    if isLegacyInstance name
    then "/run/secrets/ghost.env"
    else "/run/secrets/ghost-${name}.env";
  instanceTraefikName = name:
    if isLegacyInstance name
    then "ghost"
    else "ghost-${name}";

  mkWriteRuntimeEnv = name: instance:
    pkgs.writeShellScript "ghost-${name}-write-runtime-env" ''
      set -euo pipefail
      umask 0077

      db_secret_file=${lib.escapeShellArg (toString instance.database.passwordFile)}
      mail_secret_file=${lib.escapeShellArg (
        if instance.mail.passwordFile == null
        then ""
        else toString instance.mail.passwordFile
      )}
      runtime_env_file=${lib.escapeShellArg (instanceRuntimeEnvFile name)}

      if [[ ! -s "$db_secret_file" ]]; then
        echo "ghost(${name}): missing or empty database password file: $db_secret_file" >&2
        exit 1
      fi

      db_password="$(cat "$db_secret_file")"
      db_password="''${db_password%$'\n'}"
      db_password="''${db_password%$'\r'}"

      if [[ -z "$db_password" ]]; then
        echo "ghost(${name}): database password file is empty after trimming" >&2
        exit 1
      fi

      escape_env() {
        local value="$1"
        value="''${value//\\/\\\\}"
        value="''${value//\"/\\\"}"
        printf '%s' "$value"
      }

      install -d -m 0700 /run/secrets
      tmp="$(mktemp -p /run/secrets '.ghost-${name}.env.XXXXXX')"

      printf 'database__connection__password="%s"\n' "$(escape_env "$db_password")" > "$tmp"

      if [[ -n "$mail_secret_file" ]]; then
        if [[ ! -s "$mail_secret_file" ]]; then
          echo "ghost(${name}): missing or empty mail password file: $mail_secret_file" >&2
          rm -f "$tmp"
          exit 1
        fi

        mail_password="$(cat "$mail_secret_file")"
        mail_password="''${mail_password%$'\n'}"
        mail_password="''${mail_password%$'\r'}"

        if [[ -z "$mail_password" ]]; then
          echo "ghost(${name}): mail password file is empty after trimming" >&2
          rm -f "$tmp"
          exit 1
        fi

        printf 'mail__options__auth__pass="%s"\n' "$(escape_env "$mail_password")" >> "$tmp"
      fi

      chmod 0600 "$tmp"
      mv -f "$tmp" "$runtime_env_file"
    '';

  mkWaitForHealthy = name: instance:
    pkgs.writeShellScript "ghost-${name}-wait-healthy" ''
      set -euo pipefail

      container_name=${instance.containerName}
      # Ghost's health window is longer than the simpler services, so the
      # systemd post-start wait needs to cover it plus a little boot-time slack.
      timeout_seconds=240
      deadline=$((SECONDS + timeout_seconds))

      while true; do
        status="$(${dockerBin} inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_name" 2>/dev/null || true)"

        case "$status" in
          healthy)
            exit 0
            ;;
          unhealthy)
            echo "ghost(${name}): container became unhealthy" >&2
            ${dockerBin} ps --filter "name=^/$container_name$" --format 'table {{.Names}}\t{{.Status}}' >&2 || true
            exit 1
            ;;
          starting|none|"")
            ;;
          *)
            echo "ghost(${name}): unexpected health status: $status" >&2
            ;;
        esac

        if [ "$SECONDS" -ge "$deadline" ]; then
          echo "ghost(${name}): timed out waiting for a healthy container (''${timeout_seconds}s)" >&2
          ${dockerBin} ps --filter "name=^/$container_name$" --format 'table {{.Names}}\t{{.Status}}' >&2 || true
          exit 1
        fi

        sleep 2
      done
    '';

  mkInstanceAssertions = name: instance: [
    {
      assertion = builtins.match instanceNameRegex name != null;
      message = "services.ghost.instances.${name}: instance name may only contain letters, numbers, and `-`, and must not start with `-`.";
    }
    {
      assertion = builtins.match hostnameRegex instance.hostname != null;
      message = "services.ghost.instances.${name}.hostname must be a valid DNS hostname.";
    }
    {
      assertion = builtins.match networkRegex instance.network != null;
      message = "services.ghost.instances.${name}.network may only contain letters, numbers, `.`, `_`, and `-`.";
    }
    {
      assertion = builtins.match "^[^[:space:]]+$" instance.image.repository != null;
      message = "services.ghost.instances.${name}.image.repository must not contain whitespace.";
    }
    {
      assertion = builtins.match "^[^[:space:]]+$" instance.image.tag != null;
      message = "services.ghost.instances.${name}.image.tag must not contain whitespace.";
    }
    {
      assertion = instance.image.allowMutableTag || instance.image.tag != "latest";
      message = "services.ghost.instances.${name}.image.tag must be pinned (not `latest`) unless services.ghost.instances.${name}.image.allowMutableTag = true.";
    }
    {
      assertion = lib.hasPrefix "/" instance.dataDir;
      message = "services.ghost.instances.${name}.dataDir must be an absolute path.";
    }
    {
      assertion = instance.database.host != "";
      message = "services.ghost.instances.${name}.database.host must be set when enabling Ghost.";
    }
    {
      assertion = instance.database.passwordFile != null;
      message = "services.ghost.instances.${name}.database.passwordFile must be set when enabling Ghost.";
    }
    {
      assertion = !instance.mail.enable || instance.mail.passwordFile != null;
      message = "services.ghost.instances.${name}.mail.passwordFile must be set when services.ghost.instances.${name}.mail.enable = true.";
    }
  ];

  allAssertions =
    [
      {
        assertion = !(cfg.enable && cfg.instances != {});
        message = "Use either legacy services.ghost.* options or services.ghost.instances, not both at once.";
      }
    ]
    ++ lib.concatMap (name: mkInstanceAssertions name effectiveInstances.${name}) (lib.attrNames effectiveInstances);
in {
  options.services.ghost = {
    enable = lib.mkEnableOption "Ghost blog service (Docker Compose)";

    # Legacy single-instance options kept for compatibility.
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
        example = "mysql.internal.example";
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

    instances = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({name, ...}: {
        options = instanceSubmoduleOptions name;
      }));
      default = {};
      description = ''
        Multi-instance Ghost configuration. Each key defines one blog instance
        (e.g. `services.ghost.instances.main`, `services.ghost.instances.docs`).
      '';
    };
  };

  config = lib.mkIf hasEffectiveInstances {
    assertions = allAssertions;

    virtualisation.docker.enable = true;

    environment.etc = lib.mkMerge (lib.mapAttrsToList (
        name: _instance: {
          "${instanceEtcComposeKey name}".source = ./docker-compose.yml;
        }
      )
      effectiveInstances);

    systemd.services = lib.mkMerge (lib.mapAttrsToList (
        name: instance: let
          composeEtcKey = instanceEtcComposeKey name;
          composePath = instanceComposePath name;
          composeDir = instanceComposeDir name;
          runtimeEnvFile = instanceRuntimeEnvFile name;
          traefikName = instanceTraefikName name;
        in {
          "${instanceServiceName name}" = {
            description = "Ghost blog (${name}) (Docker Compose)";

            wantedBy = ["multi-user.target"];
            requires = ["docker.service"];
            after = ["docker.service" "network-online.target"];
            wants = ["network-online.target"];
            restartTriggers = [
              config.environment.etc."${composeEtcKey}".source
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
                "GHOST_CONTAINER_NAME=${instance.containerName}"
                "GHOST_IMAGE_REPOSITORY=${instance.image.repository}"
                "GHOST_IMAGE_TAG=${instance.image.tag}"
                "GHOST_NETWORK=${instance.network}"
                "GHOST_HOSTNAME=${instance.hostname}"
                "GHOST_ENTRYPOINTS=${if instance.tls then "websecure" else "web"}"
                "GHOST_TLS=${if instance.tls then "true" else "false"}"
                "GHOST_URL=${if instance.tls then "https" else "http"}://${instance.hostname}"
                "GHOST_DATA_DIR=${instance.dataDir}"
                "GHOST_DATABASE_HOST=${instance.database.host}"
                "GHOST_DATABASE_PORT=${toString instance.database.port}"
                "GHOST_DATABASE_NAME=${instance.database.name}"
                "GHOST_DATABASE_USER=${instance.database.user}"
                "GHOST_MAIL_TRANSPORT=${if instance.mail.enable then "SMTP" else "Direct"}"
                "GHOST_MAIL_FROM=${if instance.mail.enable then instance.mail.from else ""}"
                "GHOST_MAIL_HOST=${if instance.mail.enable then instance.mail.host else ""}"
                "GHOST_MAIL_PORT=${if instance.mail.enable then toString instance.mail.port else ""}"
                "GHOST_MAIL_SECURE=${if instance.mail.enable && instance.mail.secure then "true" else "false"}"
                "GHOST_MAIL_USER=${if instance.mail.enable then instance.mail.user else ""}"
                "GHOST_RUNTIME_ENV_FILE=${runtimeEnvFile}"
                "GHOST_TRAEFIK_ROUTER_NAME=${traefikName}"
                "GHOST_TRAEFIK_SERVICE_NAME=${traefikName}"
                "TZ=${instance.timezone}"
              ];

              ExecStartPre = [
                "${pkgs.runtimeShell} -c 'mkdir -p ${instance.dataDir} && chown 1000:1000 ${instance.dataDir} && chmod 0750 ${instance.dataDir}'"
                "${pkgs.runtimeShell} -c 'test -s ${composePath}'"
                "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"ghost(${name}): docker daemon is not ready\" >&2; exit 1'"
                (mkWriteRuntimeEnv name instance)
                "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
                "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${instance.network} >/dev/null 2>&1 || ${dockerBin} network create ${instance.network}'"
              ];

              ExecStart = "${dockerBin} compose up -d";
              ExecStartPost = mkWaitForHealthy name instance;
              ExecStop = "${dockerBin} compose down";
            };
          };
        }
      )
      effectiveInstances);
  };
}
