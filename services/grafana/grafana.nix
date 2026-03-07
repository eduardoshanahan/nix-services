{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.grafanaCompose;
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};
  serviceName = "grafana";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
  provisioning = import ./provisioning.nix {inherit lib cfg;};
  dashboards = import ./dashboards.nix;
  scripts = import ./scripts.nix {
    inherit lib pkgs cfg serviceName dockerBin;
  };

  inherit (provisioning) datasourcesYaml dashboardsProviderYaml;
  inherit
    (dashboards)
    starterDashboardJson
    nodesDetailDashboardJson
    containerFleetDashboardJson
    dnsEdgeDashboardJson
    nasDetailDashboardJson
    nasFileActivityDashboardJson
    giteaOverviewDashboardJson
    sharedInfraDashboardJson
    monitoringControlPlaneDashboardJson
    edgeServiceReliabilityDashboardJson
    alertingTriageDashboardJson
    logsPipelineDashboardJson
    smtpRelayOperationsDashboardJson
    serviceSliDashboardJson
    unifiOverviewDashboardJson
    ;
  inherit (scripts) backupScript healthcheckScript waitForHealthy;
  runtimeEnvScript = pkgs.writeShellScript "${serviceName}-runtime-env" ''
    set -euo pipefail
    umask 0077

    admin_secret_file=${lib.escapeShellArg (toString cfg.adminPasswordFile)}
    db_type=${lib.escapeShellArg cfg.database.type}
    db_secret_file=${lib.escapeShellArg (
      if cfg.database.postgres.passwordFile == null
      then ""
      else toString cfg.database.postgres.passwordFile
    )}
    oauth_client_id_file=${lib.escapeShellArg (
      if cfg.auth.genericOauth.clientIdFile == null
      then ""
      else toString cfg.auth.genericOauth.clientIdFile
    )}
    oauth_client_secret_file=${lib.escapeShellArg (
      if cfg.auth.genericOauth.clientSecretFile == null
      then ""
      else toString cfg.auth.genericOauth.clientSecretFile
    )}
    oauth_enabled=${if cfg.auth.genericOauth.enable then "true" else "false"}
    env_file="/run/secrets/${serviceName}.env"
    tmp="$(mktemp -p /run/secrets ".${serviceName}.env.XXXXXX")"

    install -d -m 0700 /run/secrets

    if [[ ! -s "$admin_secret_file" ]]; then
      echo "grafana: missing or empty admin password file: $admin_secret_file" >&2
      exit 1
    fi
    admin_password="$(tr -d '\r\n' < "$admin_secret_file")"
    if [[ -z "$admin_password" ]]; then
      echo "grafana: admin password file is empty after trimming" >&2
      exit 1
    fi

    escape_env() {
      local value="$1"
      value="''${value//\\/\\\\}"
      value="''${value//\"/\\\"}"
      printf '%s' "$value"
    }

    {
      printf 'GF_SECURITY_ADMIN_PASSWORD="%s"\n' "$(escape_env "$admin_password")"
      printf 'GF_DATABASE_TYPE="%s"\n' "${cfg.database.type}"
      printf 'GF_DATABASE_HOST="%s:%s"\n' "${cfg.database.postgres.host}" "${toString cfg.database.postgres.port}"
      printf 'GF_DATABASE_NAME="%s"\n' "${cfg.database.postgres.name}"
      printf 'GF_DATABASE_USER="%s"\n' "${cfg.database.postgres.user}"
      printf 'GF_DATABASE_SSL_MODE="%s"\n' "${cfg.database.postgres.sslMode}"
      printf 'GF_SERVER_ROOT_URL="%s://%s/"\n' "${if cfg.tls then "https" else "http"}" "${cfg.hostname}"
      if [[ "$db_type" == "postgres" ]]; then
        if [[ -z "$db_secret_file" || ! -s "$db_secret_file" ]]; then
          echo "grafana: missing or empty database password file: $db_secret_file" >&2
          exit 1
        fi
        db_password="$(tr -d '\r\n' < "$db_secret_file")"
        if [[ -z "$db_password" ]]; then
          echo "grafana: database password file is empty after trimming" >&2
          exit 1
        fi
        printf 'GF_DATABASE_PASSWORD="%s"\n' "$(escape_env "$db_password")"
      fi
      if [[ "$oauth_enabled" == "true" ]]; then
        if [[ -z "$oauth_client_id_file" || ! -s "$oauth_client_id_file" ]]; then
          echo "grafana: missing or empty OAuth client ID file: $oauth_client_id_file" >&2
          exit 1
        fi
        if [[ -z "$oauth_client_secret_file" || ! -s "$oauth_client_secret_file" ]]; then
          echo "grafana: missing or empty OAuth client secret file: $oauth_client_secret_file" >&2
          exit 1
        fi

        oauth_client_id="$(tr -d '\r\n' < "$oauth_client_id_file")"
        oauth_client_secret="$(tr -d '\r\n' < "$oauth_client_secret_file")"
        if [[ -z "$oauth_client_id" ]]; then
          echo "grafana: OAuth client ID is empty after trimming" >&2
          exit 1
        fi
        if [[ -z "$oauth_client_secret" ]]; then
          echo "grafana: OAuth client secret is empty after trimming" >&2
          exit 1
        fi

        printf 'GF_AUTH_GENERIC_OAUTH_ENABLED="true"\n'
        printf 'GF_AUTH_GENERIC_OAUTH_NAME="%s"\n' "${cfg.auth.genericOauth.name}"
        printf 'GF_AUTH_GENERIC_OAUTH_CLIENT_ID="%s"\n' "$(escape_env "$oauth_client_id")"
        printf 'GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET="%s"\n' "$(escape_env "$oauth_client_secret")"
        printf 'GF_AUTH_GENERIC_OAUTH_SCOPES="%s"\n' "${cfg.auth.genericOauth.scopes}"
        printf 'GF_AUTH_GENERIC_OAUTH_AUTH_URL="%s"\n' "${cfg.auth.genericOauth.authUrl}"
        printf 'GF_AUTH_GENERIC_OAUTH_TOKEN_URL="%s"\n' "${cfg.auth.genericOauth.tokenUrl}"
        printf 'GF_AUTH_GENERIC_OAUTH_API_URL="%s"\n' "${cfg.auth.genericOauth.apiUrl}"
        printf 'GF_AUTH_GENERIC_OAUTH_USE_PKCE="%s"\n' "${if cfg.auth.genericOauth.usePkce then "true" else "false"}"
        printf 'GF_AUTH_GENERIC_OAUTH_TLS_SKIP_VERIFY_INSECURE="%s"\n' "${if cfg.auth.genericOauth.tlsSkipVerifyInsecure then "true" else "false"}"
      else
        printf 'GF_AUTH_GENERIC_OAUTH_ENABLED="false"\n'
      fi
    } > "$tmp"
    chmod 0600 "$tmp"
    mv -f "$tmp" "$env_file"
  '';
