{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homepageDashboard;
  serviceName = "homepage";
  composeDir = "/etc/${serviceName}";
  configDir = "${composeDir}/config";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  yamlFormat = pkgs.formats.yaml {};
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
  digestRegex = "^sha256:[0-9a-f]{64}$";
  imageRef =
    if cfg.image.digest == null
    then "${cfg.image.repository}:${cfg.image.tag}"
    else "${cfg.image.repository}@${cfg.image.digest}";
  allowedHosts = lib.unique (
    [cfg.hostname]
    ++ lib.optional cfg.tls "${cfg.hostname}:443"
    ++ lib.optional (!cfg.tls) "${cfg.hostname}:80"
    ++ cfg.extraAllowedHosts
  );
  render = import ./render.nix {
    inherit lib cfg imageRef configDir allowedHosts;
  };
  inherit (render) composeYaml settingsYaml servicesYaml bookmarksYaml widgetsYaml dockerYaml;
in {
  imports = [
    ./options.nix
  ];

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.homepageDashboard.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.homepageDashboard.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.homepageDashboard.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.homepageDashboard.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.digest == null || builtins.match digestRegex cfg.image.digest != null;
        message = "services.homepageDashboard.image.digest must match `sha256:<64 lowercase hex characters>` when set.";
      }
      {
        assertion = cfg.image.digest != null || cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.homepageDashboard.image.tag must be pinned (not `latest`) unless services.homepageDashboard.image.allowMutableTag = true.";
      }
      {
        assertion = !cfg.docker.enable || lib.hasPrefix "/" cfg.docker.socketPath;
        message = "services.homepageDashboard.docker.socketPath must be an absolute path when Docker integration is enabled.";
      }
      {
        assertion = builtins.isAttrs cfg.config.settings;
        message = "services.homepageDashboard.config.settings must be a YAML object / Nix attrset.";
      }
      {
        assertion = builtins.isList cfg.config.services;
        message = "services.homepageDashboard.config.services must be a YAML array / Nix list.";
      }
      {
        assertion = builtins.isList cfg.config.bookmarks;
        message = "services.homepageDashboard.config.bookmarks must be a YAML array / Nix list.";
      }
      {
        assertion = builtins.isList cfg.config.widgets;
        message = "services.homepageDashboard.config.widgets must be a YAML array / Nix list.";
      }
      {
        assertion = builtins.isAttrs cfg.config.docker;
        message = "services.homepageDashboard.config.docker must be a YAML object / Nix attrset.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".text = composeYaml;
    environment.etc."${serviceName}/config/settings.yaml".source =
      yamlFormat.generate "homepage-settings.yaml" settingsYaml;
    environment.etc."${serviceName}/config/services.yaml".source =
      yamlFormat.generate "homepage-services.yaml" servicesYaml;
    environment.etc."${serviceName}/config/bookmarks.yaml".source =
      yamlFormat.generate "homepage-bookmarks.yaml" bookmarksYaml;
    environment.etc."${serviceName}/config/widgets.yaml".source =
      yamlFormat.generate "homepage-widgets.yaml" widgetsYaml;
    environment.etc."${serviceName}/config/docker.yaml".source =
      yamlFormat.generate "homepage-docker.yaml" dockerYaml;

    systemd.services.${serviceName} = {
      description = "Homepage dashboard (Docker Compose)";

      wantedBy = ["multi-user.target"];
      requires = ["docker.service"];
      after = ["docker.service" "network-online.target"];
      wants = ["network-online.target"];
      restartTriggers = [
        config.environment.etc."${serviceName}/docker-compose.yml".source
        config.environment.etc."${serviceName}/config/settings.yaml".source
        config.environment.etc."${serviceName}/config/services.yaml".source
        config.environment.etc."${serviceName}/config/bookmarks.yaml".source
        config.environment.etc."${serviceName}/config/widgets.yaml".source
        config.environment.etc."${serviceName}/config/docker.yaml".source
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

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'test -s ${configDir}/settings.yaml'"
          "${pkgs.runtimeShell} -c 'test -s ${configDir}/services.yaml'"
          "${pkgs.runtimeShell} -c 'test -s ${configDir}/bookmarks.yaml'"
          "${pkgs.runtimeShell} -c 'test -s ${configDir}/widgets.yaml'"
          "${pkgs.runtimeShell} -c 'test -s ${configDir}/docker.yaml'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"homepage: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ] ++ lib.optional cfg.docker.enable "${pkgs.runtimeShell} -c 'test -S ${cfg.docker.socketPath}'";

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
