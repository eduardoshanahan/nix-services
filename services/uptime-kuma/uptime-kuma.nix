{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.uptimeKuma;
  runtimeSecretEnv = import ../../lib/runtime-secret-env.nix {inherit lib pkgs;};
  serviceName = "uptime-kuma-compose";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";

  scripts = import ./scripts.nix {
    inherit pkgs cfg dockerBin;
  };

  inherit (scripts) waitForHealthy;
in {
  imports = [
    ./options.nix
  ];
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.uptimeKuma.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.uptimeKuma.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.uptimeKuma.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.uptimeKuma.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.uptimeKuma.image.tag must be pinned (not `latest`) unless services.uptimeKuma.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.uptimeKuma.dataDir must be an absolute path.";
      }
      {
        assertion = cfg.database.type != "mariadb" || cfg.database.mariadb.passwordFile != null;
        message = "services.uptimeKuma.database.mariadb.passwordFile must be set when database.type = \"mariadb\".";
      }
      {
        assertion = cfg.database.type != "mariadb" || builtins.match "^[^[:space:]]+$" cfg.database.mariadb.host != null;
        message = "services.uptimeKuma.database.mariadb.host must not contain whitespace.";
      }
      {
        assertion = cfg.database.type != "mariadb" || builtins.match "^[^[:space:]]+$" cfg.database.mariadb.name != null;
        message = "services.uptimeKuma.database.mariadb.name must not contain whitespace.";
      }
      {
        assertion = cfg.database.type != "mariadb" || builtins.match "^[^[:space:]]+$" cfg.database.mariadb.user != null;
        message = "services.uptimeKuma.database.mariadb.user must not contain whitespace.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "Uptime Kuma (Docker Compose)";

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
        TimeoutStartSec = 600;
        Restart = "on-failure";
        RestartSec = 10;
        WorkingDirectory = composeDir;

        Environment = [
          "UPTIME_KUMA_CONTAINER_NAME=${cfg.containerName}"
          "UPTIME_KUMA_IMAGE_REPOSITORY=${cfg.image.repository}"
          "UPTIME_KUMA_IMAGE_TAG=${cfg.image.tag}"
          "UPTIME_KUMA_NETWORK=${cfg.network}"
          "UPTIME_KUMA_HOSTNAME=${cfg.hostname}"
          "UPTIME_KUMA_ENTRYPOINTS=${
            if cfg.tls
            then "websecure"
            else "web"
          }"
          "UPTIME_KUMA_TLS=${
            if cfg.tls
            then "true"
            else "false"
          }"
          "UPTIME_KUMA_DATA_DIR=${cfg.dataDir}"
          "UPTIME_KUMA_DB_ENV_FILE=/run/secrets/${serviceName}.env"
          "UPTIME_KUMA_DB_TYPE=${cfg.database.type}"
          "UPTIME_KUMA_DB_HOSTNAME=${cfg.database.mariadb.host}"
          "UPTIME_KUMA_DB_PORT=${toString cfg.database.mariadb.port}"
          "UPTIME_KUMA_DB_NAME=${cfg.database.mariadb.name}"
          "UPTIME_KUMA_DB_USERNAME=${cfg.database.mariadb.user}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre =
          [
            "${pkgs.runtimeShell} -c 'mkdir -p ${cfg.dataDir} && chown 1000:1000 ${cfg.dataDir} && chmod 0750 ${cfg.dataDir}'"
            "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          ]
          ++ lib.optionals (cfg.database.type == "sqlite") [
            "${pkgs.runtimeShell} -c 'install -d -m 0700 /run/secrets; : > /run/secrets/${serviceName}.env; chmod 0600 /run/secrets/${serviceName}.env'"
          ]
          ++ lib.optionals (cfg.database.type == "mariadb") [
            (runtimeSecretEnv.mkRuntimeSecretEnvExecStartPre {
              name = serviceName;
              secretFile = cfg.database.mariadb.passwordFile;
              envVar = "UPTIME_KUMA_DB_PASSWORD";
            })
          ]
          ++ [
            "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"uptime-kuma: docker daemon is not ready\" >&2; exit 1'"
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
