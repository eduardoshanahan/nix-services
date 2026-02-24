{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.prometheusCompose;
  serviceName = "prometheus";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";

  mkTargetLines = {
    targets,
    indent,
  }:
    map (target: "${indent}- \"${target}\"") targets;

  optionalJobLines = {
    name,
    targets,
  }:
    lib.optionals (targets != []) (
      [
        "  - job_name: \"${name}\""
        "    static_configs:"
        "      - targets:"
      ]
      ++ (mkTargetLines {
        inherit targets;
        indent = "        ";
      })
      ++ [""]
    );

  alertingLines = targets:
    lib.optionals (targets != []) (
      [
        "alerting:"
        "  alertmanagers:"
        "    - static_configs:"
        "        - targets:"
      ]
      ++ (mkTargetLines {
        inherit targets;
        indent = "          ";
      })
      ++ [""]
    );

  prometheusConfigText =
    lib.concatStringsSep "\n" (
      [
        "global:"
        "  scrape_interval: 15s"
        "  evaluation_interval: 15s"
        ""
        "rule_files:"
        "  - /etc/prometheus/alert.rules.yml"
        ""
      ]
      ++ lib.optionals cfg.alerting.enable (alertingLines cfg.alerting.targets)
      ++ [
        "scrape_configs:"
        "  - job_name: \"prometheus\""
        "    static_configs:"
        "      - targets: [\"127.0.0.1:9090\"]"
        ""
      ]
      ++ (optionalJobLines {
        name = "nodes";
        targets = cfg.scrape.nodeTargets;
      })
      ++ (optionalJobLines {
        name = "loki";
        targets = cfg.scrape.lokiTargets;
      })
      ++ (optionalJobLines {
        name = "alertmanager";
        targets = cfg.scrape.alertmanagerTargets;
      })
    )
    + "\n";
in {
  options.services.prometheusCompose = {
    enable = lib.mkEnableOption "Prometheus service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "prometheus";
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
      default = "/var/lib/prometheus";
      description = "Persistent host path used for Prometheus TSDB data.";
    };

    retentionTime = lib.mkOption {
      type = lib.types.str;
      default = "30d";
      description = "Prometheus TSDB retention time (for example `30d`).";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "prom/prometheus";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "v2.55.1";
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

    scrape = {
      nodeTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = [ "rpi-box-01.<homelab-domain>:9100" "rpi-box-02.<homelab-domain>:9100" ];
        description = "Node exporter targets (`host:port`).";
      };

      lokiTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = [ "loki.<homelab-domain>:3100" ];
        description = "Loki targets (`host:port`) to scrape.";
      };

      alertmanagerTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "alertmanager:9093" ];
        description = "Alertmanager targets (`host:port`) to scrape.";
      };
    };

    alerting = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Alertmanager integration in Prometheus config.";
      };

      targets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "alertmanager:9093" ];
        description = "Alertmanager targets (`host:port`) used under `alerting.alertmanagers`.";
      };
    };

    tls = lib.mkEnableOption "TLS on the Prometheus Traefik router";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.prometheusCompose.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.prometheusCompose.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.prometheusCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.prometheusCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.prometheusCompose.image.tag must be pinned (not `latest`) unless services.prometheusCompose.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.prometheusCompose.dataDir must be an absolute path.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    environment.etc."${serviceName}/prometheus.yml".text = prometheusConfigText;

    environment.etc."${serviceName}/alert.rules.yml".text = ''
      groups: []
    '';

    systemd.services.${serviceName} = {
      description = "Prometheus (Docker Compose)";

      wantedBy = ["multi-user.target"];
      requires = ["docker.service"];
      after = ["docker.service" "network-online.target"];
      wants = ["network-online.target"];
      restartTriggers = [
        config.environment.etc."${serviceName}/docker-compose.yml".source
        config.environment.etc."${serviceName}/prometheus.yml".source
        config.environment.etc."${serviceName}/alert.rules.yml".source
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
          "PROMETHEUS_CONTAINER_NAME=${cfg.containerName}"
          "PROMETHEUS_IMAGE_REPOSITORY=${cfg.image.repository}"
          "PROMETHEUS_IMAGE_TAG=${cfg.image.tag}"
          "PROMETHEUS_NETWORK=${cfg.network}"
          "PROMETHEUS_HOSTNAME=${cfg.hostname}"
          "PROMETHEUS_ENTRYPOINTS=${if cfg.tls then "websecure" else "web"}"
          "PROMETHEUS_TLS=${if cfg.tls then "true" else "false"}"
          "PROMETHEUS_DATA_DIR=${cfg.dataDir}"
          "PROMETHEUS_RETENTION_TIME=${cfg.retentionTime}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${cfg.dataDir} && chown 65534:65534 ${cfg.dataDir} && chmod 0750 ${cfg.dataDir}'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/prometheus.yml'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/alert.rules.yml'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"prometheus: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
