{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homeAssistant;
  runtimeSecretEnv = import ../../lib/runtime-secret-env.nix {inherit lib pkgs;};
  serviceName = "home-assistant";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
  proxyRegex = "^([0-9]{1,3}\\.){3}[0-9]{1,3}(/([0-9]|[1-2][0-9]|3[0-2]))?$";
  managedProxyHeader = "# BEGIN NIX-SERVICES HOME-ASSISTANT REVERSE PROXY";
  managedProxyFooter = "# END NIX-SERVICES HOME-ASSISTANT REVERSE PROXY";
  managedRecorderHeader = "# BEGIN NIX-SERVICES HOME-ASSISTANT RECORDER";
  managedRecorderFooter = "# END NIX-SERVICES HOME-ASSISTANT RECORDER";
  proxyYamlLines = builtins.concatStringsSep "\n" (map (p: "    - ${p}") cfg.reverseProxy.trustedProxies);
  ensureProxyConfigScript = pkgs.writeShellScript "home-assistant-ensure-proxy-config" ''
    set -eu

    if [ "${if cfg.reverseProxy.enable then "1" else "0"}" != "1" ]; then
      exit 0
    fi

    cfgFile="${cfg.dataDir}/configuration.yaml"

    if [ ! -f "$cfgFile" ]; then
      cat >"$cfgFile" <<'EOF'
# Loads default set of integrations. Do not remove.
default_config:

# Load frontend themes from the themes folder
frontend:
  themes: !include_dir_merge_named themes

automation: !include automations.yaml
script: !include scripts.yaml
scene: !include scenes.yaml
EOF
    fi

    if grep -q "^http:" "$cfgFile" && ! grep -q "${managedProxyHeader}" "$cfgFile"; then
      echo "home-assistant: existing un-managed http: block found; leaving it unchanged" >&2
      exit 0
    fi

    tmpFile="$(mktemp)"
    sed "/${managedProxyHeader}/,/${managedProxyFooter}/d" "$cfgFile" > "$tmpFile"
    cat >>"$tmpFile" <<EOF

${managedProxyHeader}
http:
  use_x_forwarded_for: ${if cfg.reverseProxy.useXForwardedFor then "true" else "false"}
  trusted_proxies:
${proxyYamlLines}
${managedProxyFooter}
EOF
    mv "$tmpFile" "$cfgFile"
  '';
  ensureRecorderConfigScript = pkgs.writeShellScript "home-assistant-ensure-recorder-config" ''
    set -eu

    cfgFile="${cfg.dataDir}/configuration.yaml"

    if [ ! -f "$cfgFile" ]; then
      cat >"$cfgFile" <<'EOF'
# Loads default set of integrations. Do not remove.
default_config:

# Load frontend themes from the themes folder
frontend:
  themes: !include_dir_merge_named themes

automation: !include automations.yaml
script: !include scripts.yaml
scene: !include scenes.yaml
EOF
    fi

    tmpFile="$(mktemp)"
    sed "/${managedRecorderHeader}/,/${managedRecorderFooter}/d" "$cfgFile" > "$tmpFile"

    if [ "${if cfg.recorder.dbUrlFile != null then "1" else "0"}" = "1" ]; then
      cat >>"$tmpFile" <<EOF

${managedRecorderHeader}
recorder:
  db_url: !env_var HOME_ASSISTANT_RECORDER_DB_URL
${managedRecorderFooter}
EOF
    fi

    mv "$tmpFile" "$cfgFile"
  '';
in {
  imports = [
    ./options.nix
  ];

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.homeAssistant.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.homeAssistant.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.homeAssistant.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.homeAssistant.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.homeAssistant.image.tag must be pinned (not `latest`) unless services.homeAssistant.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.homeAssistant.dataDir must be an absolute path.";
      }
      {
        assertion = (!cfg.reverseProxy.enable) || (cfg.reverseProxy.trustedProxies != []);
        message = "services.homeAssistant.reverseProxy.trustedProxies must be non-empty when reverseProxy is enabled.";
      }
      {
        assertion = builtins.all (p: builtins.match proxyRegex p != null) cfg.reverseProxy.trustedProxies;
        message = "services.homeAssistant.reverseProxy.trustedProxies entries must be IPv4 addresses/CIDRs (for example 172.18.0.0/16).";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "Home Assistant (Docker Compose)";

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
        TimeoutStartSec = 900;
        Restart = "on-failure";
        RestartSec = 10;
        WorkingDirectory = composeDir;

        Environment = [
          "HOME_ASSISTANT_CONTAINER_NAME=${cfg.containerName}"
          "HOME_ASSISTANT_IMAGE_REPOSITORY=${cfg.image.repository}"
          "HOME_ASSISTANT_IMAGE_TAG=${cfg.image.tag}"
          "HOME_ASSISTANT_NETWORK=${cfg.network}"
          "HOME_ASSISTANT_HOSTNAME=${cfg.hostname}"
          "HOME_ASSISTANT_ENTRYPOINTS=${if cfg.tls then "websecure" else "web"}"
          "HOME_ASSISTANT_TLS=${if cfg.tls then "true" else "false"}"
          "HOME_ASSISTANT_DATA_DIR=${cfg.dataDir}"
          "HOME_ASSISTANT_RECORDER_ENV_FILE=/run/secrets/${serviceName}.env"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre =
          [
            "${pkgs.runtimeShell} -c 'mkdir -p ${cfg.dataDir} && chmod 0750 ${cfg.dataDir}'"
            "${ensureProxyConfigScript}"
            "${ensureRecorderConfigScript}"
            "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          ]
          ++ lib.optionals (cfg.recorder.dbUrlFile == null) [
            "${pkgs.runtimeShell} -c 'install -d -m 0700 /run/secrets; : > /run/secrets/${serviceName}.env; chmod 0600 /run/secrets/${serviceName}.env'"
          ]
          ++ lib.optionals (cfg.recorder.dbUrlFile != null) [
            (runtimeSecretEnv.mkRuntimeSecretEnvExecStartPre {
              name = serviceName;
              secretFile = cfg.recorder.dbUrlFile;
              envVar = "HOME_ASSISTANT_RECORDER_DB_URL";
            })
          ]
          ++ [
            "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"home-assistant: docker daemon is not ready\" >&2; exit 1'"
            "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
            "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
          ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
