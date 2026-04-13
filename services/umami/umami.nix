{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.umamiCompose;
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};
  serviceName = "umami";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  portType = lib.types.ints.between 1 65535;
  runtimeEnvFile = "/run/secrets/umami.env";
in {
  options.services.umamiCompose = {
    enable = lib.mkEnableOption "Umami web analytics (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "umami";
      description = "Docker container name.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Host listen address for the Umami web interface.";
      example = "192.0.2.10";
    };

    listenPort = lib.mkOption {
      type = portType;
      default = 3000;
      description = "Host TCP port mapped to Umami port 3000.";
    };

    traefik = {
      enable = lib.mkEnableOption "Traefik integration (disables port mapping)";

      hostname = lib.mkOption {
        type = lib.types.str;
        description = "Public hostname for Traefik routing.";
        example = "analytics.example.com";
      };

      network = lib.mkOption {
        type = lib.types.str;
        default = "traefik";
        description = "Docker network name for Traefik.";
      };
    };

    database = {
      type = lib.mkOption {
        type = lib.types.enum ["mysql" "postgresql"];
        default = "postgresql";
        description = "Database type (mysql or postgresql).";
      };

      host = lib.mkOption {
        type = lib.types.str;
        description = "Database hostname or IP reachable from the Umami host.";
        example = "db.internal.example";
      };

      port = lib.mkOption {
        type = portType;
        default = 5432;
        description = "Database TCP port.";
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "umami";
        description = "Database name for Umami.";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "umami";
        description = "Database username for Umami.";
      };

      passwordFile = runtimeSecrets.mkSecretFileOption {
        description = ''
          Absolute path to a runtime-provisioned file containing the database password
          for the Umami database user.
        '';
        example = "/run/secrets/umami_db_password";
      };
    };

    appSecretFile = runtimeSecrets.mkSecretFileOption {
      description = ''
        Absolute path to a runtime-provisioned file containing the APP_SECRET
        (random hash salt) for Umami.
      '';
      example = "/run/secrets/umami_app_secret";
    };

    trackerScriptName = lib.mkOption {
      type = lib.types.str;
      default = "script.js";
      description = ''
        Custom name for the tracker script endpoint (helps evade ad blockers).
        Default is "script.js". Examples: "getinfo", "stats.js", "analytics.js".
      '';
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "ghcr.io/umami-software/umami";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "postgresql-latest";
        description = "Container image tag.";
      };

      allowMutableTag = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Allow mutable tags such as `latest` or `postgresql-latest`.
          Enabled by default for Umami to track latest releases.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.umamiCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.umamiCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.umamiCompose.image.tag must be pinned (not `latest`) unless services.umamiCompose.image.allowMutableTag = true.";
      }
      {
        assertion = cfg.database.host != "";
        message = "services.umamiCompose.database.host must be set when enabling Umami.";
      }
      {
        assertion = cfg.database.passwordFile != null;
        message = "services.umamiCompose.database.passwordFile must be set when enabling Umami.";
      }
      {
        assertion = cfg.appSecretFile != null;
        message = "services.umamiCompose.appSecretFile must be set when enabling Umami.";
      }
      {
        assertion = !cfg.traefik.enable || cfg.traefik.hostname != "";
        message = "services.umamiCompose.traefik.hostname must be set when Traefik integration is enabled.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = let
      mkWriteRuntimeEnv = pkgs.writeShellScript "umami-write-runtime-env" ''
        set -euo pipefail
        umask 0077

        db_secret_file=${lib.escapeShellArg (toString cfg.database.passwordFile)}
        app_secret_file=${lib.escapeShellArg (toString cfg.appSecretFile)}
        runtime_env_file=${lib.escapeShellArg runtimeEnvFile}

        if [[ ! -s "$db_secret_file" ]]; then
          echo "umami: missing or empty database password file: $db_secret_file" >&2
          exit 1
        fi

        if [[ ! -s "$app_secret_file" ]]; then
          echo "umami: missing or empty app secret file: $app_secret_file" >&2
          exit 1
        fi

        db_password="$(cat "$db_secret_file")"
        db_password="''${db_password%$'\n'}"
        db_password="''${db_password%$'\r'}"

        if [[ -z "$db_password" ]]; then
          echo "umami: database password file is empty after trimming" >&2
          exit 1
        fi

        app_secret="$(cat "$app_secret_file")"
        app_secret="''${app_secret%$'\n'}"
        app_secret="''${app_secret%$'\r'}"

        if [[ -z "$app_secret" ]]; then
          echo "umami: app secret file is empty after trimming" >&2
          exit 1
        fi

        # URL-encode password for DATABASE_URL
        # Using Python urllib.parse.quote for reliable URL encoding
        encoded_password="$(${pkgs.python3}/bin/python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip(), safe=""))' <<< "$db_password")"

        install -d -m 0700 /run/secrets
        tmp="$(mktemp -p /run/secrets '.umami.env.XXXXXX')"

        printf 'DATABASE_URL=%s://%s:%s@%s:%s/%s\n' \
          "${cfg.database.type}" \
          "${cfg.database.user}" \
          "$encoded_password" \
          "${cfg.database.host}" \
          "${toString cfg.database.port}" \
          "${cfg.database.name}" > "$tmp"

        printf 'APP_SECRET=%s\n' "$app_secret" >> "$tmp"

        chmod 0600 "$tmp"
        mv -f "$tmp" "$runtime_env_file"
      '';

      mkWaitForHealthy = pkgs.writeShellScript "umami-wait-healthy" ''
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
              echo "umami: container became unhealthy" >&2
              ${dockerBin} ps --filter "name=^/$container_name$" --format 'table {{.Names}}\t{{.Status}}' >&2 || true
              exit 1
              ;;
            starting|none|"")
              ;;
            *)
              echo "umami: unexpected health status: $status" >&2
              ;;
          esac

          if [ "$SECONDS" -ge "$deadline" ]; then
            echo "umami: timed out waiting for a healthy container (''${timeout_seconds}s)" >&2
            ${dockerBin} ps --filter "name=^/$container_name$" --format 'table {{.Names}}\t{{.Status}}' >&2 || true
            exit 1
          fi

          sleep 2
        done
      '';
    in {
      description = "Umami web analytics (Docker Compose)";
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
        TimeoutStartSec = 180;
        Restart = "on-failure";
        RestartSec = 10;
        WorkingDirectory = composeDir;

        Environment =
          [
            "UMAMI_CONTAINER_NAME=${cfg.containerName}"
            "UMAMI_LISTEN_ADDRESS=${cfg.listenAddress}"
            "UMAMI_LISTEN_PORT=${toString cfg.listenPort}"
            "UMAMI_IMAGE_REPOSITORY=${cfg.image.repository}"
            "UMAMI_IMAGE_TAG=${cfg.image.tag}"
            "UMAMI_RUNTIME_ENV_FILE=${runtimeEnvFile}"
            "UMAMI_TRACKER_SCRIPT_NAME=${cfg.trackerScriptName}"
          ]
          ++ lib.optionals cfg.traefik.enable [
            "UMAMI_TRAEFIK_ENABLED=true"
            "UMAMI_TRAEFIK_HOSTNAME=${cfg.traefik.hostname}"
            "UMAMI_TRAEFIK_NETWORK=${cfg.traefik.network}"
          ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"umami: docker daemon is not ready\" >&2; exit 1'"
          mkWriteRuntimeEnv
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStartPost = mkWaitForHealthy;
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
