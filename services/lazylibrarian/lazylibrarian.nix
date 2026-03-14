{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.lazylibrarianCompose;
  serviceName = "lazylibrarian";
  composeDir = "/etc/${serviceName}";
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";
  hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$";
  networkRegex = "^[a-zA-Z0-9][a-zA-Z0-9_.-]*$";
  gawkBin = "${pkgs.gawk}/bin/awk";
  integrationConfigPath = "${cfg.dataDir}/config.ini";

  reconcileScript = pkgs.writeShellScript "${serviceName}-reconcile-integrations" ''
    set -euo pipefail

    config_path=${lib.escapeShellArg integrationConfigPath}
    qbittorrent_json=${lib.escapeShellArg (builtins.toJSON cfg.integrations.qbittorrent)}

    log() {
      printf 'lazylibrarian: %s\n' "$*" >&2
    }

    if [[ ! -s "$config_path" ]]; then
      log "config file is missing or empty: $config_path"
      exit 1
    fi

    enabled="$(${pkgs.jq}/bin/jq -r '.enable' <<<"$qbittorrent_json")"
    if [[ "$enabled" != "true" ]]; then
      exit 0
    fi

    host="$(${pkgs.jq}/bin/jq -r '.host' <<<"$qbittorrent_json")"
    port="$(${pkgs.jq}/bin/jq -r '.port' <<<"$qbittorrent_json")"
    use_ssl="$(${pkgs.jq}/bin/jq -r '.useSsl' <<<"$qbittorrent_json")"
    label="$(${pkgs.jq}/bin/jq -r '.label' <<<"$qbittorrent_json")"
    proxy_headers="$(${pkgs.jq}/bin/jq -r '.proxyHeaders' <<<"$qbittorrent_json")"
    proxy_local_header="$(${pkgs.jq}/bin/jq -r '.proxyLocalHeader' <<<"$qbittorrent_json")"

    if [[ "$use_ssl" == "true" && "$host" != http://* && "$host" != https://* ]]; then
      host="https://$host"
    elif [[ "$use_ssl" != "true" && "$host" != http://* && "$host" != https://* ]]; then
      host="http://$host"
    fi

    tmp="$(mktemp -p "$(dirname "$config_path")" ".config.ini.XXXXXX")"

    ${gawkBin} \
      -v torrent_enabled="True" \
      -v host="$host" \
      -v port="$port" \
      -v http_proxy="$( [[ "$proxy_headers" == "true" ]] && printf 'True' || printf 'False' )" \
      -v proxy_local="$proxy_local_header" \
      -v label="$label" '
        function flush_torrent() {
          if (in_torrent && !seen_torrent_enabled) {
            print "tor_downloader_qbittorrent = " torrent_enabled
          }
        }

        function flush_qbittorrent() {
          if (in_qbittorrent) {
            if (!seen_qb_host) print "qbittorrent_host = " host
            if (!seen_qb_port) print "qbittorrent_port = " port
            if (!seen_qb_label) print "qbittorrent_label = " label
          }
        }

        function flush_webserver() {
          if (in_webserver && !seen_http_proxy) {
            print "http_proxy = " http_proxy
          }
        }

        function flush_proxy() {
          if (in_proxy && !seen_proxy_local) {
            print "proxy_local = " proxy_local
          }
        }

        /^\[.*\]$/ {
          flush_torrent()
          flush_qbittorrent()
          flush_webserver()
          flush_proxy()
          in_torrent = ($0 == "[TORRENT]")
          in_qbittorrent = ($0 == "[QBITTORRENT]")
          in_webserver = ($0 == "[WEBSERVER]")
          in_proxy = ($0 == "[PROXY]")
          print
          next
        }

        END {
          flush_torrent()
          flush_qbittorrent()
          flush_webserver()
          flush_proxy()
          if (!seen_torrent_section) {
            print ""
            print "[TORRENT]"
            print "tor_downloader_qbittorrent = " torrent_enabled
          }
          if (!seen_qb_section) {
            print ""
            print "[QBITTORRENT]"
            print "qbittorrent_host = " host
            print "qbittorrent_port = " port
            print "qbittorrent_label = " label
          }
          if (!seen_webserver_section) {
            print ""
            print "[WEBSERVER]"
            print "http_proxy = " http_proxy
          }
          if (!seen_proxy_section) {
            print ""
            print "[PROXY]"
            print "proxy_local = " proxy_local
          }
        }

        {
          if (in_torrent) {
            seen_torrent_section = 1
            if ($0 ~ /^tor_downloader_qbittorrent[[:space:]]*=/) {
              print "tor_downloader_qbittorrent = " torrent_enabled
              seen_torrent_enabled = 1
              next
            }
          }

          if (in_qbittorrent) {
            seen_qb_section = 1
            if ($0 ~ /^qbittorrent_host[[:space:]]*=/) {
              print "qbittorrent_host = " host
              seen_qb_host = 1
              next
            }
            if ($0 ~ /^qbittorrent_port[[:space:]]*=/) {
              print "qbittorrent_port = " port
              seen_qb_port = 1
              next
            }
            if ($0 ~ /^qbittorrent_label[[:space:]]*=/) {
              print "qbittorrent_label = " label
              seen_qb_label = 1
              next
            }
          }

          if (in_webserver) {
            seen_webserver_section = 1
            if ($0 ~ /^http_proxy[[:space:]]*=/) {
              print "http_proxy = " http_proxy
              seen_http_proxy = 1
              next
            }
          }

          if (in_proxy) {
            seen_proxy_section = 1
            if ($0 ~ /^proxy_local[[:space:]]*=/) {
              print "proxy_local = " proxy_local
              seen_proxy_local = 1
              next
            }
          }

          print
        }
      ' \
      "$config_path" > "$tmp"

    chmod 0600 "$tmp"
    mv -f "$tmp" "$config_path"
    log "updated qBittorrent settings in $config_path"
  '';

  qbittorrentIntegrationSubmodule = {
    options = {
      enable = lib.mkEnableOption "LazyLibrarian qBittorrent reconciliation";

      host = lib.mkOption {
        type = lib.types.str;
        description = "qBittorrent hostname or URL to apply in LazyLibrarian.";
        example = "qbittorrent.<homelab-domain>";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 443;
        description = "qBittorrent port to apply in LazyLibrarian.";
      };

      useSsl = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to prefix the qBittorrent host with https:// when no scheme is provided.";
      };

      label = lib.mkOption {
        type = lib.types.str;
        default = "lazylibrarian";
        description = "qBittorrent category/label to apply in LazyLibrarian.";
      };

      proxyHeaders = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable LazyLibrarian's HTTP proxy mode so it respects Traefik's forwarded scheme.";
      };

      proxyLocalHeader = lib.mkOption {
        type = lib.types.str;
        default = "Host";
        description = "Header name to use for LazyLibrarian's PROXY_LOCAL setting.";
      };
    };
  };

  hasDeclarativeIntegrations = cfg.integrations.qbittorrent.enable;
in {
  options.services.lazylibrarianCompose = {
    enable = lib.mkEnableOption "LazyLibrarian service (Docker Compose)";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "lazylibrarian";
      description = "Docker container name.";
    };

    hostname = lib.mkOption {
      type = lib.types.str;
      description = "Hostname used for the Traefik router `Host()` rule.";
    };

    timezone = lib.mkOption {
      type = lib.types.str;
      default = "UTC";
      description = "Timezone passed to the container via `TZ`.";
    };

    network = lib.mkOption {
      type = lib.types.str;
      default = "traefik";
      description = "External Docker network name used by Traefik and downstream services.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/lazylibrarian";
      description = "Persistent host path used for LazyLibrarian config/state.";
    };

    downloadsDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional host path bind-mounted into the container for downloader completed files.";
    };

    downloadsMountPath = lib.mkOption {
      type = lib.types.str;
      default = "/downloads";
      description = "Container path used for the downloader bind mount.";
    };

    booksDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional host path bind-mounted into the container for LazyLibrarian's own library/staging area.";
    };

    booksMountPath = lib.mkOption {
      type = lib.types.str;
      default = "/books";
      description = "Container path used for the LazyLibrarian library/staging bind mount.";
    };

    cwaIngestDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional host path bind-mounted into the container for Calibre-Web-Automated ingest handoff.";
    };

    cwaIngestMountPath = lib.mkOption {
      type = lib.types.str;
      default = "/cwa-book-ingest";
      description = "Container path used for the Calibre-Web-Automated ingest bind mount.";
    };

    uid = lib.mkOption {
      type = lib.types.int;
      default = 1000;
      description = "UID passed to the container as `PUID`.";
    };

    gid = lib.mkOption {
      type = lib.types.int;
      default = 1000;
      description = "GID passed to the container as `PGID`.";
    };

    image = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "lscr.io/linuxserver/lazylibrarian";
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

    tls = lib.mkEnableOption "TLS on the LazyLibrarian Traefik router";

    integrations.qbittorrent = lib.mkOption {
      type = lib.types.submodule qbittorrentIntegrationSubmodule;
      default = {};
      description = "Declarative qBittorrent settings to reconcile in LazyLibrarian before startup.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match hostnameRegex cfg.hostname != null;
        message = "services.lazylibrarianCompose.hostname must be a valid DNS hostname.";
      }
      {
        assertion = builtins.match networkRegex cfg.network != null;
        message = "services.lazylibrarianCompose.network may only contain letters, numbers, `.`, `_`, and `-`.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.repository != null;
        message = "services.lazylibrarianCompose.image.repository must not contain whitespace.";
      }
      {
        assertion = builtins.match "^[^[:space:]]+$" cfg.image.tag != null;
        message = "services.lazylibrarianCompose.image.tag must not contain whitespace.";
      }
      {
        assertion = cfg.image.allowMutableTag || cfg.image.tag != "latest";
        message = "services.lazylibrarianCompose.image.tag must be pinned (not `latest`) unless services.lazylibrarianCompose.image.allowMutableTag = true.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.lazylibrarianCompose.dataDir must be an absolute path.";
      }
      {
        assertion = cfg.downloadsDir == null || lib.hasPrefix "/" cfg.downloadsDir;
        message = "services.lazylibrarianCompose.downloadsDir must be null or an absolute path.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.downloadsMountPath;
        message = "services.lazylibrarianCompose.downloadsMountPath must be an absolute path.";
      }
      {
        assertion = cfg.booksDir == null || lib.hasPrefix "/" cfg.booksDir;
        message = "services.lazylibrarianCompose.booksDir must be null or an absolute path.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.booksMountPath;
        message = "services.lazylibrarianCompose.booksMountPath must be an absolute path.";
      }
      {
        assertion = cfg.cwaIngestDir == null || lib.hasPrefix "/" cfg.cwaIngestDir;
        message = "services.lazylibrarianCompose.cwaIngestDir must be null or an absolute path.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.cwaIngestMountPath;
        message = "services.lazylibrarianCompose.cwaIngestMountPath must be an absolute path.";
      }
      {
        assertion = cfg.uid >= 0;
        message = "services.lazylibrarianCompose.uid must be non-negative.";
      }
      {
        assertion = cfg.gid >= 0;
        message = "services.lazylibrarianCompose.gid must be non-negative.";
      }
      {
        assertion = (!cfg.integrations.qbittorrent.enable) || (builtins.match "^[^[:space:]]+$" cfg.integrations.qbittorrent.host != null);
        message = "services.lazylibrarianCompose.integrations.qbittorrent.host must not contain whitespace when enabled.";
      }
    ];

    virtualisation.docker.enable = true;

    environment.etc."${serviceName}/docker-compose.yml".source = ./docker-compose.yml;

    systemd.services.${serviceName} = {
      description = "LazyLibrarian (Docker Compose)";
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
        WorkingDirectory = composeDir;
        TimeoutStartSec = 900;
        Restart = "on-failure";
        RestartSec = 10;

        Environment = [
          "LAZYLIBRARIAN_CONTAINER_NAME=${cfg.containerName}"
          "LAZYLIBRARIAN_IMAGE_REPOSITORY=${cfg.image.repository}"
          "LAZYLIBRARIAN_IMAGE_TAG=${cfg.image.tag}"
          "LAZYLIBRARIAN_NETWORK=${cfg.network}"
          "LAZYLIBRARIAN_HOST=${cfg.hostname}"
          "LAZYLIBRARIAN_ENTRYPOINTS=${if cfg.tls then "websecure" else "web"}"
          "LAZYLIBRARIAN_TLS=${if cfg.tls then "true" else "false"}"
          "LAZYLIBRARIAN_DATA_DIR=${cfg.dataDir}"
          "LAZYLIBRARIAN_DOWNLOADS_DIR=${if cfg.downloadsDir == null then "" else cfg.downloadsDir}"
          "LAZYLIBRARIAN_DOWNLOADS_MOUNT_PATH=${cfg.downloadsMountPath}"
          "LAZYLIBRARIAN_BOOKS_DIR=${if cfg.booksDir == null then "" else cfg.booksDir}"
          "LAZYLIBRARIAN_BOOKS_MOUNT_PATH=${cfg.booksMountPath}"
          "LAZYLIBRARIAN_CWA_INGEST_DIR=${if cfg.cwaIngestDir == null then "" else cfg.cwaIngestDir}"
          "LAZYLIBRARIAN_CWA_INGEST_MOUNT_PATH=${cfg.cwaIngestMountPath}"
          "LAZYLIBRARIAN_PUID=${toString cfg.uid}"
          "LAZYLIBRARIAN_PGID=${toString cfg.gid}"
          "TZ=${cfg.timezone}"
        ];

        ExecStartPre = [
          "${pkgs.runtimeShell} -c 'mkdir -p ${lib.escapeShellArg cfg.dataDir}${lib.optionalString (cfg.downloadsDir != null) " ${lib.escapeShellArg cfg.downloadsDir}"}${lib.optionalString (cfg.booksDir != null) " ${lib.escapeShellArg cfg.booksDir}"}${lib.optionalString (cfg.cwaIngestDir != null) " ${lib.escapeShellArg cfg.cwaIngestDir}"} && chown ${toString cfg.uid}:${toString cfg.gid} ${lib.escapeShellArg cfg.dataDir} && chmod 0750 ${lib.escapeShellArg cfg.dataDir}${lib.optionalString (cfg.booksDir != null) " && chmod 0775 ${lib.escapeShellArg cfg.booksDir}"}${lib.optionalString (cfg.cwaIngestDir != null) " && chmod 0775 ${lib.escapeShellArg cfg.cwaIngestDir}"}'"
          "${pkgs.runtimeShell} -c 'test -s /etc/ssl/certs/ca-certificates-with-homelab.pem'"
        ] ++ lib.optionals hasDeclarativeIntegrations [
          reconcileScript
        ] ++ [
          "${pkgs.runtimeShell} -c 'test -s ${composeDir}/docker-compose.yml'"
          "${pkgs.runtimeShell} -c 'for i in $(seq 1 30); do ${dockerBin} info >/dev/null 2>&1 && exit 0; sleep 1; done; echo \"lazylibrarian: docker daemon is not ready\" >&2; exit 1'"
          "${pkgs.runtimeShell} -c '${dockerBin} compose config >/dev/null'"
          "${pkgs.runtimeShell} -c '${dockerBin} network inspect ${cfg.network} >/dev/null 2>&1 || ${dockerBin} network create ${cfg.network}'"
        ];

        ExecStart = "${dockerBin} compose up -d";
        ExecStop = "${dockerBin} compose down";
      };
    };
  };
}
