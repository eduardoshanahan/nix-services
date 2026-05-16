{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.cadvisorCompose;
  serviceName = "cadvisor";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  portType = lib.types.ints.between 1 65535;
in {
  options.services.cadvisorCompose = {
    enable = lib.mkEnableOption "cAdvisor container metrics exporter (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "cadvisor";
      description = "Docker container name.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Host listen address for the cAdvisor metrics endpoint.";
      example = "127.0.0.1";
    };

    listenPort = lib.mkOption {
      type = portType;
      default = 8081;
      description = "Host TCP port mapped to cAdvisor port 8080.";
    };

    dockerDataRoot = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/docker";
      description = "Host Docker data root bind-mounted into the container.";
    };

    housekeepingInterval = lib.mkOption {
      type = lib.types.str;
      default = "30s";
      description = "cAdvisor housekeeping interval.";
    };

    disableMetrics = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Comma-separated list of metric collectors to disable (passed as
        `--disable_metrics`). Useful on resource-constrained hosts to skip
        collectors that are expensive or unsupported (e.g. `perf_event` on ARM).
        Empty string means all default collectors are enabled.
      '';
      example = "perf_event,referenced_memory,resctrl,cpu_topology,hugetlb";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "gcr.io/cadvisor/cadvisor";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "v0.55.1";
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
        message = "services.cadvisorCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.cadvisorCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.cadvisorCompose.image.tag must be pinned (not `latest`) unless services.cadvisorCompose.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dockerDataRoot;
        message = "services.cadvisorCompose.dockerDataRoot must be an absolute path.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "cAdvisor container metrics exporter (Docker Compose)";
      wantedBy = [ "multi-user.target" ];
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
          "CADVISOR_CONTAINER_NAME=${cfg.containerName}"
          "CADVISOR_LISTEN_ADDRESS=${cfg.listenAddress}"
          "CADVISOR_LISTEN_PORT=${toString cfg.listenPort}"
          "CADVISOR_DOCKER_DATA_ROOT=${cfg.dockerDataRoot}"
          "CADVISOR_HOUSEKEEPING_INTERVAL=${cfg.housekeepingInterval}"
          "CADVISOR_DISABLE_METRICS=${cfg.disableMetrics}"
          "CADVISOR_IMAGE_REPOSITORY=${cfg.image.repository}"
          "CADVISOR_IMAGE_TAG=${cfg.image.tag}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"cadvisor: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
