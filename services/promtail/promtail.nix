{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.promtailCompose;
  serviceName = "promtail";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";

  render = import ./render.nix {
    inherit lib cfg;
  };

  inherit (render) configYaml;
in {
  imports = [
    ./options.nix
  ];
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.lokiPushUrl != null;
        message = "services.promtailCompose.lokiPushUrl must be set when enabling Promtail.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.promtailCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.promtailCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.promtailCompose.image.tag must be pinned (not `latest`) unless services.promtailCompose.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.promtailCompose.dataDir must be an absolute path.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    environment.etc."${serviceName}/config.yml".text = configYaml;

    systemd.services.${serviceName} = {
      description = "Promtail log shipper (Docker Compose)";

      wantedBy = ["multi-user.target"];
      after = ["docker.service" "network-online.target"];
      wants = ["network-online.target"];
      restartTriggers = [
        config.environment.etc."${serviceName}/docker-compose.yml".source
        config.environment.etc."${serviceName}/config.yml".source
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
          "PROMTAIL_CONTAINER_NAME=${cfg.containerName}"
          "PROMTAIL_IMAGE_REPOSITORY=${cfg.image.repository}"
          "PROMTAIL_IMAGE_TAG=${cfg.image.tag}"
          "PROMTAIL_DATA_DIR=${cfg.dataDir}"
          "PROMTAIL_HTTP_PORT=${toString cfg.httpPort}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${cfg.dataDir} && chmod 0750 ${cfg.dataDir}'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/config.yml'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"promtail: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
