{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.tailscaleCompose;
  runtimeSecrets = import ../../lib/runtime-secrets.nix { inherit lib; };
  runtimeSecretEnv = import ../../lib/runtime-secret-env.nix { inherit lib pkgs; };

  serviceName = "tailscale";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";

  tailscaleArgs = lib.concatStringsSep " " (
    (lib.optional (cfg.advertiseRoutes != [ ]) "--advertise-routes=${lib.concatStringsSep "," cfg.advertiseRoutes}")
    ++ [
      "--accept-routes=${if cfg.acceptRoutes then "true" else "false"}"
      "--accept-dns=${if cfg.acceptDns then "true" else "false"}"
    ]
    ++ cfg.extraUpFlags
  );
in {
  options.services.tailscaleCompose = {
    enable = lib.mkEnableOption "Tailscale subnet router (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "tailscale";
      description = "Docker container name.";
    };

    hostname = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      description = "Hostname shown for this node in Tailscale.";
    };

    stateDir = lib.mkOption {
      type = runtimeSecrets.absolutePathType;
      default = "/var/lib/tailscale";
      description = "Persistent host directory for Tailscale state.";
    };

    socketPath = lib.mkOption {
      type = runtimeSecrets.absolutePathType;
      default = "/var/run/tailscale/tailscaled.sock";
      description = "Path to the tailscaled unix socket on the host.";
    };

    authKeyFile = runtimeSecrets.mkSecretFileOption {
      description = ''
        Absolute path to a runtime-provisioned file containing a Tailscale auth key.

        Leave null when the node is already authenticated and state is persisted.
      '';
      example = "/run/secrets/tailscale-authkey";
    };

    advertiseRoutes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "198.51.100.0/24" ];
      description = "Subnet routes advertised by this node.";
    };

    acceptRoutes = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Accept subnet routes advertised by other nodes.";
    };

    acceptDns = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow Tailscale to manage DNS configuration.";
    };

    extraUpFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "--ssh" ];
      description = "Additional flags passed to `tailscale up` through `TS_EXTRA_ARGS`.";
    };

    firewallMode = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "iptables" "nftables" ]);
      default = null;
      example = "nftables";
      description = ''
        Optional override for Tailscale's firewall backend inside the container.

        Set this to `nftables` on hosts where the container defaults to
        `iptables-legacy` but the host firewall stack is nftables-based.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open the Tailscale WireGuard UDP port in the host firewall.";
    };

    udpPort = lib.mkOption {
      type = lib.types.port;
      default = 41641;
      description = "Host UDP port for Tailscale WireGuard traffic.";
    };

    enableIpForwarding = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable IPv4/IPv6 forwarding when using subnet routes.";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "tailscale/tailscale";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "v1.96.5";
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
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.tailscaleCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.tailscaleCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.tailscaleCompose.image.tag must be pinned (not `latest`) unless services.tailscaleCompose.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" (toString cfg.stateDir);
        message = "services.tailscaleCompose.stateDir must be an absolute path.";
      }
      {
        assertion = lib.hasPrefix "/" (toString cfg.socketPath);
        message = "services.tailscaleCompose.socketPath must be an absolute path.";
      }
    ];

    virtualisation.docker.enable = true;
    boot.kernelModules = [ "tun" ];

    boot.kernel.sysctl = lib.mkIf cfg.enableIpForwarding {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };

    networking.firewall.allowedUDPPorts = lib.optionals cfg.openFirewall [ cfg.udpPort ];

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "Tailscale subnet router (Docker Compose)";

      wantedBy = [ "multi-user.target" ];
      after = [ "docker.service" "network-online.target" ];
      wants = [ "network-online.target" ];
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
          "TAILSCALE_CONTAINER_NAME=${cfg.containerName}"
          "TAILSCALE_HOSTNAME=${cfg.hostname}"
          "TAILSCALE_STATE_DIR=${toString cfg.stateDir}"
          "TAILSCALE_SOCKET=${toString cfg.socketPath}"
          "TAILSCALE_IMAGE_REPOSITORY=${cfg.image.repository}"
          "TAILSCALE_IMAGE_TAG=${cfg.image.tag}"
          "TAILSCALE_EXTRA_ARGS=\"${tailscaleArgs}\""
          "TAILSCALE_ENV_FILE=/run/secrets/${serviceName}.env"
        ] ++ lib.optionals (cfg.firewallMode != null) [
          "TAILSCALE_FIREWALL_MODE=${cfg.firewallMode}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${toString cfg.stateDir} /var/run/tailscale && chmod 0700 ${toString cfg.stateDir}'"
          "${pkgs.runtimeShell} -c 'install -d -m 0700 /run/secrets && : > /run/secrets/${serviceName}.env && chmod 0600 /run/secrets/${serviceName}.env'"
          "${pkgs.runtimeShell} -c 'test -c /dev/net/tun'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"tailscale: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
        ] ++ lib.optionals (cfg.authKeyFile != null) [
          (runtimeSecretEnv.mkRuntimeSecretEnvExecStartPre {
            name = serviceName;
            secretFile = cfg.authKeyFile;
            envVar = "TS_AUTHKEY";
          })
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
