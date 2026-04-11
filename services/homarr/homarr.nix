{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homarr;
  runtimeSecretEnv = import ../../lib/runtime-secret-env.nix {inherit lib pkgs;};
  serviceName = "homarr";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
in {
  imports = [
    ./options.nix
  ];

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.homarr.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.homarr.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.homarr.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.homarr.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.homarr.image.tag must be pinned (not `latest`) unless services.homarr.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.homarr.dataDir must be an absolute path.";
      }
      {
        assertion = cfg.secretEncryptionKeyFile != null;
        message = "services.homarr.secretEncryptionKeyFile must be set.";
      }
      {
        assertion = builtins.length cfg.docker.hostnames == builtins.length cfg.docker.ports;
        message = "services.homarr.docker.hostnames and services.homarr.docker.ports must have the same length.";
      }
      {
        assertion = lib.all (host: builtins.match "^[^[:space:]]+$" host != null) cfg.docker.hostnames;
        message = "services.homarr.docker.hostnames entries must not contain whitespace.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "Homarr (Docker Compose)";

      wantedBy = ["multi-user.target"];
      requires = ["docker.service"];
      after = ["docker.service" "network-online.target"];
      wants = ["network-online.target"];
      restartTriggers = [
        config.environment.etc."${serviceName}/docker-compose.yml".source
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = 180;
        Restart = "on-failure";
        RestartSec = 10;
        WorkingDirectory = composeDir;

        Environment = [
          "HOMARR_CONTAINER_NAME=${cfg.containerName}"
          "HOMARR_IMAGE_REPOSITORY=${cfg.image.repository}"
          "HOMARR_IMAGE_TAG=${cfg.image.tag}"
          "HOMARR_NETWORK=${cfg.network}"
          "HOMARR_HOSTNAME=${cfg.hostname}"
          "HOMARR_ENTRYPOINTS=${if cfg.tls then "websecure" else "web"}"
          "HOMARR_TLS=${if cfg.tls then "true" else "false"}"
          "HOMARR_DATA_DIR=${cfg.dataDir}"
          "HOMARR_RUNTIME_ENV_FILE=/run/secrets/${serviceName}.env"
          "HOMARR_DOCKER_HOSTNAMES=${lib.concatStringsSep "," cfg.docker.hostnames}"
          "HOMARR_DOCKER_PORTS=${lib.concatStringsSep "," (map builtins.toString cfg.docker.ports)}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${lib.escapeShellArg cfg.dataDir} && chmod 0750 ${lib.escapeShellArg cfg.dataDir}'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          (runtimeSecretEnv.mkRuntimeSecretEnvExecStartPre {
            name = serviceName;
            secretFile = cfg.secretEncryptionKeyFile;
            envVar = "SECRET_ENCRYPTION_KEY";
          })
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"homarr: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
