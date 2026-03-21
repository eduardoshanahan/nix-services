{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.lokiCompose;
  serviceName = "loki";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";

  render = import ./render.nix {
    inherit lib pkgs cfg;
  };

  inherit (render) backupScript configYaml;
in {
  imports = [
    ./options.nix
  ];
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.lokiCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.lokiCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.lokiCompose.image.tag must be pinned (not `latest`) unless services.lokiCompose.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.lokiCompose.dataDir must be an absolute path.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.backup.targetDir;
        message = "services.lokiCompose.backup.targetDir must be an absolute path.";
      }
      {
        assertion = !cfg.backup.enable || (!lib.hasPrefix "${cfg.dataDir}/" cfg.backup.targetDir && cfg.backup.targetDir != cfg.dataDir);
        message = "services.lokiCompose.backup.targetDir must not be inside services.lokiCompose.dataDir.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    environment.etc."${serviceName}/config.yaml".text = configYaml;

    systemd.services.${serviceName} = {
      description = "Loki log aggregation service (Docker Compose)";

      wantedBy = ["multi-user.target"];
      after = ["docker.service" "network-online.target"];
      wants = ["network-online.target"];
      restartTriggers = [
        config.environment.etc."${serviceName}/docker-compose.yml".source
        config.environment.etc."${serviceName}/config.yaml".source
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
          "LOKI_CONTAINER_NAME=${cfg.containerName}"
          "LOKI_IMAGE_REPOSITORY=${cfg.image.repository}"
          "LOKI_IMAGE_TAG=${cfg.image.tag}"
          "LOKI_LISTEN_ADDRESS=${cfg.listenAddress}"
          "LOKI_HTTP_PORT=${toString cfg.httpPort}"
          "LOKI_DATA_DIR=${cfg.dataDir}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${cfg.dataDir} && chown 10001:10001 ${cfg.dataDir} && chmod 0750 ${cfg.dataDir}'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/config.yaml'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"loki: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };

    systemd.services."${serviceName}-backup" = lib.mkIf cfg.backup.enable {
      description = "Backup Loki data";
      after = ["${serviceName}.service"];
      requires = ["${serviceName}.service"];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = backupScript;
      };
    };

    systemd.timers."${serviceName}-backup" = lib.mkIf cfg.backup.enable {
      description = "Periodic Loki backup";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.backup.schedule;
        Persistent = true;
        Unit = "${serviceName}-backup.service";
      };
    };
  };
}
