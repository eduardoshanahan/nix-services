{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.grafanaCompose;
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};
  runtimeSecretEnv = import ../../lib/runtime-secret-env.nix {inherit lib pkgs;};
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
    dnsEdgeDashboardJson
    nasDetailDashboardJson
    nasFileActivityDashboardJson
    giteaOverviewDashboardJson
    unifiOverviewDashboardJson
    ;
  inherit (scripts) backupScript healthcheckScript waitForHealthy;
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
          config.environment.etc."${serviceName}/provisioning/dashboards/dns-edge.json".source
          config.environment.etc."${serviceName}/provisioning/dashboards/nas-detail.json".source
          config.environment.etc."${serviceName}/provisioning/dashboards/gitea-overview.json".source
          config.environment.etc."${serviceName}/provisioning/dashboards/unifi-overview.json".source
        ]
        ++ lib.optionals (cfg.provisioning.enable && cfg.provisioning.dashboards.enableStarter && cfg.provisioning.datasources.loki.url != null) [
          config.environment.etc."${serviceName}/provisioning/dashboards/nas-file-activity.json".source
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
            "${pkgs.runtimeShell} -c 'test -s ${composeDir}/provisioning/dashboards/dns-edge.json'"
            "${pkgs.runtimeShell} -c 'test -s ${composeDir}/provisioning/dashboards/nas-detail.json'"
            "${pkgs.runtimeShell} -c 'test -s ${composeDir}/provisioning/dashboards/gitea-overview.json'"
            "${pkgs.runtimeShell} -c 'test -s ${composeDir}/provisioning/dashboards/unifi-overview.json'"
          ]
          ++ lib.optionals (cfg.provisioning.enable && cfg.provisioning.dashboards.enableStarter && cfg.provisioning.datasources.loki.url != null) [
            "${pkgs.runtimeShell} -c 'test -s ${composeDir}/provisioning/dashboards/nas-file-activity.json'"
          ]
          ++ [
            "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"grafana: docker daemon is not ready\" >&2; exit 1'"
            (runtimeSecretEnv.mkRuntimeSecretEnvExecStartPre {
              name = serviceName;
              secretFile = cfg.adminPasswordFile;
              envVar = "GF_SECURITY_ADMIN_PASSWORD";
            })
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