in {
  options.services.grafanaCompose = {
    enable = lib.mkEnableOption "Grafana service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "grafana";
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
      default = "/var/lib/grafana";
      description = "Persistent host path used for Grafana data.";
    };

    adminPasswordFile = runtimeSecrets.mkSecretFileOption {
      description = ''
        Absolute path to a runtime-provisioned file containing the Grafana admin password.
      '';
      example = "/run/secrets/grafana-admin-password";
    };

    database = {
      type = lib.mkOption {
        type = lib.types.enum [ "sqlite" "postgres" ];
        default = "sqlite";
        description = "Grafana database backend.";
      };

      postgres = {
        host = lib.mkOption {
          type = lib.types.str;
          default = "postgres.<homelab-domain>";
          description = "PostgreSQL host for Grafana when `database.type = \"postgres\"`.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 5433;
          description = "PostgreSQL port for Grafana.";
        };

        name = lib.mkOption {
          type = lib.types.str;
          default = "grafana";
          description = "PostgreSQL database name for Grafana.";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = "grafana";
          description = "PostgreSQL username for Grafana.";
        };

        passwordFile = runtimeSecrets.mkSecretFileOption {
          description = "Absolute path to a runtime-provisioned file containing the PostgreSQL password for Grafana.";
          example = "/run/secrets/grafana-db-password";
        };

        sslMode = lib.mkOption {
          type = lib.types.enum [ "disable" "require" "verify-ca" "verify-full" ];
          default = "disable";
          description = "PostgreSQL SSL mode for Grafana.";
        };
      };
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "grafana/grafana";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "11.2.0";
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

    tls = lib.mkEnableOption "TLS on the Grafana Traefik router";

    auth = {
      genericOauth = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable Grafana Generic OAuth authentication.";
        };

        name = lib.mkOption {
          type = lib.types.str;
          default = "Authentik";
          description = "Display name shown on Grafana login button.";
        };

        clientIdFile = runtimeSecrets.mkSecretFileOption {
          description = "Absolute path to a runtime-provisioned file containing the Generic OAuth client ID.";
          example = "/run/secrets/grafana-oidc-client-id";
        };

        clientSecretFile = runtimeSecrets.mkSecretFileOption {
          description = "Absolute path to a runtime-provisioned file containing the Generic OAuth client secret.";
          example = "/run/secrets/grafana-oidc-client-secret";
        };

        scopes = lib.mkOption {
          type = lib.types.str;
          default = "openid profile email";
          description = "OAuth scopes requested by Grafana.";
        };

        authUrl = lib.mkOption {
          type = lib.types.str;
          default = "https://authentik.<homelab-domain>/application/o/authorize/";
          description = "OIDC authorization endpoint.";
        };

        tokenUrl = lib.mkOption {
          type = lib.types.str;
          default = "https://authentik.<homelab-domain>/application/o/token/";
          description = "OIDC token endpoint.";
        };

        apiUrl = lib.mkOption {
          type = lib.types.str;
          default = "https://authentik.<homelab-domain>/application/o/userinfo/";
          description = "OIDC user info endpoint.";
        };

        usePkce = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable PKCE for Generic OAuth.";
        };

        tlsSkipVerifyInsecure = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Skip TLS certificate verification for Generic OAuth endpoints.
            Keep disabled unless the IdP certificate chain is not trusted by Grafana.
          '';
        };
      };
    };

    monitoring = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable periodic service/container health checks via systemd timer.";
      };

      interval = lib.mkOption {
        type = lib.types.str;
        default = "5m";
        description = "How often to run the Grafana healthcheck (for example `5m`).";
      };
    };

    backup = {
      enable = lib.mkEnableOption "periodic Grafana data backups";

      targetDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/backups/grafana";
        description = "Directory where compressed Grafana backup archives are written.";
      };

      schedule = lib.mkOption {
        type = lib.types.str;
        default = "daily";
        description = "Systemd OnCalendar expression for Grafana backups.";
      };

      keepDays = lib.mkOption {
        type = lib.types.ints.positive;
        default = 14;
        description = "How many days of backup archives to keep.";
      };
    };

    provisioning = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable declarative provisioning for Grafana datasources and starter dashboards.";
      };

      datasources = {
        prometheus = {
          url = lib.mkOption {
            type = lib.types.str;
            default = "http://prometheus:9090";
            description = "Prometheus URL used by provisioned Grafana datasource.";
          };
        };

        loki = {
          url = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "http://loki.internal.example:3100";
            description = "Optional Loki URL for a provisioned Grafana datasource.";
          };
        };
      };

      dashboards = {
        enableStarter = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Provision a starter Homelab overview dashboard.";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.grafanaCompose.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.grafanaCompose.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.grafanaCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.grafanaCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.grafanaCompose.image.tag must be pinned (not `latest`) unless services.grafanaCompose.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.grafanaCompose.dataDir must be an absolute path.";
      }
      {
        assertion = cfg.adminPasswordFile != null;
        message = "services.grafanaCompose.adminPasswordFile must be set when enabling Grafana.";
      }
      {
        assertion = !cfg.auth.genericOauth.enable || cfg.auth.genericOauth.clientIdFile != null;
        message = "services.grafanaCompose.auth.genericOauth.clientIdFile must be set when Generic OAuth is enabled.";
      }
      {
        assertion = !cfg.auth.genericOauth.enable || cfg.auth.genericOauth.clientSecretFile != null;
        message = "services.grafanaCompose.auth.genericOauth.clientSecretFile must be set when Generic OAuth is enabled.";
      }
      {
        assertion = cfg.database.type != "postgres" || cfg.database.postgres.passwordFile != null;
        message = "services.grafanaCompose.database.postgres.passwordFile must be set when database.type = \"postgres\".";
      }
      {
        assertion = cfg.database.type != "postgres" || builtins.match "^[^[:space:]]+$" cfg.database.postgres.host != null;
        message = "services.grafanaCompose.database.postgres.host must not contain whitespace.";
      }
      {
        assertion = cfg.database.type != "postgres" || builtins.match "^[^[:space:]]+$" cfg.database.postgres.name != null;
        message = "services.grafanaCompose.database.postgres.name must not contain whitespace.";
      }
      {
        assertion = cfg.database.type != "postgres" || builtins.match "^[^[:space:]]+$" cfg.database.postgres.user != null;
        message = "services.grafanaCompose.database.postgres.user must not contain whitespace.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.backup.targetDir;
        message = "services.grafanaCompose.backup.targetDir must be an absolute path.";
      }
      {
        assertion = !cfg.backup.enable || (!lib.hasPrefix "${cfg.dataDir}/" cfg.backup.targetDir && cfg.backup.targetDir != cfg.dataDir);
        message = "services.grafanaCompose.backup.targetDir must not be inside services.grafanaCompose.dataDir.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;
    environment.etc."${serviceName}/provisioning/datasources/datasources.yml" = lib.mkIf cfg.provisioning.enable {
      text = datasourcesYaml;
      mode = "0444";
    };
    environment.etc."${serviceName}/provisioning/dashboards/providers.yml" = lib.mkIf cfg.provisioning.enable {
      text = dashboardsProviderYaml;
      mode = "0444";
    };
    environment.etc."${serviceName}/provisioning/dashboards/homelab-overview.json" = lib.mkIf (cfg.provisioning.enable && cfg.provisioning.dashboards.enableStarter) {
      text = starterDashboardJson;
      mode = "0444";
    };
    environment.etc."${serviceName}/provisioning/dashboards/nodes-detail.json" = lib.mkIf (cfg.provisioning.enable && cfg.provisioning.dashboards.enableStarter) {
      text = nodesDetailDashboardJson;
      mode = "0444";
    };
    environment.etc."${serviceName}/provisioning/dashboards/container-fleet.json" = lib.mkIf (cfg.provisioning.enable && cfg.provisioning.dashboards.enableStarter) {
      text = containerFleetDashboardJson;
      mode = "0444";
    };
    environment.etc."${serviceName}/provisioning/dashboards/dns-edge.json" = lib.mkIf (cfg.provisioning.enable && cfg.provisioning.dashboards.enableStarter) {
      text = dnsEdgeDashboardJson;
      mode = "0444";
    };
    environment.etc."${serviceName}/provisioning/dashboards/nas-detail.json" = lib.mkIf (cfg.provisioning.enable && cfg.provisioning.dashboards.enableStarter) {
      text = nasDetailDashboardJson;
      mode = "0444";
    };
    environment.etc."${serviceName}/provisioning/dashboards/nas-file-activity.json" = lib.mkIf (cfg.provisioning.enable && cfg.provisioning.dashboards.enableStarter && cfg.provisioning.datasources.loki.url != null) {
      text = nasFileActivityDashboardJson;
      mode = "0444";
    };
    environment.etc."${serviceName}/provisioning/dashboards/gitea-overview.json" = lib.mkIf (cfg.provisioning.enable && cfg.provisioning.dashboards.enableStarter) {
      text = giteaOverviewDashboardJson;
      mode = "0444";
    };
    environment.etc."${serviceName}/provisioning/dashboards/shared-infra.json" = lib.mkIf (cfg.provisioning.enable && cfg.provisioning.dashboards.enableStarter) {
      text = sharedInfraDashboardJson;
      mode = "0444";
    };
    environment.etc."${serviceName}/provisioning/dashboards/monitoring-control-plane.json" = lib.mkIf (cfg.provisioning.enable && cfg.provisioning.dashboards.enableStarter) {
      text = monitoringControlPlaneDashboardJson;
      mode = "0444";
    };
    environment.etc."${serviceName}/provisioning/dashboards/edge-service-reliability.json" = lib.mkIf (cfg.provisioning.enable && cfg.provisioning.dashboards.enableStarter) {
      text = edgeServiceReliabilityDashboardJson;
      mode = "0444";
    };
    environment.etc."${serviceName}/provisioning/dashboards/alerting-triage.json" = lib.mkIf (cfg.provisioning.enable && cfg.provisioning.dashboards.enableStarter) {
      text = alertingTriageDashboardJson;
      mode = "0444";
    };
    environment.etc."${serviceName}/provisioning/dashboards/smtp-relay-operations.json" = lib.mkIf (cfg.provisioning.enable && cfg.provisioning.dashboards.enableStarter) {
      text = smtpRelayOperationsDashboardJson;
      mode = "0444";
    };
    environment.etc."${serviceName}/provisioning/dashboards/service-sli.json" = lib.mkIf (cfg.provisioning.enable && cfg.provisioning.dashboards.enableStarter) {
      text = serviceSliDashboardJson;
      mode = "0444";
    };
    environment.etc."${serviceName}/provisioning/dashboards/logs-pipeline.json" = lib.mkIf (cfg.provisioning.enable && cfg.provisioning.dashboards.enableStarter && cfg.provisioning.datasources.loki.url != null) {
      text = logsPipelineDashboardJson;
      mode = "0444";
    };
    environment.etc."${serviceName}/provisioning/dashboards/unifi-overview.json" = lib.mkIf (cfg.provisioning.enable && cfg.provisioning.dashboards.enableStarter) {
      text = unifiOverviewDashboardJson;
      mode = "0444";
    };

    systemd.services.${serviceName} = {
      description = "Grafana (Docker Compose)";

      wantedBy = ["multi-user.target"];
      requires = ["docker.service"];
      after = ["docker.service" "network-online.target"];
      wants = ["network-online.target"];
      restartTriggers =
        lib.optionals cfg.provisioning.enable [
          config.environment.etc."${serviceName}/provisioning/datasources/datasources.yml".source
          config.environment.etc."${serviceName}/provisioning/dashboards/providers.yml".source
        ]
        ++ lib.optionals (cfg.provisioning.enable && cfg.provisioning.dashboards.enableStarter) [
          config.environment.etc."${serviceName}/provisioning/dashboards/homelab-overview.json".source
          config.environment.etc."${serviceName}/provisioning/dashboards/nodes-detail.json".source
          config.environment.etc."${serviceName}/provisioning/dashboards/container-fleet.json".source
          config.environment.etc."${serviceName}/provisioning/dashboards/dns-edge.json".source
          config.environment.etc."${serviceName}/provisioning/dashboards/nas-detail.json".source
          config.environment.etc."${serviceName}/provisioning/dashboards/gitea-overview.json".source
          config.environment.etc."${serviceName}/provisioning/dashboards/shared-infra.json".source
          config.environment.etc."${serviceName}/provisioning/dashboards/monitoring-control-plane.json".source
          config.environment.etc."${serviceName}/provisioning/dashboards/edge-service-reliability.json".source
          config.environment.etc."${serviceName}/provisioning/dashboards/alerting-triage.json".source
          config.environment.etc."${serviceName}/provisioning/dashboards/smtp-relay-operations.json".source
          config.environment.etc."${serviceName}/provisioning/dashboards/service-sli.json".source
          config.environment.etc."${serviceName}/provisioning/dashboards/unifi-overview.json".source
        ]
        ++ lib.optionals (cfg.provisioning.enable && cfg.provisioning.dashboards.enableStarter && cfg.provisioning.datasources.loki.url != null) [
          config.environment.etc."${serviceName}/provisioning/dashboards/nas-file-activity.json".source
          config.environment.etc."${serviceName}/provisioning/dashboards/logs-pipeline.json".source
        ]
        ++ [
          config.environment.etc."${serviceName}/docker-compose.yml".source
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
          "GRAFANA_CONTAINER_NAME=${cfg.containerName}"
          "GRAFANA_IMAGE_REPOSITORY=${cfg.image.repository}"
          "GRAFANA_IMAGE_TAG=${cfg.image.tag}"
          "GRAFANA_NETWORK=${cfg.network}"
          "GRAFANA_HOSTNAME=${cfg.hostname}"
          "GRAFANA_ENTRYPOINTS=${
            if cfg.tls
            then "websecure"
            else "web"
          }"
          "GRAFANA_TLS=${
            if cfg.tls
            then "true"
            else "false"
          }"
          "GRAFANA_DATA_DIR=${cfg.dataDir}"
          "GRAFANA_ENV_FILE=/run/secrets/${serviceName}.env"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre =
          [
            "${pkgs.runtimeShell} -c 'mkdir -p ${cfg.dataDir} && chown 472:472 ${cfg.dataDir} && chmod 0750 ${cfg.dataDir}'"
            "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          ]
          ++ lib.optionals cfg.provisioning.enable [
            "${pkgs.runtimeShell} -c 'test -s ${composeDir}/provisioning/datasources/datasources.yml'"
            "${pkgs.runtimeShell} -c 'test -s ${composeDir}/provisioning/dashboards/providers.yml'"
          ]
          ++ lib.optionals (cfg.provisioning.enable && cfg.provisioning.dashboards.enableStarter) [
            "${pkgs.runtimeShell} -c 'test -s ${composeDir}/provisioning/dashboards/homelab-overview.json'"
            "${pkgs.runtimeShell} -c 'test -s ${composeDir}/provisioning/dashboards/nodes-detail.json'"
            "${pkgs.runtimeShell} -c 'test -s ${composeDir}/provisioning/dashboards/container-fleet.json'"
            "${pkgs.runtimeShell} -c 'test -s ${composeDir}/provisioning/dashboards/dns-edge.json'"
            "${pkgs.runtimeShell} -c 'test -s ${composeDir}/provisioning/dashboards/nas-detail.json'"
            "${pkgs.runtimeShell} -c 'test -s ${composeDir}/provisioning/dashboards/gitea-overview.json'"
            "${pkgs.runtimeShell} -c 'test -s ${composeDir}/provisioning/dashboards/shared-infra.json'"
            "${pkgs.runtimeShell} -c 'test -s ${composeDir}/provisioning/dashboards/monitoring-control-plane.json'"
            "${pkgs.runtimeShell} -c 'test -s ${composeDir}/provisioning/dashboards/edge-service-reliability.json'"
            "${pkgs.runtimeShell} -c 'test -s ${composeDir}/provisioning/dashboards/alerting-triage.json'"
            "${pkgs.runtimeShell} -c 'test -s ${composeDir}/provisioning/dashboards/smtp-relay-operations.json'"
            "${pkgs.runtimeShell} -c 'test -s ${composeDir}/provisioning/dashboards/service-sli.json'"
            "${pkgs.runtimeShell} -c 'test -s ${composeDir}/provisioning/dashboards/unifi-overview.json'"
          ]
          ++ lib.optionals (cfg.provisioning.enable && cfg.provisioning.dashboards.enableStarter && cfg.provisioning.datasources.loki.url != null) [
            "${pkgs.runtimeShell} -c 'test -s ${composeDir}/provisioning/dashboards/nas-file-activity.json'"
            "${pkgs.runtimeShell} -c 'test -s ${composeDir}/provisioning/dashboards/logs-pipeline.json'"
          ]
          ++ [
            "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"grafana: docker daemon is not ready\" >&2; exit 1'"
            runtimeEnvScript
            "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
            "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
          ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStartPost = waitForHealthy;
        ExecStop = "${dockerBin} compose down";
      };
    };

    systemd.services."${serviceName}-healthcheck" = lib.mkIf cfg.monitoring.enable {
      description = "Grafana periodic healthcheck";
      after = ["${serviceName}.service"];
      requires = ["${serviceName}.service"];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = healthcheckScript;
      };
    };

    systemd.timers."${serviceName}-healthcheck" = lib.mkIf cfg.monitoring.enable {
      description = "Run Grafana periodic healthcheck";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "2m";
        OnUnitActiveSec = cfg.monitoring.interval;
        Unit = "${serviceName}-healthcheck.service";
      };
    };

    systemd.services."${serviceName}-backup" = lib.mkIf cfg.backup.enable {
      description = "Backup Grafana data";
      after = ["${serviceName}.service"];
      requires = ["${serviceName}.service"];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = backupScript;
      };
    };

    systemd.timers."${serviceName}-backup" = lib.mkIf cfg.backup.enable {
      description = "Periodic Grafana backup";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.backup.schedule;
        Persistent = true;
        Unit = "${serviceName}-backup.service";
      };
    };
  };
}
