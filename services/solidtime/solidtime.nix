{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.solidtimeCompose;
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};
  serviceName = "solidtime";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
  writeRuntimeEnv = pkgs.writeShellScript "solidtime-write-runtime-env" ''
    set -euo pipefail
    umask 0077

    secret_file=${lib.escapeShellArg (toString cfg.secretFile)}

    if [[ ! -s "$secret_file" ]]; then
      echo "solidtime: missing or empty secret env file: $secret_file" >&2
      exit 1
    fi

    for required_key in APP_KEY PASSPORT_PRIVATE_KEY PASSPORT_PUBLIC_KEY DB_PASSWORD; do
      if ! grep -q "^''${required_key}=" "$secret_file"; then
        echo "solidtime: required key ''${required_key}= missing from $secret_file" >&2
        exit 1
      fi
    done

    install -d -m 0700 /run/secrets
    tmp="$(mktemp -p /run/secrets '.solidtime.env.XXXXXX')"
    cat "$secret_file" > "$tmp"
    chmod 0600 "$tmp"
    mv -f "$tmp" /run/secrets/solidtime.env
  '';
  waitForHealthy = pkgs.writeShellScript "solidtime-wait-healthy" ''
    set -euo pipefail

    container_name=${cfg.containerNameApp}
    timeout_seconds=240
    deadline=$((SECONDS + timeout_seconds))

    while true; do
      status="$(${dockerBin} inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_name" 2>/dev/null || true)"

      case "$status" in
        healthy)
          exit 0
          ;;
        unhealthy)
          echo "solidtime: app container became unhealthy" >&2
          ${dockerBin} ps --filter "name=^/$container_name$" --format 'table {{.Names}}\t{{.Status}}' >&2 || true
          exit 1
          ;;
        starting|none|"")
          ;;
        *)
          echo "solidtime: unexpected health status: $status" >&2
          ;;
      esac

      if [ "$SECONDS" -ge "$deadline" ]; then
        echo "solidtime: timed out waiting for healthy app container (''${timeout_seconds}s)" >&2
        ${dockerBin} ps --filter "name=^/$container_name$" --format 'table {{.Names}}\t{{.Status}}' >&2 || true
        exit 1
      fi

      sleep 2
    done
  '';
  appUrl = "${if cfg.tls then "https" else "http"}://${cfg.hostname}";
