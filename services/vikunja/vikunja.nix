{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.vikunjaCompose;
  serviceName = "vikunja";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
  publicUrl = "${
    if cfg.tls
    then "https"
    else "http"
  }://${cfg.hostname}/";
in {
  imports = [
    ./options.nix
  ];

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.vikunjaCompose.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.vikunjaCompose.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.vikunjaCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.vikunjaCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.vikunjaCompose.image.tag must be pinned (not `latest`) unless services.vikunjaCompose.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.vikunjaCompose.dataDir must be an absolute path.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "Vikunja (Docker Compose)";

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
          "VIKUNJA_CONTAINER_NAME=${cfg.containerName}"
          "VIKUNJA_IMAGE_REPOSITORY=${cfg.image.repository}"
          "VIKUNJA_IMAGE_TAG=${cfg.image.tag}"
          "VIKUNJA_NETWORK=${cfg.network}"
          "VIKUNJA_HOSTNAME=${cfg.hostname}"
          "VIKUNJA_ENTRYPOINTS=${
            if cfg.tls
            then "websecure"
            else "web"
          }"
          "VIKUNJA_TLS=${
            if cfg.tls
            then "true"
            else "false"
          }"
          "VIKUNJA_SERVICE_PUBLICURL=${publicUrl}"
          "VIKUNJA_SERVICE_ENABLEREGISTRATION=${
            if cfg.enableRegistration
            then "true"
            else "false"
          }"
          "VIKUNJA_DATA_DIR=${cfg.dataDir}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${cfg.dataDir} && chown 1000:0 ${cfg.dataDir} && chmod 0750 ${cfg.dataDir}'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"vikunja: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
