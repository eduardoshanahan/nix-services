{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.vikunjaCompose;
  runtimeSecretEnv = import ../../lib/runtime-secret-env.nix {inherit lib pkgs;};
  serviceName = "vikunja";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  yamlFormat = pkgs.formats.yaml {};
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
  publicUrl = "${
    if cfg.tls
    then "https"
    else "http"
  }://${cfg.hostname}/";
  configYaml = {
    auth =
      {
        local.enabled = cfg.auth.local.enable;
      }
      // lib.optionalAttrs cfg.auth.openid.enable {
        openid = {
          enabled = true;
          providers = {
            "${cfg.auth.openid.providerKey}" = {
              name = cfg.auth.openid.name;
              authurl = cfg.auth.openid.authUrl;
              scope = cfg.auth.openid.scopes;
              usernamefallback = cfg.auth.openid.usernameFallback;
              emailfallback = cfg.auth.openid.emailFallback;
              clientid.file = "/run/secrets/vikunja-oidc-client-id";
              clientsecret.file = "/run/secrets/vikunja-oidc-client-secret";
            };
          };
        };
      };
  };
in {
  imports = [
    ./options.nix
  ];

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.vikunjaCompose.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.vikunjaCompose.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.vikunjaCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.vikunjaCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.vikunjaCompose.image.tag must be pinned (not `latest`) unless services.vikunjaCompose.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.vikunjaCompose.dataDir must be an absolute path.";
      }
      {
        assertion = cfg.database.type != "sqlite" || lib.hasPrefix "/" cfg.database.sqlite.path;
        message = "services.vikunjaCompose.database.sqlite.path must be an absolute path.";
      }
      {
        assertion = cfg.database.type != "postgres" || cfg.database.postgres.passwordFile != null;
        message = "services.vikunjaCompose.database.postgres.passwordFile must be set when database.type = \"postgres\".";
      }
      {
        assertion = cfg.database.type != "postgres" || builtins.match "^[^[:space:]]+$" cfg.database.postgres.host != null;
        message = "services.vikunjaCompose.database.postgres.host must not contain whitespace.";
      }
      {
        assertion = cfg.database.type != "postgres" || builtins.match "^[^[:space:]]+$" cfg.database.postgres.name != null;
        message = "services.vikunjaCompose.database.postgres.name must not contain whitespace.";
      }
      {
        assertion = cfg.database.type != "postgres" || builtins.match "^[^[:space:]]+$" cfg.database.postgres.user != null;
        message = "services.vikunjaCompose.database.postgres.user must not contain whitespace.";
      }
      {
        assertion = !cfg.mailer.enable || builtins.match "^[^[:space:]]+$" cfg.mailer.host != null;
        message = "services.vikunjaCompose.mailer.host must not contain whitespace when mailer is enabled.";
      }
      {
        assertion = (cfg.mailer.username == "") == (cfg.mailer.passwordFile == null);
        message = "Set both services.vikunjaCompose.mailer.username and services.vikunjaCompose.mailer.passwordFile together, or leave both unset.";
      }
      {
        assertion = !cfg.auth.openid.enable || cfg.auth.openid.clientIdFile != null;
        message = "services.vikunjaCompose.auth.openid.clientIdFile must be set when OpenID auth is enabled.";
      }
      {
        assertion = !cfg.auth.openid.enable || cfg.auth.openid.clientSecretFile != null;
        message = "services.vikunjaCompose.auth.openid.clientSecretFile must be set when OpenID auth is enabled.";
      }
      {
        assertion = !cfg.auth.openid.enable || builtins.match "^[^[:space:]]+$" cfg.auth.openid.providerKey != null;
        message = "services.vikunjaCompose.auth.openid.providerKey must not contain whitespace.";
      }
      {
        assertion = !cfg.auth.openid.enable || builtins.match "^[^[:space:]]+$" cfg.auth.openid.authUrl != null;
        message = "services.vikunjaCompose.auth.openid.authUrl must not contain whitespace.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;
    environment.etc."${serviceName}/config.yml".source = yamlFormat.generate "${serviceName}-config.yml" configYaml;

    systemd.services.${serviceName} = {
      description = "Vikunja (Docker Compose)";

      wantedBy = ["multi-user.target"];
      requires = ["docker.service"];
      after = ["docker.service" "network-online.target"];
      wants = ["network-online.target"];
      restartTriggers = [
        config.environment.etc."${serviceName}/docker-compose.yml".source
        config.environment.etc."${serviceName}/config.yml".source
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

        Environment = [
          "VIKUNJA_CONTAINER_NAME=${cfg.containerName}"
          "VIKUNJA_IMAGE_REPOSITORY=${cfg.image.repository}"
          "VIKUNJA_IMAGE_TAG=${cfg.image.tag}"
          "VIKUNJA_NETWORK=${cfg.network}"
          "VIKUNJA_HOSTNAME=${cfg.hostname}"
          "VIKUNJA_ENTRYPOINTS=${
            if cfg.tls
            then "websecure"
            else "web"
          }"
          "VIKUNJA_TLS=${
            if cfg.tls
            then "true"
            else "false"
          }"
          "VIKUNJA_SERVICE_PUBLICURL=${publicUrl}"
          "VIKUNJA_SERVICE_ENABLEREGISTRATION=${
            if cfg.enableRegistration
            then "true"
            else "false"
          }"
          "VIKUNJA_METRICS_ENABLED=${
            if cfg.metrics.enable
            then "true"
            else "false"
          }"
          "VIKUNJA_DATA_DIR=${cfg.dataDir}"
          "VIKUNJA_DATABASE_ENV_FILE=/run/secrets/${serviceName}.env"
          "VIKUNJA_MAILER_ENV_FILE=/run/secrets/${serviceName}-mailer.env"
          "VIKUNJA_DATABASE_TYPE=${cfg.database.type}"
          "VIKUNJA_DATABASE_PATH=${cfg.database.sqlite.path}"
          "VIKUNJA_DATABASE_HOST=${cfg.database.postgres.host}:${toString cfg.database.postgres.port}"
          "VIKUNJA_DATABASE_DATABASE=${cfg.database.postgres.name}"
          "VIKUNJA_DATABASE_USER=${cfg.database.postgres.user}"
          "VIKUNJA_DATABASE_SSLMODE=${cfg.database.postgres.sslMode}"
          "VIKUNJA_MAILER_ENABLED=${
            if cfg.mailer.enable
            then "true"
            else "false"
          }"
          "VIKUNJA_MAILER_HOST=${cfg.mailer.host}"
          "VIKUNJA_MAILER_PORT=${toString cfg.mailer.port}"
          "VIKUNJA_MAILER_AUTHTYPE=${cfg.mailer.authType}"
          "VIKUNJA_MAILER_USERNAME=${cfg.mailer.username}"
          "VIKUNJA_MAILER_SKIPTLSVERIFY=${
            if cfg.mailer.skipTlsVerify
            then "true"
            else "false"
          }"
          "VIKUNJA_MAILER_FORCESSL=${
            if cfg.mailer.forceSsl
            then "true"
            else "false"
          }"
          "VIKUNJA_MAILER_FROMEMAIL=${cfg.mailer.fromEmail}"
          "VIKUNJA_MAILER_QUEUELENGTH=${toString cfg.mailer.queueLength}"
          "VIKUNJA_MAILER_QUEUETIMEOUT=${toString cfg.mailer.queueTimeout}"
          "VIKUNJA_AUTH_OPENID_ENABLED=${
            if cfg.auth.openid.enable
            then "true"
            else "false"
          }"
          "VIKUNJA_OIDC_CLIENT_ID_FILE=${
            if !cfg.auth.openid.enable
            then "/dev/null"
            else "${cfg.dataDir}/.secrets/vikunja-oidc-client-id"
          }"
          "VIKUNJA_OIDC_CLIENT_SECRET_FILE=${
            if !cfg.auth.openid.enable
            then "/dev/null"
            else "${cfg.dataDir}/.secrets/vikunja-oidc-client-secret"
          }"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre =
          [
            "${pkgs.runtimeShell} -c 'mkdir -p ${cfg.dataDir} && chown 1000:0 ${cfg.dataDir} && chmod 0750 ${cfg.dataDir}'"
            "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
            "${pkgs.runtimeShell} -c 'test -s ${composeDir}/config.yml'"
            "${pkgs.runtimeShell} -c 'install -d -m 0700 /run/secrets'"
          ]
          ++ lib.optionals (cfg.database.type == "sqlite") [
            "${pkgs.runtimeShell} -c ': > /run/secrets/${serviceName}.env; chmod 0600 /run/secrets/${serviceName}.env'"
          ]
          ++ lib.optionals (cfg.database.type == "postgres") [
            (runtimeSecretEnv.mkRuntimeSecretEnvExecStartPre {
              name = serviceName;
              secretFile = cfg.database.postgres.passwordFile;
              envVar = "VIKUNJA_DATABASE_PASSWORD";
            })
          ]
          ++ lib.optionals (cfg.mailer.passwordFile != null) [
            (runtimeSecretEnv.mkRuntimeSecretEnvExecStartPre {
              name = "${serviceName}-mailer";
              secretFile = cfg.mailer.passwordFile;
              envVar = "VIKUNJA_MAILER_PASSWORD";
            })
          ]
          ++ lib.optionals (cfg.mailer.passwordFile == null) [
            "${pkgs.runtimeShell} -c ': > /run/secrets/${serviceName}-mailer.env; chmod 0600 /run/secrets/${serviceName}-mailer.env'"
          ]
          ++ lib.optionals cfg.auth.openid.enable [
            "${pkgs.runtimeShell} -c 'install -d -m 0700 -o 1000 -g 0 ${cfg.dataDir}/.secrets'"
            "${pkgs.runtimeShell} -c 'install -m 0400 -o 1000 -g 0 ${toString cfg.auth.openid.clientIdFile} ${cfg.dataDir}/.secrets/vikunja-oidc-client-id'"
            "${pkgs.runtimeShell} -c 'install -m 0400 -o 1000 -g 0 ${toString cfg.auth.openid.clientSecretFile} ${cfg.dataDir}/.secrets/vikunja-oidc-client-secret'"
          ]
          ++ [
            "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"vikunja: docker daemon is not ready\" >&2; exit 1'"
            "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
            "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
          ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
