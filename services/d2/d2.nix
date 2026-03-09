{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.d2Compose;
  serviceName = "d2";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  defaultFileName =
    if lib.hasSuffix ".d2" cfg.defaultFile
    then cfg.defaultFile
    else "${cfg.defaultFile}.d2";
  defaultGeneratedPasswordFile = "${cfg.dataDir}/auth/admin-password";
  effectivePasswordFile =
    if cfg.auth.passwordFile == null
    then defaultGeneratedPasswordFile
    else cfg.auth.passwordFile;
  authEnabledFlag = if cfg.auth.enable then "1" else "0";
  authAutoGenerateFlag = if cfg.auth.passwordFile == null then "1" else "0";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
in {
  imports = [
    ./options.nix
  ];

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.d2Compose.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.d2Compose.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.d2Compose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.d2Compose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.d2Compose.image.tag must be pinned (not `latest`) unless services.d2Compose.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.d2Compose.dataDir must be an absolute path.";
      }
      {
        assertion = (!cfg.auth.enable) || builtins.match "^[^[:space:]]+$" cfg.auth.username != null;
        message = "services.d2Compose.auth.username must not contain whitespace when auth is enabled.";
      }
      {
        assertion = (!cfg.auth.enable) || lib.hasPrefix "/" effectivePasswordFile;
        message = "services.d2Compose.auth.passwordFile must be absolute when auth is enabled.";
      }
      {
        assertion = builtins.match "^[A-Za-z0-9._-]+(\\.d2)?$" cfg.defaultFile != null;
        message = "services.d2Compose.defaultFile may only contain letters, numbers, `.`, `_`, and `-` (optionally ending in .d2).";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;
    environment.etc."${serviceName}/Dockerfile".source = ./Dockerfile;
    environment.etc."${serviceName}/app/main.go".source = ./app/main.go;
    environment.etc."${serviceName}/app/go.mod".source = ./app/go.mod;
    environment.etc."${serviceName}/app/go.sum".source = ./app/go.sum;

    systemd.services.${serviceName} = {
      description = "D2 editor and renderer (Docker Compose)";
      wantedBy = ["multi-user.target"];
      requires = ["docker.service"];
      after = ["docker.service" "network-online.target"];
      wants = ["network-online.target"];
      restartTriggers = [
        config.environment.etc."${serviceName}/docker-compose.yml".source
        config.environment.etc."${serviceName}/Dockerfile".source
        config.environment.etc."${serviceName}/app/main.go".source
        config.environment.etc."${serviceName}/app/go.mod".source
        config.environment.etc."${serviceName}/app/go.sum".source
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = composeDir;
        TimeoutStartSec = 300;
        Restart = "on-failure";
        RestartSec = 10;

        Environment = [
          "D2_CONTAINER_NAME=${cfg.containerName}"
          "D2_IMAGE_REPOSITORY=${cfg.image.repository}"
          "D2_IMAGE_TAG=${cfg.image.tag}"
          "D2_NETWORK=${cfg.network}"
          "D2_HOSTNAME=${cfg.hostname}"
          "D2_ENTRYPOINTS=${if cfg.tls then "websecure" else "web"}"
          "D2_TLS=${if cfg.tls then "true" else "false"}"
          "D2_DATA_DIR=${cfg.dataDir}"
          "D2_DEFAULT_FILE=${defaultFileName}"
          "D2_AUTH_ENABLED=${if cfg.auth.enable then "true" else "false"}"
          "D2_AUTH_USERNAME=${cfg.auth.username}"
          "D2_AUTH_PASSWORD_FILE=${effectivePasswordFile}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${lib.escapeShellArg cfg.dataDir}/projects ${lib.escapeShellArg cfg.dataDir}/auth'"
          "${pkgs.runtimeShell} -c 'if [ ! -s ${lib.escapeShellArg ("${cfg.dataDir}/projects/${defaultFileName}")} ]; then printf \"%s\\n\" \"direction: right\" \"\" \"app: D2 service\" \"app -> users: served via Traefik\" > ${lib.escapeShellArg ("${cfg.dataDir}/projects/${defaultFileName}")}; fi'"
          "${pkgs.runtimeShell} -c 'if [ \"${authEnabledFlag}\" = \"1\" ] && [ \"${authAutoGenerateFlag}\" = \"1\" ] && [ ! -s ${lib.escapeShellArg defaultGeneratedPasswordFile} ]; then umask 077; ${pkgs.openssl}/bin/openssl rand -base64 24 > ${lib.escapeShellArg defaultGeneratedPasswordFile}; fi'"
          "${pkgs.runtimeShell} -c 'if [ \"${authEnabledFlag}\" = \"1\" ]; then test -s ${lib.escapeShellArg effectivePasswordFile}; fi'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/Dockerfile'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/app/main.go'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/app/go.mod'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"d2: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${dockerBin} compose up -d --build";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
