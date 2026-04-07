{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.mysqlExporterCompose;
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};
  serviceName = "mysql-exporter";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  runtimeDir = "/run/${serviceName}";
  runtimeMyCnfPath = "${runtimeDir}/${serviceName}.my.cnf";
  runtimeMyCnfScript = pkgs.writeShellScript "${serviceName}-runtime-my-cnf" ''
    set -euo pipefail
    umask 0077

    secret_file=${lib.escapeShellArg (toString cfg.mysql.passwordFile)}
    mycnf_file=${lib.escapeShellArg runtimeMyCnfPath}

    install -d -m 0755 ${runtimeDir}

    if [[ -e "$mycnf_file" && ! -f "$mycnf_file" ]]; then
      rm -rf "$mycnf_file"
    fi

    tmp="$(mktemp -p ${runtimeDir} ".${serviceName}.my.cnf.XXXXXX")"

    if [[ ! -s "$secret_file" ]]; then
      echo "mysql-exporter: missing or empty password file: $secret_file" >&2
      exit 1
    fi

    mysql_password="$(tr -d '\r\n' < "$secret_file")"
    if [[ -z "$mysql_password" ]]; then
      echo "mysql-exporter: password file is empty after trimming" >&2
      exit 1
    fi

    escape_cnf() {
      local value="$1"
      value="''${value//\\/\\\\}"
      value="''${value//\"/\\\"}"
      printf '%s' "$value"
    }

    {
      printf '[client]\n'
      printf 'user="%s"\n' "${cfg.mysql.username}"
      printf 'password="%s"\n' "$(escape_cnf "$mysql_password")"
      printf 'host="%s"\n' "${cfg.mysql.host}"
      printf 'port=%s\n' "${toString cfg.mysql.port}"
    } > "$tmp"

    chmod 0644 "$tmp"
    mv -f "$tmp" "$mycnf_file"
  '';
in {
  options.services.mysqlExporterCompose = {
    enable = lib.mkEnableOption "MySQL Prometheus exporter (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "mysql-exporter";
      description = "Docker container name.";
    };

    network = lib.mkOption {
      type = lib.types.str;
      default = "traefik";
      description = "External Docker network name used by Traefik and downstream services.";
    };

    timezone = lib.mkOption {
      type = lib.types.str;
      default = "UTC";
      description = "Timezone passed to the container via `TZ`.";
    };

    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 9104;
      description = "Host TCP port mapped to exporter port 9104.";
    };

    mysql = {
      host = lib.mkOption {
        type = lib.types.str;
        description = "MySQL hostname reachable from exporter container.";
        example = "mysql.internal.example";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 3306;
        description = "MySQL TCP port.";
      };

      username = lib.mkOption {
        type = lib.types.str;
        description = "MySQL username used by exporter.";
        example = "ghost";
      };

      passwordFile = runtimeSecrets.mkSecretFileOption {
        description = "Absolute path to a runtime-provisioned file containing the MySQL password.";
        example = "/run/secrets/ghost-db-password";
      };
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "prom/mysqld-exporter";
        description = "Container image repository.";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "v0.19.0";
        description = "Container image tag.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.mysql.passwordFile != null;
        message = "services.mysqlExporterCompose.mysql.passwordFile must be set when enabling mysql exporter.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "MySQL Prometheus exporter (Docker Compose)";

      wantedBy = ["multi-user.target"];
      after = ["docker.service" "network-online.target"];
      wants = ["network-online.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = composeDir;

        Environment = [
          "MYSQL_EXPORTER_CONTAINER_NAME=${cfg.containerName}"
          "MYSQL_EXPORTER_NETWORK=${cfg.network}"
          "MYSQL_EXPORTER_PORT=${toString cfg.listenPort}"
          "MYSQL_EXPORTER_MYSQL_HOST=${cfg.mysql.host}"
          "MYSQL_EXPORTER_MYSQL_PORT=${toString cfg.mysql.port}"
          "MYSQL_EXPORTER_MYCNF_PATH=${runtimeMyCnfPath}"
          "MYSQL_EXPORTER_IMAGE_REPOSITORY=${cfg.image.repository}"
          "MYSQL_EXPORTER_IMAGE_TAG=${cfg.image.tag}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
          runtimeMyCnfScript
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
