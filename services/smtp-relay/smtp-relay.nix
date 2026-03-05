{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.smtpRelayCompose;
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};
  runtimeSecretEnv = import ../../lib/runtime-secret-env.nix {inherit lib pkgs;};

  serviceName = "smtp-relay";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  writeRelayPasswordEnv = runtimeSecretEnv.mkRuntimeSecretEnvExecStartPre {
    name = "smtp-relay";
    secretFile = cfg.upstream.passwordFile;
    envVar = "RELAYHOST_PASSWORD";
  };
in {
  options.services.smtpRelayCompose = {
    enable = lib.mkEnableOption "SMTP relay service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "smtp-relay";
      description = "Docker container name.";
    };

    hostname = lib.mkOption {
      type = lib.types.str;
      default = "smtp-relay.internal.example";
      description = "Hostname used by Postfix as `myhostname`.";
    };

    timezone = lib.mkOption {
      type = lib.types.str;
      default = "UTC";
      description = "Timezone passed to the container via `TZ`.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Host listen address for inbound SMTP submissions.";
      example = "127.0.0.1";
    };

    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 2525;
      description = "Host TCP port mapped to the container submission port (587).";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open `listenPort` in the host firewall.";
    };

    upstream = {
      host = lib.mkOption {
        type = lib.types.str;
        description = "Upstream SMTP relay host.";
        example = "smtp.gmail.com";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 587;
        description = "Upstream SMTP relay TCP port.";
      };

      username = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Upstream SMTP username (leave empty for unauthenticated relay).";
      };

      passwordFile = runtimeSecrets.mkSecretFileOption {
        description = ''
          Absolute path to a runtime-provisioned file containing only the upstream
          SMTP password on a single line.
        '';
        example = "/run/secrets/smtp-relay-password";
      };
    };

    allowedSenderDomains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["<homelab-domain>"];
      description = ''
        Sender domains allowed by the relay (`ALLOWED_SENDER_DOMAINS`).
        Must be non-empty to avoid accidental open relay behavior.
      '';
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "boky/postfix";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "4.4.0";
        description = "Container image tag.";
      };

      allowMutableTag = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Allow mutable tags such as `latest`. Keep disabled to enforce pinned
          image tags by default.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.smtpRelayCompose.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.smtpRelayCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.smtpRelayCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.smtpRelayCompose.image.tag must be pinned (not `latest`) unless services.smtpRelayCompose.image.allowMutableTag = true.";
      }
      {
        assertion = cfg.allowedSenderDomains != [];
        message = "services.smtpRelayCompose.allowedSenderDomains must be set and non-empty.";
      }
      {
        assertion = cfg.upstream.host != "";
        message = "services.smtpRelayCompose.upstream.host must be set.";
      }
      {
        assertion = (cfg.upstream.username == "") == (cfg.upstream.passwordFile == null);
        message = "Set both services.smtpRelayCompose.upstream.username and services.smtpRelayCompose.upstream.passwordFile together, or leave both unset.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "SMTP relay (Docker Compose)";

      wantedBy = ["multi-user.target"];
      after = ["docker.service" "network-online.target"];
      wants = ["network-online.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = composeDir;

        Environment = [
          "SMTP_RELAY_CONTAINER_NAME=${cfg.containerName}"
          "SMTP_RELAY_HOSTNAME=${cfg.hostname}"
          "SMTP_RELAY_LISTEN_ADDRESS=${cfg.listenAddress}"
          "SMTP_RELAY_LISTEN_PORT=${toString cfg.listenPort}"
          "SMTP_RELAY_UPSTREAM_HOST=[${cfg.upstream.host}]:${toString cfg.upstream.port}"
          "SMTP_RELAY_UPSTREAM_USERNAME=${cfg.upstream.username}"
          "SMTP_RELAY_RUNTIME_ENV_FILE=/run/secrets/smtp-relay.env"
          "\"SMTP_RELAY_ALLOWED_SENDER_DOMAINS=${lib.concatStringsSep " " cfg.allowedSenderDomains}\""
          "SMTP_RELAY_IMAGE_REPOSITORY=${cfg.image.repository}"
          "SMTP_RELAY_IMAGE_TAG=${cfg.image.tag}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre =
          [
            "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
            "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"smtp-relay: docker daemon is not ready\" >&2; exit 1'"
            "${pkgs.runtimeShell} -c 'install -d -m 0700 /run/secrets'"
          ]
          ++ lib.optionals (cfg.upstream.passwordFile != null) [
            "${pkgs.runtimeShell} -c '${writeRelayPasswordEnv}'"
          ]
          ++ lib.optionals (cfg.upstream.passwordFile == null) [
            "${pkgs.runtimeShell} -c ': > /run/secrets/smtp-relay.env && chmod 0600 /run/secrets/smtp-relay.env'"
          ]
          ++ [
            "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
          ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [cfg.listenPort];
  };
}