in {
  options.services.solidtimeCompose = {
    enable = lib.mkEnableOption "Solidtime service (Docker Compose)";

    containerNameApp = lib.mkOption {
      type = lib.types.str;
      default = "solidtime-app";
      description = "Docker container name for Solidtime app container.";
    };

    containerNameScheduler = lib.mkOption {
      type = lib.types.str;
      default = "solidtime-scheduler";
      description = "Docker container name for Solidtime scheduler container.";
    };

    containerNameQueue = lib.mkOption {
      type = lib.types.str;
      default = "solidtime-queue";
      description = "Docker container name for Solidtime queue worker container.";
    };

    containerNameGotenberg = lib.mkOption {
      type = lib.types.str;
      default = "solidtime-gotenberg";
      description = "Docker container name for bundled Gotenberg container.";
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
      description = "External Docker network name used by Traefik and downstream services.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host listen address mapped to Solidtime HTTP port 8000.";
    };

    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 3800;
      description = "Host listen port mapped to Solidtime HTTP port 8000.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open `listenPort` in host firewall.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/solidtime";
      description = "Persistent host path used for Solidtime storage and logs.";
    };

    appName = lib.mkOption {
      type = lib.types.str;
      default = "solidtime";
      description = "Application name exposed to Laravel and frontend build.";
    };

    trustedProxies = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0/0,2000:0:0:0:0:0:0:0/3";
      description = "Trusted proxy CIDR list passed to `TRUSTED_PROXIES`.";
    };

    enableRegistration = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow user self-registration in Solidtime.";
    };

    logLevel = lib.mkOption {
      type = lib.types.str;
      default = "info";
      description = "Application log level.";
    };

    secretFile = runtimeSecrets.mkSecretFileOption {
      description = ''
        Absolute path to a runtime-provisioned dotenv file consumed by Solidtime.
        It must include at least APP_KEY, PASSPORT_PRIVATE_KEY,
        PASSPORT_PUBLIC_KEY, and DB_PASSWORD.
      '';
      example = "/run/secrets/solidtime-secrets.env";
    };

    database = {
      host = lib.mkOption {
        type = lib.types.str;
        default = "postgres.<homelab-domain>";
        description = "PostgreSQL host reachable from the Solidtime host.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 5433;
        description = "PostgreSQL TCP port.";
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "solidtime";
        description = "PostgreSQL database name for Solidtime.";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "solidtime";
        description = "PostgreSQL username for Solidtime.";
      };

      sslmode = lib.mkOption {
        type = lib.types.str;
        default = "disable";
        description = "PostgreSQL SSL mode (for example `disable`, `require`).";
      };
    };

    mail = {
      host = lib.mkOption {
        type = lib.types.str;
        default = "smtp-relay.<homelab-domain>";
        description = "SMTP host used by Solidtime.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 2525;
        description = "SMTP TCP port used by Solidtime.";
      };

      encryption = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "MAIL_ENCRYPTION value passed to Solidtime (for example `tls`).";
      };

      fromAddress = lib.mkOption {
        type = lib.types.str;
        default = "no-reply@solidtime.internal.example";
        description = "Sender address for Solidtime mail.";
      };

      fromName = lib.mkOption {
        type = lib.types.str;
        default = "solidtime";
        description = "Sender display name for Solidtime mail.";
      };

      username = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "SMTP username for Solidtime. Keep empty for unauthenticated relay.";
      };
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "solidtime/solidtime";
        description = "Solidtime image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "latest";
        description = "Solidtime image tag.";
      };

      allowMutableTag = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Allow mutable tags such as `latest`.";
      };
    };

    gotenberg = {
      image = {
        repository = lib.mkOption {
          type = lib.types.str;
          default = "gotenberg/gotenberg";
          description = "Gotenberg image repository.";
        };

        tag = lib.mkOption {
          type = lib.types.str;
          default = "8.15";
          description = "Gotenberg image tag.";
        };

        allowMutableTag = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Allow mutable Gotenberg tags such as `latest`.";
        };
      };
    };

    tls = lib.mkEnableOption "TLS on the Solidtime Traefik router";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.solidtimeCompose.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.solidtimeCompose.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.solidtimeCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.solidtimeCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.solidtimeCompose.image.tag must be pinned (not `latest`) unless services.solidtimeCompose.image.allowMutableTag = true.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.gotenberg.image.repository != null;
        message = "services.solidtimeCompose.gotenberg.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.gotenberg.image.tag != null;
        message = "services.solidtimeCompose.gotenberg.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.gotenberg.image.allowMutableTag || cfg.gotenberg.image.tag != "latest";
        message = "services.solidtimeCompose.gotenberg.image.tag must be pinned (not `latest`) unless services.solidtimeCompose.gotenberg.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.solidtimeCompose.dataDir must be an absolute path.";
      }
      {
        assertion = cfg.secretFile != null;
        message = "services.solidtimeCompose.secretFile must be set when enabling Solidtime.";
      }
      {
        assertion = cfg.database.host != "";
        message = "services.solidtimeCompose.database.host must be set when enabling Solidtime.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "Solidtime (Docker Compose)";

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
        TimeoutStartSec = 1800;
        Restart = "on-failure";
        RestartSec = 10;
        WorkingDirectory = composeDir;

        Environment = [
          "SOLIDTIME_IMAGE_REPOSITORY=${cfg.image.repository}"
          "SOLIDTIME_IMAGE_TAG=${cfg.image.tag}"
          "SOLIDTIME_GOTENBERG_IMAGE_REPOSITORY=${cfg.gotenberg.image.repository}"
          "SOLIDTIME_GOTENBERG_IMAGE_TAG=${cfg.gotenberg.image.tag}"
          "SOLIDTIME_APP_CONTAINER_NAME=${cfg.containerNameApp}"
          "SOLIDTIME_SCHEDULER_CONTAINER_NAME=${cfg.containerNameScheduler}"
          "SOLIDTIME_QUEUE_CONTAINER_NAME=${cfg.containerNameQueue}"
          "SOLIDTIME_GOTENBERG_CONTAINER_NAME=${cfg.containerNameGotenberg}"
          "SOLIDTIME_LISTEN_ADDRESS=${cfg.listenAddress}"
          "SOLIDTIME_LISTEN_PORT=${toString cfg.listenPort}"
          "SOLIDTIME_NETWORK=${cfg.network}"
          "SOLIDTIME_HOSTNAME=${cfg.hostname}"
          "SOLIDTIME_ENTRYPOINTS=${if cfg.tls then "websecure" else "web"}"
          "SOLIDTIME_TLS=${if cfg.tls then "true" else "false"}"
          "SOLIDTIME_APP_URL=${appUrl}"
          "SOLIDTIME_DATA_DIR=${cfg.dataDir}"
          "SOLIDTIME_APP_NAME=${cfg.appName}"
          "SOLIDTIME_FORCE_HTTPS=${if cfg.tls then "true" else "false"}"
          "SOLIDTIME_TRUSTED_PROXIES=${cfg.trustedProxies}"
          "SOLIDTIME_ENABLE_REGISTRATION=${if cfg.enableRegistration then "true" else "false"}"
          "SOLIDTIME_LOG_LEVEL=${cfg.logLevel}"
          "SOLIDTIME_DB_HOST=${cfg.database.host}"
          "SOLIDTIME_DB_PORT=${toString cfg.database.port}"
          "SOLIDTIME_DB_SSLMODE=${cfg.database.sslmode}"
          "SOLIDTIME_DB_DATABASE=${cfg.database.name}"
          "SOLIDTIME_DB_USERNAME=${cfg.database.user}"
          "SOLIDTIME_MAIL_HOST=${cfg.mail.host}"
          "SOLIDTIME_MAIL_PORT=${toString cfg.mail.port}"
          "SOLIDTIME_MAIL_ENCRYPTION=${cfg.mail.encryption}"
          "SOLIDTIME_MAIL_FROM_ADDRESS=${cfg.mail.fromAddress}"
          "SOLIDTIME_MAIL_FROM_NAME=${cfg.mail.fromName}"
          "SOLIDTIME_MAIL_USERNAME=${cfg.mail.username}"
          "SOLIDTIME_SECRET_ENV_FILE=/run/secrets/solidtime.env"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${cfg.dataDir} ${cfg.dataDir}/storage ${cfg.dataDir}/logs ${cfg.dataDir}/app && chown -R 1000:1000 ${cfg.dataDir} && chmod -R u+rwX,g+rX,o-rwx ${cfg.dataDir}'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"solidtime: docker daemon is not ready\" >&2; exit 1'"
          writeRuntimeEnv
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStartPost = waitForHealthy;
        ExecStop = "${dockerBin} compose down";
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [cfg.listenPort];
  };
}
