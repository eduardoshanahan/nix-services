{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.diagramsNet;
  serviceName = "diagrams-net";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";

  scripts = import ./scripts.nix {
    inherit pkgs cfg dockerBin;
  };

  inherit (scripts) waitForHealthy;
in {
  imports = [
    ./options.nix
  ];
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.diagramsNet.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.diagramsNet.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.diagramsNet.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.diagramsNet.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.diagramsNet.image.tag must be pinned (not `latest`) unless services.diagramsNet.image.allowMutableTag = true.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "diagrams.net (Docker Compose)";

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
          "DIAGRAMS_NET_CONTAINER_NAME=${cfg.containerName}"
          "DIAGRAMS_NET_IMAGE_REPOSITORY=${cfg.image.repository}"
          "DIAGRAMS_NET_IMAGE_TAG=${cfg.image.tag}"
          "DIAGRAMS_NET_NETWORK=${cfg.network}"
          "DIAGRAMS_NET_HOSTNAME=${cfg.hostname}"
          "DIAGRAMS_NET_ENTRYPOINTS=${
            if cfg.tls
            then "websecure"
            else "web"
          }"
          "DIAGRAMS_NET_TLS=${
            if cfg.tls
            then "true"
            else "false"
          }"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p /var/lib/diagrams-net && chown 1000:1000 /var/lib/diagrams-net && chmod 0750 /var/lib/diagrams-net'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"diagrams-net: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStartPost = waitForHealthy;
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
