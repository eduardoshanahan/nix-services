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
  externalUrl = "${if cfg.tls then "https" else "http"}://${cfg.hostname}/";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";

  configTexts = import ./config-text.nix {
    inherit lib cfg;
  };

  inherit (configTexts) prometheusConfigText alertRulesText;
in {
  imports = [
    ./options.nix
  ];
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

    environment.etc."${serviceName}/alert.rules.yml".text = alertRulesText;

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
          "PROMETHEUS_ENTRYPOINTS=${
            if cfg.tls
            then "websecure"
            else "web"
          }"
          "PROMETHEUS_TLS=${
            if cfg.tls
            then "true"
            else "false"
          }"
          "PROMETHEUS_DATA_DIR=${cfg.dataDir}"
          "PROMETHEUS_RETENTION_TIME=${cfg.retentionTime}"
          "PROMETHEUS_EXTERNAL_URL=${externalUrl}"
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
