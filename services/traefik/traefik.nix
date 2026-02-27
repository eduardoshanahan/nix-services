{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.traefik;
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};

  serviceName = "traefik";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";

  render = import ./render.nix {
    inherit lib pkgs cfg;
  };

  inherit
    (render)
    tlsEnabled
    httpToHttpsRedirectEnabled
    tlsFilesCheck
    composeText
    tlsConfigText
    ;
in {
  imports = [
    ./options.nix
  ];
  config = {
    assertions = [
      {
        assertion = !tlsEnabled || cfg.tls.certFile != null;
        message = "services.traefik.tls.certFile must be set when TLS is enabled.";
      }
      {
        assertion = !tlsEnabled || cfg.tls.keyFile != null;
        message = "services.traefik.tls.keyFile must be set when TLS is enabled.";
      }
      {
        assertion = !httpToHttpsRedirectEnabled || tlsEnabled;
        message = "services.traefik.httpToHttpsRedirect requires services.traefik.tls.enable = true.";
      }
      {
        assertion = !cfg.ghostActivityPub.enable || cfg.ghostActivityPub.hostname != "";
        message = "services.traefik.ghostActivityPub.hostname must be set when services.traefik.ghostActivityPub.enable = true.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".text = composeText;
    environment.etc."traefik/tls.yml".text = tlsConfigText;

    systemd.services.${serviceName} = {
      description = "Traefik ingress (Docker Compose)";

      wantedBy = ["multi-user.target"];
      after = ["docker.service" "network-online.target"];
      wants = ["network-online.target"];
      restartTriggers = [
        config.environment.etc."${serviceName}/docker-compose.yml".source
        config.environment.etc."traefik/tls.yml".source
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;

        WorkingDirectory = composeDir;

        Environment =
          [
            "TRAEFIK_CONTAINER_NAME=${cfg.containerName}"
            "TRAEFIK_NETWORK=${cfg.network}"
          ]
          ++ runtimeSecrets.mkSecretFileEnvVar {
            envVar = "TRAEFIK_ENV_FILE";
            inherit (cfg) secretFile;
            fallback = "/dev/null";
          };

        ExecStartPre =
          [
            "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
          ]
          ++ lib.optionals tlsEnabled [
            tlsFilesCheck
          ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
