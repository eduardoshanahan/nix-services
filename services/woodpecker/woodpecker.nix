{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.woodpeckerCompose;
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};
  serviceName = "woodpecker";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
  backendVolumeRegex = "^[^[:space:]]+:[^[:space:]]+(:[A-Za-z,]+)?$";
  runtimeEnvScript = pkgs.writeShellScript "${serviceName}-runtime-env" ''
    set -euo pipefail
    umask 0077

    agent_secret_file=${lib.escapeShellArg (toString cfg.agent.secretFile)}
    gitea_client_file=${lib.escapeShellArg (toString cfg.gitea.clientIdFile)}
    gitea_secret_file=${lib.escapeShellArg (toString cfg.gitea.clientSecretFile)}
    db_password_file=${lib.escapeShellArg (toString cfg.database.postgres.passwordFile)}
    db_host=${lib.escapeShellArg cfg.database.postgres.host}
    db_port=${lib.escapeShellArg (toString cfg.database.postgres.port)}
    db_name=${lib.escapeShellArg cfg.database.postgres.name}
    db_user=${lib.escapeShellArg cfg.database.postgres.user}
    db_sslmode=${lib.escapeShellArg cfg.database.postgres.sslMode}
    server_env_file="/run/secrets/woodpecker-server.env"
    agent_env_file="/run/secrets/woodpecker-agent.env"

    install -d -m 0700 /run/secrets

    trim_secret() {
      local file="$1"
      local label="$2"
      local value

      if [[ ! -s "$file" ]]; then
        echo "woodpecker: missing or empty $label file: $file" >&2
        exit 1
      fi

      value="$(cat "$file")"
      value="''${value%$'\n'}"
      value="''${value%$'\r'}"

      if [[ -z "$value" ]]; then
        echo "woodpecker: $label file is empty after trimming: $file" >&2
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

    agent_secret="$(trim_secret "$agent_secret_file" "agent secret")"
    gitea_client="$(trim_secret "$gitea_client_file" "Gitea client ID")"
    gitea_secret="$(trim_secret "$gitea_secret_file" "Gitea client secret")"
    db_password="$(trim_secret "$db_password_file" "Postgres password")"
    db_dsn="postgres://$db_user:$db_password@$db_host:$db_port/$db_name?sslmode=$db_sslmode"

    server_tmp="$(mktemp -p /run/secrets '.woodpecker-server.env.XXXXXX')"
    agent_tmp="$(mktemp -p /run/secrets '.woodpecker-agent.env.XXXXXX')"

    {
      printf 'WOODPECKER_AGENT_SECRET="%s"\n' "$(escape_env "$agent_secret")"
      printf 'WOODPECKER_GITEA_CLIENT="%s"\n' "$(escape_env "$gitea_client")"
      printf 'WOODPECKER_GITEA_SECRET="%s"\n' "$(escape_env "$gitea_secret")"
      printf 'WOODPECKER_DATABASE_DRIVER="postgres"\n'
      printf 'WOODPECKER_DATABASE_DATASOURCE="%s"\n' "$(escape_env "$db_dsn")"
    } > "$server_tmp"

    {
      printf 'WOODPECKER_AGENT_SECRET="%s"\n' "$(escape_env "$agent_secret")"
    } > "$agent_tmp"

    chmod 0600 "$server_tmp" "$agent_tmp"
    mv -f "$server_tmp" "$server_env_file"
    mv -f "$agent_tmp" "$agent_env_file"
  '';
in {
  options.services.woodpeckerCompose = {
    enable = lib.mkEnableOption "Woodpecker CI server with a colocated agent (Docker Compose)";

    hostname = lib.mkOption {
      type = lib.types.str;
      description = "Public hostname used for the Woodpecker UI.";
    };

    timezone = lib.mkOption {
      type = lib.types.str;
      default = "UTC";
      description = "Timezone passed to the containers via `TZ`.";
    };

    network = lib.mkOption {
      type = lib.types.str;
      default = "traefik";
      description = "External Docker network name shared with Traefik.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/woodpecker";
      description = "Persistent host path used for Woodpecker server state.";
    };

    tls = lib.mkEnableOption "TLS on the Woodpecker Traefik router";

    openRegistration = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether Woodpecker allows open repo activation/registration.";
    };

    adminUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Comma-joined list of Woodpecker admin usernames.";
    };

    server = {
      containerName = lib.mkOption {
        type = lib.types.str;
        default = "woodpecker-server";
        description = "Docker container name for the Woodpecker server.";
      };

      grpcBindAddress = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0";
        description = "Host bind address for the published gRPC listener.";
      };

      grpcPort = lib.mkOption {
        type = lib.types.port;
        default = 9000;
        description = "Host TCP port used by agents to reach the server gRPC endpoint.";
      };

      image = {
        repository = lib.mkOption {
          type = lib.types.str;
          default = "woodpeckerci/woodpecker-server";
          description = "Container image repository for the Woodpecker server.";
        };

        tag = lib.mkOption {
          type = lib.types.str;
          default = "latest";
          description = "Container image tag for the Woodpecker server.";
        };

        allowMutableTag = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Allow mutable tags such as `latest`.";
        };
      };
    };

    gitea = {
      url = lib.mkOption {
        type = lib.types.str;
        default = "https://gitea.<homelab-domain>";
        description = "Base URL for the Gitea/Forge instance.";
      };

      clientIdFile = runtimeSecrets.mkSecretFileOption {
        description = "Absolute path to the Gitea OAuth client ID file.";
        example = "/run/secrets/woodpecker-gitea-client";
      };

      clientSecretFile = runtimeSecrets.mkSecretFileOption {
        description = "Absolute path to the Gitea OAuth client secret file.";
        example = "/run/secrets/woodpecker-gitea-secret";
      };
    };

    database = {
      postgres = {
        host = lib.mkOption {
          type = lib.types.str;
          default = "postgres.<homelab-domain>";
          description = "PostgreSQL host for the Woodpecker server.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 5433;
          description = "PostgreSQL port for the Woodpecker server.";
        };

        name = lib.mkOption {
          type = lib.types.str;
          default = "woodpecker";
          description = "PostgreSQL database name for the Woodpecker server.";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = "woodpecker";
          description = "PostgreSQL username for the Woodpecker server.";
        };

        passwordFile = runtimeSecrets.mkSecretFileOption {
          description = "Absolute path to the Woodpecker PostgreSQL password file.";
          example = "/run/secrets/woodpecker-postgres-password";
        };

        sslMode = lib.mkOption {
          type = lib.types.enum [
            "disable"
            "require"
            "verify-ca"
            "verify-full"
          ];
          default = "disable";
          description = "sslmode passed in the PostgreSQL DSN.";
        };
      };
    };

    agent = {
      containerName = lib.mkOption {
        type = lib.types.str;
        default = "woodpecker-agent";
        description = "Docker container name for the colocated Woodpecker agent.";
      };

      hostname = lib.mkOption {
        type = lib.types.str;
        default = "rpi-box-02";
        description = "Logical agent hostname reported to Woodpecker.";
      };

      server = lib.mkOption {
        type = lib.types.str;
        default = "woodpecker-server:9000";
        description = "gRPC server endpoint used by the colocated agent.";
      };

      secretFile = runtimeSecrets.mkSecretFileOption {
        description = "Absolute path to the shared Woodpecker agent secret file.";
        example = "/run/secrets/woodpecker-agent-secret";
      };

      maxWorkflows = lib.mkOption {
        type = lib.types.ints.positive;
        default = 1;
        description = "Maximum concurrent workflows accepted by the colocated agent.";
      };

      socketPath = lib.mkOption {
        type = lib.types.str;
        default = "/var/run/docker.sock";
        description = "Host Docker socket path bind-mounted into the agent.";
      };

      backendDockerNetwork = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional Docker network name passed as WOODPECKER_BACKEND_DOCKER_NETWORK.";
      };

      backendDockerVolumes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "/etc/ssl/certs:/etc/ssl/certs:ro" ];
        description = "Volumes injected into CI job containers via WOODPECKER_BACKEND_DOCKER_VOLUMES.";
      };

      image = {
        repository = lib.mkOption {
          type = lib.types.str;
          default = "woodpeckerci/woodpecker-agent";
          description = "Container image repository for the Woodpecker agent.";
        };

        tag = lib.mkOption {
          type = lib.types.str;
          default = "latest";
          description = "Container image tag for the Woodpecker agent.";
        };

        allowMutableTag = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Allow mutable tags such as `latest`.";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.woodpeckerCompose.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.woodpeckerCompose.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.server.image.repository != null;
        message = "services.woodpeckerCompose.server.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.server.image.tag != null;
        message = "services.woodpeckerCompose.server.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.server.image.allowMutableTag || cfg.server.image.tag != "latest";
        message = "services.woodpeckerCompose.server.image.tag must be pinned unless allowMutableTag = true.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.agent.image.repository != null;
        message = "services.woodpeckerCompose.agent.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.agent.image.tag != null;
        message = "services.woodpeckerCompose.agent.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.agent.image.allowMutableTag || cfg.agent.image.tag != "latest";
        message = "services.woodpeckerCompose.agent.image.tag must be pinned unless allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.woodpeckerCompose.dataDir must be an absolute path.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.agent.socketPath;
        message = "services.woodpeckerCompose.agent.socketPath must be an absolute path.";
      }
      {
        assertion = cfg.gitea.clientIdFile != null;
        message = "services.woodpeckerCompose.gitea.clientIdFile must be set.";
      }
      {
        assertion = cfg.gitea.clientSecretFile != null;
        message = "services.woodpeckerCompose.gitea.clientSecretFile must be set.";
      }
      {
        assertion = cfg.database.postgres.passwordFile != null;
        message = "services.woodpeckerCompose.database.postgres.passwordFile must be set.";
      }
      {
        assertion = cfg.agent.secretFile != null;
        message = "services.woodpeckerCompose.agent.secretFile must be set.";
      }
      {
        assertion = lib.all (volume: builtins.match backendVolumeRegex volume != null) cfg.agent.backendDockerVolumes;
        message = "services.woodpeckerCompose.agent.backendDockerVolumes entries must look like host:container[:mode].";
      }
      {
        assertion = cfg.agent.backendDockerNetwork == null || builtins.match networkRegex cfg.agent.backendDockerNetwork != null;
        message = "services.woodpeckerCompose.agent.backendDockerNetwork may only contain letters, numbers, `.`, `_`, and `-`.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "Woodpecker CI (Docker Compose)";
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
        TimeoutStartSec = 180;
        Restart = "on-failure";
        RestartSec = 10;

        Environment = [
          "WOODPECKER_SERVER_CONTAINER_NAME=${cfg.server.containerName}"
          "WOODPECKER_SERVER_IMAGE_REPOSITORY=${cfg.server.image.repository}"
          "WOODPECKER_SERVER_IMAGE_TAG=${cfg.server.image.tag}"
          "WOODPECKER_SERVER_GRPC_BIND=${cfg.server.grpcBindAddress}"
          "WOODPECKER_SERVER_GRPC_PORT=${toString cfg.server.grpcPort}"
          "WOODPECKER_SERVER_RUNTIME_ENV_FILE=/run/secrets/woodpecker-server.env"
          "WOODPECKER_AGENT_CONTAINER_NAME=${cfg.agent.containerName}"
          "WOODPECKER_AGENT_IMAGE_REPOSITORY=${cfg.agent.image.repository}"
          "WOODPECKER_AGENT_IMAGE_TAG=${cfg.agent.image.tag}"
          "WOODPECKER_AGENT_RUNTIME_ENV_FILE=/run/secrets/woodpecker-agent.env"
          "WOODPECKER_AGENT_SERVER=${cfg.agent.server}"
          "WOODPECKER_AGENT_HOSTNAME=${cfg.agent.hostname}"
          "WOODPECKER_AGENT_MAX_WORKFLOWS=${toString cfg.agent.maxWorkflows}"
          "WOODPECKER_AGENT_SOCKET_PATH=${cfg.agent.socketPath}"
          "WOODPECKER_AGENT_BACKEND_DOCKER_NETWORK=${if cfg.agent.backendDockerNetwork == null then "" else cfg.agent.backendDockerNetwork}"
          "WOODPECKER_AGENT_BACKEND_DOCKER_VOLUMES=${lib.concatStringsSep "," cfg.agent.backendDockerVolumes}"
          "WOODPECKER_NETWORK=${cfg.network}"
          "WOODPECKER_HOSTNAME=${cfg.hostname}"
          "WOODPECKER_HOST_URL=${if cfg.tls then "https" else "http"}://${cfg.hostname}"
          "WOODPECKER_ENTRYPOINTS=${if cfg.tls then "websecure" else "web"}"
          "WOODPECKER_TLS=${if cfg.tls then "true" else "false"}"
          "WOODPECKER_OPEN=${if cfg.openRegistration then "true" else "false"}"
          "WOODPECKER_ADMIN_USERS=${lib.concatStringsSep "," cfg.adminUsers}"
          "WOODPECKER_GITEA_URL=${cfg.gitea.url}"
          "WOODPECKER_DATA_DIR=${cfg.dataDir}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${lib.escapeShellArg cfg.dataDir}'"
          "${pkgs.runtimeShell} -c 'test -S ${cfg.agent.socketPath}'"
          "${pkgs.runtimeShell} -c 'test -r /etc/ssl/certs/homelab-root-ca.crt'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          runtimeEnvScript
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"woodpecker: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
