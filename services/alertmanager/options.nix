{lib, ...}: let
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};
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
          type = lib.types.enum ["MarkdownV2" "Markdown" "HTML" ""];
          default = "HTML";
          description = "Telegram parse mode.";
        };
      };
    };
  };
}
