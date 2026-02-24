{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.alertmanager;
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};
  serviceName = "alertmanager";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
  emailEnabled = cfg.notifications.email.enable;
  telegramEnabled = cfg.notifications.telegram.enable;

  renderConfigScript = pkgs.writeShellScript "alertmanager-render-config" ''
    set -euo pipefail
    umask 0077

    mkdir -p /run/alertmanager
    cp ${composeDir}/alertmanager.yml.tmpl /run/alertmanager/alertmanager.yml

    escape_sed() {
      printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
    }

    ${lib.optionalString emailEnabled ''
      if [[ ! -s "${toString cfg.notifications.email.authPasswordFile}" ]]; then
        echo "alertmanager: missing email auth password file: ${toString cfg.notifications.email.authPasswordFile}" >&2
        exit 1
      fi
      smtp_password="$(tr -d '\r\n' < ${toString cfg.notifications.email.authPasswordFile})"
      sed -i "s/__SMTP_AUTH_PASSWORD__/$(escape_sed "$smtp_password")/g" /run/alertmanager/alertmanager.yml
    ''}

    ${lib.optionalString telegramEnabled ''
      if [[ ! -s "${toString cfg.notifications.telegram.botTokenFile}" ]]; then
        echo "alertmanager: missing telegram bot token file: ${toString cfg.notifications.telegram.botTokenFile}" >&2
        exit 1
      fi
      telegram_token="$(tr -d '\r\n' < ${toString cfg.notifications.telegram.botTokenFile})"
      sed -i "s/__TELEGRAM_BOT_TOKEN__/$(escape_sed "$telegram_token")/g" /run/alertmanager/alertmanager.yml
    ''}

    chmod 0644 /run/alertmanager/alertmanager.yml
  '';

  alertmanagerConfigTemplate = ''
    global:
${lib.optionalString emailEnabled ''
      smtp_smarthost: "${cfg.notifications.email.smarthost}"
      smtp_from: "${cfg.notifications.email.from}"
      smtp_auth_username: "${cfg.notifications.email.authUsername}"
      smtp_auth_password: "__SMTP_AUTH_PASSWORD__"
      smtp_require_tls: ${if cfg.notifications.email.requireTls then "true" else "false"}
''}

    route:
      receiver: "default"
      group_by: ["alertname", "job", "instance"]
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 1h

    receivers:
      - name: "default"
${lib.optionalString emailEnabled ''
        email_configs:
          - to: "${cfg.notifications.email.to}"
            send_resolved: true
''}
${lib.optionalString telegramEnabled ''
        telegram_configs:
          - bot_token: "__TELEGRAM_BOT_TOKEN__"
            chat_id: ${toString cfg.notifications.telegram.chatId}
            parse_mode: "${cfg.notifications.telegram.parseMode}"
            send_resolved: true
''}
  '';
in {
  options.services.alertmanager = {
    enable = lib.mkEnableOption "Alertmanager service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "alertmanager";
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
      default = "/var/lib/alertmanager";
      description = "Persistent host path used for Alertmanager data.";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "prom/alertmanager";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "v0.27.0";
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

    tls = lib.mkEnableOption "TLS on the Alertmanager Traefik router";

    notifications = {
      email = {
        enable = lib.mkEnableOption "email notifications from Alertmanager";

        smarthost = lib.mkOption {
          type = lib.types.str;
          default = "smtp.gmail.com:587";
          description = "SMTP smarthost (`host:port`).";
        };

        from = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Sender email address.";
        };

        to = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Destination email address.";
        };

        authUsername = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "SMTP auth username.";
        };

        authPasswordFile = runtimeSecrets.mkSecretFileOption {
          description = "Absolute path to SMTP auth password file.";
          example = "/run/secrets/alertmanager-smtp-password";
        };

        requireTls = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Require TLS for SMTP delivery.";
        };
      };

      telegram = {
        enable = lib.mkEnableOption "Telegram notifications from Alertmanager";

        botTokenFile = runtimeSecrets.mkSecretFileOption {
          description = "Absolute path to Telegram bot token file.";
          example = "/run/secrets/alertmanager-telegram-bot-token";
        };

        chatId = lib.mkOption {
          type = lib.types.int;
          default = 0;
          description = "Telegram chat ID used for notifications.";
        };

        parseMode = lib.mkOption {
          type = lib.types.enum [ "MarkdownV2" "Markdown" "HTML" "" ];
          default = "HTML";
          description = "Telegram parse mode.";
        };
      };
    };
  };

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
          "ALERTMANAGER_ENTRYPOINTS=${if cfg.tls then "websecure" else "web"}"
          "ALERTMANAGER_TLS=${if cfg.tls then "true" else "false"}"
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
