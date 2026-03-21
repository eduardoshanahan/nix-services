{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.dockerSocketProxyCompose;
  serviceName = "docker-socket-proxy";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
in {
  options.services.dockerSocketProxyCompose = {
    enable = lib.mkEnableOption "read-only Docker socket proxy (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "docker-socket-proxy";
      description = "Docker container name.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host listen address mapped to the proxy port.";
    };

    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 2375;
      description = "Host TCP port mapped to proxy port 2375.";
    };

    socketPath = lib.mkOption {
      type = lib.types.str;
      default = "/var/run/docker.sock";
      description = "Host Docker socket path bind-mounted read-only.";
    };

    api = {
      containers = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Allow `/containers` API.";
      };
      events = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Allow `/events` API.";
      };
      images = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Allow `/images` API.";
      };
      info = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Allow `/info` API.";
      };
      networks = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Allow `/networks` API.";
      };
      ping = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Allow `/_ping` API.";
      };
      version = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Allow `/version` API.";
      };
      volumes = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Allow `/volumes` API.";
      };
      post = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Allow mutating POST requests.";
      };
      auth = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Allow `/auth` API.";
      };
      secrets = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Allow `/secrets` API.";
      };
      services = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Allow `/services` API.";
      };
      swarm = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Allow `/swarm` API.";
      };
      tasks = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Allow `/tasks` API.";
      };
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "docker.io/tecnativa/docker-socket-proxy";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "latest";
        description = "Container image tag.";
      };

      allowMutableTag = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Allow mutable tags such as `latest`.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.dockerSocketProxyCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.dockerSocketProxyCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.dockerSocketProxyCompose.image.tag must be pinned (not `latest`) unless services.dockerSocketProxyCompose.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.socketPath;
        message = "services.dockerSocketProxyCompose.socketPath must be an absolute path.";
      }
    ];

    virtualisation.docker.enable = true;
    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "Docker socket proxy (Docker Compose)";
      wantedBy = [ "multi-user.target" ];
      requires = [ "docker.service" ];
      after = [ "docker.service" "network-online.target" ];
      wants = [ "network-online.target" ];
      restartTriggers = [
        config.environment.etc."${serviceName}/docker-compose.yml".source
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = composeDir;
        TimeoutStartSec = 180;

        Environment = [
          "DOCKER_SOCKET_PROXY_CONTAINER_NAME=${cfg.containerName}"
          "DOCKER_SOCKET_PROXY_LISTEN_ADDRESS=${cfg.listenAddress}"
          "DOCKER_SOCKET_PROXY_LISTEN_PORT=${toString cfg.listenPort}"
          "DOCKER_SOCKET_PROXY_SOCKET_PATH=${cfg.socketPath}"
          "DOCKER_SOCKET_PROXY_CONTAINERS=${if cfg.api.containers then "1" else "0"}"
          "DOCKER_SOCKET_PROXY_EVENTS=${if cfg.api.events then "1" else "0"}"
          "DOCKER_SOCKET_PROXY_IMAGES=${if cfg.api.images then "1" else "0"}"
          "DOCKER_SOCKET_PROXY_INFO=${if cfg.api.info then "1" else "0"}"
          "DOCKER_SOCKET_PROXY_NETWORKS=${if cfg.api.networks then "1" else "0"}"
          "DOCKER_SOCKET_PROXY_PING=${if cfg.api.ping then "1" else "0"}"
          "DOCKER_SOCKET_PROXY_VERSION=${if cfg.api.version then "1" else "0"}"
          "DOCKER_SOCKET_PROXY_VOLUMES=${if cfg.api.volumes then "1" else "0"}"
          "DOCKER_SOCKET_PROXY_POST=${if cfg.api.post then "1" else "0"}"
          "DOCKER_SOCKET_PROXY_AUTH=${if cfg.api.auth then "1" else "0"}"
          "DOCKER_SOCKET_PROXY_SECRETS=${if cfg.api.secrets then "1" else "0"}"
          "DOCKER_SOCKET_PROXY_SERVICES=${if cfg.api.services then "1" else "0"}"
          "DOCKER_SOCKET_PROXY_SWARM=${if cfg.api.swarm then "1" else "0"}"
          "DOCKER_SOCKET_PROXY_TASKS=${if cfg.api.tasks then "1" else "0"}"
          "DOCKER_SOCKET_PROXY_IMAGE_REPOSITORY=${cfg.image.repository}"
          "DOCKER_SOCKET_PROXY_IMAGE_TAG=${cfg.image.tag}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'test -S ${cfg.socketPath}'"
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"docker-socket-proxy: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
