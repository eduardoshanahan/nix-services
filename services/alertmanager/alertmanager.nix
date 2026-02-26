{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.alertmanager;
  serviceName = "alertmanager";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
  emailEnabled = cfg.notifications.email.enable;
  telegramEnabled = cfg.notifications.telegram.enable;

  render = import ./render.nix {
    inherit
      lib
      pkgs
      cfg
      composeDir
      emailEnabled
      telegramEnabled
      ;
  };

  inherit (render) renderConfigScript alertmanagerConfigTemplate;
in {
  imports = [
    ./options.nix
  ];
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.alertmanager.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.alertmanager.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.alertmanager.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.alertmanager.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.alertmanager.image.tag must be pinned (not `latest`) unless services.alertmanager.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.alertmanager.dataDir must be an absolute path.";
      }
      {
        assertion = !emailEnabled || cfg.notifications.email.from != "";
        message = "services.alertmanager.notifications.email.from must be set when email notifications are enabled.";
      }
      {
        assertion = !emailEnabled || cfg.notifications.email.to != "";
        message = "services.alertmanager.notifications.email.to must be set when email notifications are enabled.";
      }
      {
        assertion = !emailEnabled || cfg.notifications.email.authUsername != "";
        message = "services.alertmanager.notifications.email.authUsername must be set when email notifications are enabled.";
      }
      {
        assertion = !emailEnabled || cfg.notifications.email.authPasswordFile != null;
        message = "services.alertmanager.notifications.email.authPasswordFile must be set when email notifications are enabled.";
      }
      {
        assertion = !telegramEnabled || cfg.notifications.telegram.botTokenFile != null;
        message = "services.alertmanager.notifications.telegram.botTokenFile must be set when Telegram notifications are enabled.";
      }
      {
        assertion = !telegramEnabled || cfg.notifications.telegram.chatId != 0;
        message = "services.alertmanager.notifications.telegram.chatId must be set when Telegram notifications are enabled.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    environment.etc."${serviceName}/alertmanager.yml.tmpl".text = alertmanagerConfigTemplate;

    systemd.services.${serviceName} = {
      description = "Alertmanager (Docker Compose)";

      wantedBy = ["multi-user.target"];
      requires = ["docker.service"];
      after = ["docker.service" "network-online.target"];
      wants = ["network-online.target"];
      restartTriggers = [
        config.environment.etc."${serviceName}/docker-compose.yml".source
        config.environment.etc."${serviceName}/alertmanager.yml.tmpl".source
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
          "ALERTMANAGER_CONTAINER_NAME=${cfg.containerName}"
          "ALERTMANAGER_IMAGE_REPOSITORY=${cfg.image.repository}"
          "ALERTMANAGER_IMAGE_TAG=${cfg.image.tag}"
          "ALERTMANAGER_NETWORK=${cfg.network}"
          "ALERTMANAGER_HOSTNAME=${cfg.hostname}"
          "ALERTMANAGER_ENTRYPOINTS=${
            if cfg.tls
            then "websecure"
            else "web"
          }"
          "ALERTMANAGER_TLS=${
            if cfg.tls
            then "true"
            else "false"
          }"
          "ALERTMANAGER_DATA_DIR=${cfg.dataDir}"
          "ALERTMANAGER_CONFIG_FILE=/run/alertmanager/alertmanager.yml"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          renderConfigScript
          "${pkgs.runtimeShell} -c 'mkdir -p ${cfg.dataDir} && chown 65534:65534 ${cfg.dataDir} && chmod 0750 ${cfg.dataDir}'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'test -s /run/alertmanager/alertmanager.yml'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"alertmanager: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
