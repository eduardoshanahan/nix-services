{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.seerr;
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};
  serviceName = "seerr";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
  jqBin = "${pkgs.jq}/bin/jq";
  awkBin = "${pkgs.gawk}/bin/awk";

  seerrArrIntegrationSubmodule = {
    options = {
      enable = lib.mkEnableOption "Seerr backend reconciliation";

      hostname = lib.mkOption {
        type = lib.types.str;
        description = "Backend hostname or FQDN to apply in Seerr.";
        example = "radarr.internal.example";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 443;
        description = "Backend port to apply in Seerr.";
      };

      useSsl = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether Seerr should use HTTPS for this backend.";
      };

      baseUrl = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Optional backend base path.";
      };

      externalUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional external URL to apply when the Seerr record has that field.";
        example = "https://radarr.internal.example";
      };

      configXmlPath = lib.mkOption {
        type = lib.types.str;
        description = "Absolute path to the backend config.xml used to read its API key.";
        example = "/srv/radarr/config.xml";
      };
    };
  };

  seerrJellyfinIntegrationSubmodule = {
    options = {
      enable = lib.mkEnableOption "Seerr Jellyfin reconciliation";

      hostname = lib.mkOption {
        type = lib.types.str;
        description = "Jellyfin hostname or FQDN to apply in Seerr.";
        example = "media.internal.example";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 443;
        description = "Jellyfin port to apply in Seerr.";
      };

      useSsl = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether Seerr should use HTTPS for Jellyfin.";
      };

      urlBase = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Optional Jellyfin base path.";
      };

      externalHostname = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional external Jellyfin hostname to apply when Seerr stores one.";
        example = "media.internal.example";
      };

      forgotPasswordUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional Jellyfin forgot-password URL to apply when Seerr stores one.";
        example = "https://media.internal.example/web/#/forgotpassword";
      };
    };
  };

  runtimeEnvScript = pkgs.writeShellScript "${serviceName}-runtime-env" ''
    set -euo pipefail
    umask 0077

    db_secret_file=${lib.escapeShellArg (toString cfg.database.postgres.passwordFile)}

    install -d -m 0700 /run/secrets

    env_file="/run/secrets/${serviceName}.env"
    tmp="$(mktemp -p /run/secrets ".${serviceName}.env.XXXXXX")"

    if [[ ! -s "$db_secret_file" ]]; then
      echo "seerr: missing or empty database password file: $db_secret_file" >&2
      exit 1
    fi

    db_password="$(tr -d '\r\n' < "$db_secret_file")"
    if [[ -z "$db_password" ]]; then
      echo "seerr: database password file is empty after trimming: $db_secret_file" >&2
      exit 1
    fi

    db_password="''${db_password//\\/\\\\}"
    db_password="''${db_password//\"/\\\"}"

    printf 'DB_PASS="%s"\n' "$db_password" > "$tmp"

    chmod 0600 "$tmp"
    mv -f "$tmp" "$env_file"
  '';

  reconcileScript = pkgs.writeShellScript "${serviceName}-reconcile-integrations" ''
    set -euo pipefail

    settings_path=${lib.escapeShellArg "${cfg.dataDir}/settings.json"}
    radarr_json=${lib.escapeShellArg (builtins.toJSON cfg.integrations.radarr)}
    sonarr_json=${lib.escapeShellArg (builtins.toJSON cfg.integrations.sonarr)}
    jellyfin_json=${lib.escapeShellArg (builtins.toJSON cfg.integrations.jellyfin)}

    log() {
      printf 'seerr: %s\n' "$*" >&2
    }

    get_backend_api_key() {
      local config_xml_path="$1"
      ${awkBin} -F'[<>]' '/ApiKey/{print $3; exit}' "$config_xml_path" 2>/dev/null || true
    }

    update_array() {
      local key="$1"
      local config_json="$2"
      local enabled hostname port use_ssl base_url external_url config_xml_path api_key
      local tmp

      enabled="$(${jqBin} -r '.enable' <<<"$config_json")"
      if [[ "$enabled" != "true" ]]; then
        return 0
      fi

      hostname="$(${jqBin} -r '.hostname' <<<"$config_json")"
      port="$(${jqBin} -r '.port' <<<"$config_json")"
      use_ssl="$(${jqBin} -r '.useSsl' <<<"$config_json")"
      base_url="$(${jqBin} -r '.baseUrl' <<<"$config_json")"
      external_url="$(${jqBin} -r '.externalUrl // empty' <<<"$config_json")"
      config_xml_path="$(${jqBin} -r '.configXmlPath' <<<"$config_json")"
      api_key="$(get_backend_api_key "$config_xml_path")"

      if [[ -z "$api_key" ]]; then
        log "could not read backend API key from $config_xml_path for $key"
        return 0
      fi

      if [[ "$(${jqBin} -r --arg key "$key" '(.[$key] | type) // "null"' "$settings_path")" != "array" ]]; then
        log "settings.json key $key is not an array; skipping"
        return 0
      fi

      if [[ "$(${jqBin} -r --arg key "$key" '.[$key] | length' "$settings_path")" == "0" ]]; then
        log "settings.json key $key has no existing entries; skipping"
        return 0
      fi

      tmp="$(mktemp -p "$(dirname "$settings_path")" ".settings.json.XXXXXX")"

      ${jqBin} \
        --arg key "$key" \
        --arg hostname "$hostname" \
        --argjson port "$port" \
        --argjson useSsl "$use_ssl" \
        --arg baseUrl "$base_url" \
        --arg apiKey "$api_key" \
        --arg externalUrl "$external_url" '
          .[$key] |= map(
            .hostname = $hostname
            | .port = $port
            | .useSsl = $useSsl
            | .baseUrl = $baseUrl
            | .apiKey = $apiKey
            | if has("externalUrl") and ($externalUrl != "") then .externalUrl = $externalUrl else . end
          )' \
        "$settings_path" > "$tmp"

      chown 1000:1000 "$tmp"
      chmod 0640 "$tmp"
      mv -f "$tmp" "$settings_path"
      log "updated $key entries in $settings_path"
    }

    if [[ ! -s "$settings_path" ]]; then
      log "settings file is missing or empty: $settings_path"
      exit 1
    fi

    if [[ "$(${jqBin} -r '(.public.initialized // false)' "$settings_path")" != "true" ]]; then
      log "settings.json is not initialized yet; skipping reconciliation"
      exit 0
    fi

    update_array "radarr" "$radarr_json"
    update_array "sonarr" "$sonarr_json"

    if [[ "$(${jqBin} -r '.enable' <<<"$jellyfin_json")" == "true" ]]; then
      hostname="$(${jqBin} -r '.hostname' <<<"$jellyfin_json")"
      port="$(${jqBin} -r '.port' <<<"$jellyfin_json")"
      use_ssl="$(${jqBin} -r '.useSsl' <<<"$jellyfin_json")"
      url_base="$(${jqBin} -r '.urlBase' <<<"$jellyfin_json")"
      external_hostname="$(${jqBin} -r '.externalHostname // empty' <<<"$jellyfin_json")"
      forgot_password_url="$(${jqBin} -r '.forgotPasswordUrl // empty' <<<"$jellyfin_json")"

      if [[ "$(${jqBin} -r '(.jellyfin | type) // "null"' "$settings_path")" != "object" ]]; then
        log "settings.json key jellyfin is not an object; skipping"
      else
        tmp="$(mktemp -p "$(dirname "$settings_path")" ".settings.json.XXXXXX")"

        ${jqBin} \
          --arg hostname "$hostname" \
          --argjson port "$port" \
          --argjson useSsl "$use_ssl" \
          --arg urlBase "$url_base" \
          --arg externalHostname "$external_hostname" \
          --arg forgotPasswordUrl "$forgot_password_url" '
            .jellyfin |= (
              .ip = $hostname
              | .port = $port
              | .useSsl = $useSsl
              | .urlBase = $urlBase
              | if has("externalHostname") and ($externalHostname != "") then .externalHostname = $externalHostname else . end
              | if has("jellyfinForgotPasswordUrl") and ($forgotPasswordUrl != "") then .jellyfinForgotPasswordUrl = $forgotPasswordUrl else . end
            )' \
          "$settings_path" > "$tmp"

        chown 1000:1000 "$tmp"
        chmod 0640 "$tmp"
        mv -f "$tmp" "$settings_path"
        log "updated jellyfin settings in $settings_path"
      fi
    fi
  '';

  hasDeclarativeIntegrations =
    cfg.integrations.radarr.enable
    || cfg.integrations.sonarr.enable
    || cfg.integrations.jellyfin.enable;
