{
  lib,
  pkgs,
  cfg,
  composeDir,
  emailEnabled,
  telegramEnabled,
}: let
  renderConfigScript = pkgs.writeShellScript "alertmanager-render-config" ''
    set -euo pipefail
    umask 0077

    install -d -m 0755 /run/alertmanager
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
        smtp_require_tls: ${
        if cfg.notifications.email.requireTls
        then "true"
        else "false"
      }
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
  inherit renderConfigScript alertmanagerConfigTemplate;
}
