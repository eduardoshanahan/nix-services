{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.daysuntilCompose;
  serviceName = "daysuntil";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
  digestRegex = "^sha256:[0-9a-f]{64}$";
  imageRef =
    if cfg.image.digest == null
    then "${cfg.image.repository}:${cfg.image.tag}"
    else "${cfg.image.repository}@${cfg.image.digest}";

  scripts = import ./scripts.nix {
    inherit pkgs cfg serviceName dockerBin;
  };

  inherit (scripts) healthcheckScript waitForHealthy;
in {
  imports = [
    ./options.nix
  ];
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.daysuntilCompose.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.daysuntilCompose.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.daysuntilCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.daysuntilCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.digest == null || builtins.match digestRegex cfg.image.digest != null;
        message = "services.daysuntilCompose.image.digest must match `sha256:<64 lowercase hex characters>` when set.";
      }
      {
        assertion = cfg.image.digest != null || cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.daysuntilCompose.image.tag must be pinned (not `latest`) unless services.daysuntilCompose.image.allowMutableTag = true.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root -"
    ];

    systemd.services.${serviceName} = {
      description = "daysuntil (Docker Compose)";

      wantedBy = ["multi-user.target"];
      requires = ["docker.service"];
      after = ["docker.service" "network-online.target"];
      wants = ["network-online.target"];
      restartTriggers = [
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
          "DAYSUNTIL_CONTAINER_NAME=${cfg.containerName}"
          "DAYSUNTIL_IMAGE=${imageRef}"
          "DAYSUNTIL_NETWORK=${cfg.network}"
          "DAYSUNTIL_HOSTNAME=${cfg.hostname}"
          "DAYSUNTIL_DATA_DIR=${cfg.dataDir}"
          "DAYSUNTIL_ENTRYPOINTS=${
            if cfg.tls
            then "websecure"
            else "web"
          }"
          "DAYSUNTIL_TLS=${
            if cfg.tls
            then "true"
            else "false"
          }"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"daysuntil: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStartPost = waitForHealthy;
        ExecStop = "${dockerBin} compose down";
      };
    };

    systemd.services."${serviceName}-healthcheck" = lib.mkIf cfg.monitoring.enable {
      description = "daysuntil periodic healthcheck";
      after = ["${serviceName}.service"];
      requires = ["${serviceName}.service"];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = healthcheckScript;
      };
    };

    systemd.timers."${serviceName}-healthcheck" = lib.mkIf cfg.monitoring.enable {
      description = "Run daysuntil periodic healthcheck";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "2m";
        OnUnitActiveSec = cfg.monitoring.interval;
        Unit = "${serviceName}-healthcheck.service";
      };
    };
  };
}
