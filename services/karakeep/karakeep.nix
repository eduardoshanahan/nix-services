{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.karakeepCompose;
  serviceName = "karakeep";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
in {
  options.services.karakeepCompose = {
    enable = lib.mkEnableOption "KaraKeep service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "karakeep";
      description = "Docker container name for the KaraKeep web app.";
    };

    hostname = lib.mkOption {
      type = lib.types.str;
      description = "Hostname used for the Traefik router `Host()` rule.";
    };

    timezone = lib.mkOption {
      type = lib.types.str;
      default = "UTC";
      description = "Timezone passed to the KaraKeep container via `TZ`.";
    };

    network = lib.mkOption {
      type = lib.types.str;
      default = "traefik";
      description = "External Docker network name used by Traefik and downstream services.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/karakeep";
      description = "Persistent host path used for KaraKeep data.";
    };

    meilisearchDataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/karakeep-meilisearch";
      description = "Persistent host path used for Meilisearch data.";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "ghcr.io/karakeep-app/karakeep";
        description = "KaraKeep image repository.";
      };

      version = lib.mkOption {
        type = lib.types.str;
        default = "release";
        description = "KaraKeep image tag/version.";
      };

      allowMutableVersion = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Allow mutable KaraKeep tags such as `release`.";
      };
    };

    chromeImage = lib.mkOption {
      type = lib.types.str;
      default = "gcr.io/zenika-hub/alpine-chrome:124";
      description = "Headless Chrome image used by KaraKeep.";
    };

    meilisearchImage = lib.mkOption {
      type = lib.types.str;
      default = "getmeili/meilisearch:v1.13.3";
      description = "Meilisearch image used by KaraKeep.";
    };

    nextAuthSecretFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to a single-line file containing NEXTAUTH_SECRET.";
    };

    meiliMasterKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to a single-line file containing MEILI_MASTER_KEY.";
    };

    tls = lib.mkEnableOption "TLS on the KaraKeep Traefik router";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.karakeepCompose.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.karakeepCompose.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.karakeepCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.version != null;
        message = "services.karakeepCompose.image.version must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableVersion || cfg.image.version != "release";
        message = "services.karakeepCompose.image.version must be pinned (not `release`) unless services.karakeepCompose.image.allowMutableVersion = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.karakeepCompose.dataDir must be an absolute path.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.meilisearchDataDir;
        message = "services.karakeepCompose.meilisearchDataDir must be an absolute path.";
      }
      {
        assertion = cfg.nextAuthSecretFile != null;
        message = "services.karakeepCompose.nextAuthSecretFile must be set.";
      }
      {
        assertion = cfg.meiliMasterKeyFile != null;
        message = "services.karakeepCompose.meiliMasterKeyFile must be set.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "KaraKeep (Docker Compose)";
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
          "KARAKEEP_CONTAINER_NAME=${cfg.containerName}"
          "KARAKEEP_IMAGE_REPOSITORY=${cfg.image.repository}"
          "KARAKEEP_VERSION=${cfg.image.version}"
          "KARAKEEP_CHROME_IMAGE=${cfg.chromeImage}"
          "KARAKEEP_MEILISEARCH_IMAGE=${cfg.meilisearchImage}"
          "KARAKEEP_NETWORK=${cfg.network}"
          "KARAKEEP_HOSTNAME=${cfg.hostname}"
          "KARAKEEP_ENTRYPOINTS=${if cfg.tls then "websecure" else "web"}"
          "KARAKEEP_TLS=${if cfg.tls then "true" else "false"}"
          "KARAKEEP_DATA_DIR=${cfg.dataDir}"
          "KARAKEEP_MEILISEARCH_DATA_DIR=${cfg.meilisearchDataDir}"
          "KARAKEEP_ENV_FILE=/run/secrets/${serviceName}.env"
          "NEXTAUTH_URL=https://${cfg.hostname}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${lib.escapeShellArg cfg.dataDir} ${lib.escapeShellArg cfg.meilisearchDataDir}'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'test -s ${toString cfg.nextAuthSecretFile} && test -s ${toString cfg.meiliMasterKeyFile}'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"karakeep: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c 'install -d -m 0700 /run/secrets && umask 0077 && NEXTAUTH_SECRET=$(tr -d \"\\r\\n\" < ${toString cfg.nextAuthSecretFile}) && MEILI_MASTER_KEY=$(tr -d \"\\r\\n\" < ${toString cfg.meiliMasterKeyFile}) && test -n \"$NEXTAUTH_SECRET\" && test -n \"$MEILI_MASTER_KEY\" && cat > /run/secrets/${serviceName}.env <<EOF\nNEXTAUTH_SECRET=\"$NEXTAUTH_SECRET\"\nMEILI_MASTER_KEY=\"$MEILI_MASTER_KEY\"\nNEXTAUTH_URL=\"$NEXTAUTH_URL\"\nKARAKEEP_VERSION=\"$KARAKEEP_VERSION\"\nEOF\nchmod 0600 /run/secrets/${serviceName}.env'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