in {
  options.services.seerr = {
    enable = lib.mkEnableOption "Seerr service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "seerr";
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
      default = "/var/lib/seerr";
      description = "Persistent host path used for Seerr state.";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "ghcr.io/seerr-team/seerr";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "v3.1.0";
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

    database.postgres = {
      host = lib.mkOption {
        type = lib.types.str;
        default = "postgres.internal.example";
        description = "PostgreSQL host for Seerr.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 5433;
        description = "PostgreSQL port for Seerr.";
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "seerr";
        description = "PostgreSQL database name for Seerr.";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "seerr";
        description = "PostgreSQL username for Seerr.";
      };

      passwordFile = runtimeSecrets.mkSecretFileOption {
        description = "Absolute path to a runtime-provisioned file containing the PostgreSQL password for Seerr.";
        example = "/run/secrets/seerr-db-password";
      };
    };

    tls = lib.mkEnableOption "TLS on the Seerr Traefik router";

    integrations = {
      radarr = lib.mkOption {
        type = lib.types.submodule seerrArrIntegrationSubmodule;
        default = {};
        description = "Declarative Seerr Radarr backend settings to reconcile after startup.";
      };

      sonarr = lib.mkOption {
        type = lib.types.submodule seerrArrIntegrationSubmodule;
        default = {};
        description = "Declarative Seerr Sonarr backend settings to reconcile after startup.";
      };

      jellyfin = lib.mkOption {
        type = lib.types.submodule seerrJellyfinIntegrationSubmodule;
        default = {};
        description = "Declarative Seerr Jellyfin media-server settings to reconcile after startup.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.seerr.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.seerr.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.seerr.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.seerr.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.seerr.image.tag must be pinned (not `latest`) unless services.seerr.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.seerr.dataDir must be an absolute path.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.database.postgres.host != null;
        message = "services.seerr.database.postgres.host must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.database.postgres.name != null;
        message = "services.seerr.database.postgres.name must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.database.postgres.user != null;
        message = "services.seerr.database.postgres.user must not contain whitespace.";
      }
      {
        assertion = cfg.database.postgres.passwordFile != null;
        message = "services.seerr.database.postgres.passwordFile must be set.";
      }
      {
        assertion = (!cfg.integrations.radarr.enable) || (builtins.match "^[^[:space:]]+$" cfg.integrations.radarr.hostname != null);
        message = "services.seerr.integrations.radarr.hostname must not contain whitespace when enabled.";
      }
      {
        assertion = (!cfg.integrations.sonarr.enable) || (builtins.match "^[^[:space:]]+$" cfg.integrations.sonarr.hostname != null);
        message = "services.seerr.integrations.sonarr.hostname must not contain whitespace when enabled.";
      }
      {
        assertion = (!cfg.integrations.radarr.enable) || lib.hasPrefix "/" cfg.integrations.radarr.configXmlPath;
        message = "services.seerr.integrations.radarr.configXmlPath must be an absolute path when enabled.";
      }
      {
        assertion = (!cfg.integrations.sonarr.enable) || lib.hasPrefix "/" cfg.integrations.sonarr.configXmlPath;
        message = "services.seerr.integrations.sonarr.configXmlPath must be an absolute path when enabled.";
      }
      {
        assertion = (!cfg.integrations.jellyfin.enable) || (builtins.match "^[^[:space:]]+$" cfg.integrations.jellyfin.hostname != null);
        message = "services.seerr.integrations.jellyfin.hostname must not contain whitespace when enabled.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "Seerr (Docker Compose)";
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
        TimeoutStartSec = 900;
        Restart = "on-failure";
        RestartSec = 10;

        Environment = [
          "SEERR_CONTAINER_NAME=${cfg.containerName}"
          "SEERR_IMAGE_REPOSITORY=${cfg.image.repository}"
          "SEERR_IMAGE_TAG=${cfg.image.tag}"
          "SEERR_NETWORK=${cfg.network}"
          "SEERR_HOST=${cfg.hostname}"
          "SEERR_ENTRYPOINTS=${if cfg.tls then "websecure" else "web"}"
          "SEERR_TLS=${if cfg.tls then "true" else "false"}"
          "SEERR_DATA_DIR=${cfg.dataDir}"
          "SEERR_RUNTIME_ENV_FILE=/run/secrets/${serviceName}.env"
          "SEERR_DB_HOST=${cfg.database.postgres.host}"
          "SEERR_DB_PORT=${toString cfg.database.postgres.port}"
          "SEERR_DB_NAME=${cfg.database.postgres.name}"
          "SEERR_DB_USER=${cfg.database.postgres.user}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${lib.escapeShellArg cfg.dataDir} && chown 1000:1000 ${lib.escapeShellArg cfg.dataDir} && chmod 0750 ${lib.escapeShellArg cfg.dataDir}'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'test -s /etc/ssl/certs/homelab-root-ca.crt'"
          runtimeEnvScript
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 60); do if exec 3<>/dev/tcp/${cfg.database.postgres.host}/${toString cfg.database.postgres.port}; then exec 3>&-; exec 3<&-; exit 0; fi; sleep 2; done; echo \"seerr: postgres is not ready at ${cfg.database.postgres.host}:${toString cfg.database.postgres.port}\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"seerr: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };

    systemd.services."${serviceName}-reconcile" = lib.mkIf hasDeclarativeIntegrations {
      description = "Reconcile declarative ${serviceName} integrations";
      wantedBy = ["${serviceName}.service"];
      requires = ["${serviceName}.service"];
      after = ["${serviceName}.service" "network-online.target"];
      wants = ["network-online.target"];
      partOf = ["${serviceName}.service"];

      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = 300;
        Restart = "on-failure";
        RestartSec = 30;
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 45";
        ExecStart = reconcileScript;
      };
    };
  };
}
