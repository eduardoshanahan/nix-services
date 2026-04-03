{
  lib,
  pkgs,
  dockerBin,
}: let
  jqBin = "${pkgs.jq}/bin/jq";
  awkBin = "${pkgs.gawk}/bin/awk";
  catBin = "${pkgs.coreutils}/bin/cat";
  trBin = "${pkgs.coreutils}/bin/tr";

  urlRegex = "^https?://[^[:space:]]+$";

  mkHttpUrlOption = description:
    lib.mkOption {
      type = lib.types.str;
      inherit description;
      example = "https://prowlarr.internal.example";
    };

  qbittorrentSubmodule = {
    options = {
      enable = lib.mkEnableOption "qBittorrent download-client reconciliation";

      host = lib.mkOption {
        type = lib.types.str;
        description = "Downloader hostname or FQDN to apply in the arr app.";
        example = "qbittorrent.internal.example";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 443;
        description = "Downloader port to apply in the arr app.";
      };

      useSsl = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether the arr app should use HTTPS for qBittorrent.";
      };

      urlBase = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Optional qBittorrent URL base/path.";
      };

      username = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "qBittorrent Web UI username to apply in the arr app.";
        example = "media-user";
      };

      passwordFile = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Absolute path to a runtime secret file containing the qBittorrent Web UI password.";
        example = "/run/secrets/qbittorrent-webui-password";
      };

      categoryField = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Servarr qBittorrent field name to reconcile for the app-specific category.";
        example = "movieCategory";
      };

      categoryValue = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "qBittorrent category value to apply for this arr app.";
        example = "radarr";
      };
    };
  };

  prowlarrIndexerSubmodule = {
    options = {
      enable = lib.mkEnableOption "Prowlarr-backed indexer URL reconciliation";

      url = mkHttpUrlOption "Base URL to apply to Prowlarr-backed indexers.";
    };
  };

  importBehaviorSubmodule = {
    options = {
      copyUsingHardlinks = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether imports should use hardlinks instead of moving files out of the downloads path.";
      };
    };
  };

  downloadClientSubmodule = {
    options = {
      enableCompletedDownloadHandling = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether completed-download handling is enabled in the arr app.";
      };

      removeCompletedDownloads = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether the arr app should remove completed items from the downloader after import.";
      };
    };
  };

  prowlarrApplicationSubmodule = {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to reconcile this Prowlarr application.";
      };

      name = lib.mkOption {
        type = lib.types.str;
        description = "Application name as it appears in Prowlarr.";
        example = "Radarr";
      };

      baseUrl = mkHttpUrlOption "Base URL to apply for the downstream app in Prowlarr.";

      prowlarrUrl = mkHttpUrlOption "Prowlarr URL to apply in the downstream app record.";

      configXmlPath = lib.mkOption {
        type = lib.types.str;
        description = "Absolute path to the downstream app config.xml used to read its live API key.";
        example = "/srv/radarr/config.xml";
      };
    };
  };

  writeArrReconcileScript = {
    scriptName,
    serviceName,
    containerName,
    networkName,
    configXmlPath,
    port,
    apiPath,
    importBehavior,
    downloadClient,
    qbittorrent,
    prowlarr,
  }:
    pkgs.writeShellScript scriptName ''
      set -euo pipefail

      container_name=${lib.escapeShellArg containerName}
      network_name=${lib.escapeShellArg networkName}
      config_xml_path=${lib.escapeShellArg configXmlPath}
      service_name=${lib.escapeShellArg serviceName}
      api_path=${lib.escapeShellArg apiPath}
      listen_port=${lib.escapeShellArg (toString port)}
      import_behavior_json=${lib.escapeShellArg (builtins.toJSON importBehavior)}
      download_client_json=${lib.escapeShellArg (builtins.toJSON downloadClient)}
      qbittorrent_json=${lib.escapeShellArg (builtins.toJSON qbittorrent)}
      prowlarr_json=${lib.escapeShellArg (builtins.toJSON prowlarr)}

      log() {
        printf '%s: %s\n' "$service_name" "$*" >&2
      }

      get_container_ip() {
        ${dockerBin} inspect "$container_name" \
          | ${jqBin} -r --arg network "$network_name" '.[0].NetworkSettings.Networks[$network].IPAddress // empty'
      }

      get_api_key() {
        ${awkBin} -F'[<>]' '/ApiKey/{print $3; exit}' "$config_xml_path" 2>/dev/null || true
      }

      api_url() {
        local endpoint="$1"
        printf 'http://127.0.0.1:%s%s%s' "$listen_port" "$api_path" "$endpoint"
      }

      api_get() {
        local endpoint="$1"
        local api_key
        api_key="$(get_api_key)"
        ${dockerBin} exec "$container_name" \
          curl -fsS -H "X-Api-Key: $api_key" "$(api_url "$endpoint")"
      }

      api_put() {
        local endpoint="$1"
        local payload="$2"
        local api_key
        api_key="$(get_api_key)"
        printf '%s' "$payload" \
          | ${dockerBin} exec -i "$container_name" \
              curl -fsS \
                -X PUT \
                -H "Content-Type: application/json" \
                -H "X-Api-Key: $api_key" \
                --data-binary @- \
                "$(api_url "$endpoint")" \
                >/dev/null
      }

      api_post() {
        local endpoint="$1"
        local payload="$2"
        local api_key
        api_key="$(get_api_key)"
        printf '%s' "$payload" \
          | ${dockerBin} exec -i "$container_name" \
              curl -fsS \
                -X POST \
                -H "Content-Type: application/json" \
                -H "X-Api-Key: $api_key" \
                --data-binary @- \
                "$(api_url "$endpoint")" \
                >/dev/null
      }

      wait_for_api() {
        local probe_endpoint="$1"
        local deadline=$((SECONDS + 180))
        local attempt=0
        local api_key=""
        local probe_url=""

        probe_url="$(api_url "$probe_endpoint")"
        log "waiting for API readiness at $probe_url"

        while true; do
          attempt=$((attempt + 1))
          api_key="$(get_api_key)"

          if [[ -z "$api_key" ]]; then
            log "attempt $attempt: config XML missing API key at $config_xml_path"
          elif ! ${dockerBin} inspect "$container_name" >/dev/null 2>&1; then
            log "attempt $attempt: container $container_name is not inspectable yet"
          elif ! ${dockerBin} exec "$container_name" test -x /usr/bin/curl; then
            log "attempt $attempt: curl is not available in container $container_name"
          elif ${dockerBin} exec "$container_name" \
            curl -fsS -H "X-Api-Key: $api_key" "$probe_url" >/dev/null 2>&1; then
            log "API became ready after $attempt attempts"
            if [[ -n "$(get_container_ip)" ]]; then
              log "container IP on network $network_name is $(get_container_ip)"
            fi
            if api_get "$probe_endpoint" >/dev/null 2>&1; then
              return 0
            fi
            log "attempt $attempt: follow-up API read unexpectedly failed"
          else
            log "attempt $attempt: API probe failed for $probe_url"
          fi

          if [[ "$SECONDS" -ge "$deadline" ]]; then
            log "timed out waiting for API readiness at $probe_url"
            return 1
          fi

          sleep 2
        done
      }

      reconcile_qbittorrent() {
        local enabled
        enabled="$(${jqBin} -r '.enable' <<<"$qbittorrent_json")"
        if [[ "$enabled" != "true" ]]; then
          return 0
        fi

        local host port_value use_ssl url_base username password_file password_value category_field category_value
        local clients ids id current payload schema template
        host="$(${jqBin} -r '.host' <<<"$qbittorrent_json")"
        port_value="$(${jqBin} -r '.port' <<<"$qbittorrent_json")"
        use_ssl="$(${jqBin} -r '.useSsl' <<<"$qbittorrent_json")"
        url_base="$(${jqBin} -r '.urlBase' <<<"$qbittorrent_json")"
        username="$(${jqBin} -r '.username' <<<"$qbittorrent_json")"
        password_file="$(${jqBin} -r '.passwordFile' <<<"$qbittorrent_json")"
        category_field="$(${jqBin} -r '.categoryField' <<<"$qbittorrent_json")"
        category_value="$(${jqBin} -r '.categoryValue' <<<"$qbittorrent_json")"

        if [[ ! -r "$password_file" ]]; then
          log "qBittorrent password file is not readable at $password_file"
          return 1
        fi

        password_value="$(${catBin} "$password_file" | ${trBin} -d '\r\n')"

        clients="$(api_get "/downloadclient")"
        ids="$(${jqBin} -r '.[] | select(((.implementation // "") == "QBittorrent") or ((.configContract // "") == "QBittorrentSettings")) | .id' <<<"$clients")"

        if [[ -z "$ids" ]]; then
          schema="$(api_get "/downloadclient/schema")"
          template="$(${jqBin} -c '
            map(select(
              ((.implementation // "") == "QBittorrent")
              or ((.configContract // "") == "QBittorrentSettings")
            ))
            | .[0] // empty' <<<"$schema")"

          if [[ -z "$template" ]]; then
            log "no qBittorrent download-client schema found; skipping create"
            return 0
          fi

          payload="$(${jqBin} -c \
            --arg host "$host" \
            --argjson port "$port_value" \
            --argjson useSsl "$use_ssl" \
            --arg urlBase "$url_base" \
            --arg username "$username" \
            --arg password "$password_value" \
            --arg categoryField "$category_field" \
            --arg categoryValue "$category_value" '
              .name = (if ((.name // "") == "") then "qBittorrent" else .name end)
              | .enable = true
              | .fields |= map(
                  if .name == "host" then .value = $host
                  elif .name == "port" then .value = $port
                  elif .name == "useSsl" then .value = $useSsl
                  elif .name == "urlBase" then .value = $urlBase
                  elif .name == "username" then .value = $username
                  elif .name == "password" then .value = $password
                  elif .name == $categoryField then .value = $categoryValue
                  else .
                  end
                )' <<<"$template")"
          api_post "/downloadclient" "$payload"
          log "created qBittorrent download client"
          return 0
        fi

        while IFS= read -r id; do
          [[ -n "$id" ]] || continue
          current="$(${jqBin} -c --argjson id "$id" '.[] | select(.id == $id)' <<<"$clients")"
          payload="$(${jqBin} -c \
            --arg host "$host" \
            --argjson port "$port_value" \
            --argjson useSsl "$use_ssl" \
            --arg urlBase "$url_base" \
            --arg username "$username" \
            --arg password "$password_value" \
            --arg categoryField "$category_field" \
            --arg categoryValue "$category_value" '
              .fields |= map(
                if .name == "host" then .value = $host
                elif .name == "port" then .value = $port
                elif .name == "useSsl" then .value = $useSsl
                elif .name == "urlBase" then .value = $urlBase
                elif .name == "username" then .value = $username
                elif .name == "password" then .value = $password
                elif .name == $categoryField then .value = $categoryValue
                else .
                end
              )' <<<"$current")"
          api_put "/downloadclient/$id" "$payload"
        done <<<"$ids"
      }

      reconcile_media_management() {
        local copy_using_hardlinks current payload
        copy_using_hardlinks="$(${jqBin} -r '.copyUsingHardlinks' <<<"$import_behavior_json")"

        current="$(api_get "/config/mediamanagement")"
        payload="$(${jqBin} -c \
          --argjson copyUsingHardlinks "$copy_using_hardlinks" '
            .copyUsingHardlinks = $copyUsingHardlinks' <<<"$current")"
        api_put "/config/mediamanagement" "$payload"
      }

      reconcile_download_client_config() {
        local enable_completed_download_handling remove_completed_downloads current payload
        enable_completed_download_handling="$(${jqBin} -r '.enableCompletedDownloadHandling' <<<"$download_client_json")"
        remove_completed_downloads="$(${jqBin} -r '.removeCompletedDownloads' <<<"$download_client_json")"

        current="$(api_get "/config/downloadclient")"
        payload="$(${jqBin} -c \
          --argjson enableCompletedDownloadHandling "$enable_completed_download_handling" \
          --argjson removeCompletedDownloads "$remove_completed_downloads" '
            .enableCompletedDownloadHandling = $enableCompletedDownloadHandling
            | .removeCompletedDownloads = $removeCompletedDownloads' <<<"$current")"
        api_put "/config/downloadclient" "$payload"
      }

      reconcile_prowlarr_indexers() {
        local enabled
        enabled="$(${jqBin} -r '.enable' <<<"$prowlarr_json")"
        if [[ "$enabled" != "true" ]]; then
          return 0
        fi

        local base_url indexers ids id current payload
        base_url="$(${jqBin} -r '.url' <<<"$prowlarr_json")"
        base_url="''${base_url%/}"

        indexers="$(api_get "/indexer")"
        ids="$(${jqBin} -r '.[] | select((.name // "") | endswith(" (Prowlarr)")) | .id' <<<"$indexers")"

        if [[ -z "$ids" ]]; then
          echo "$service_name: no Prowlarr-backed indexers found to reconcile" >&2
          return 0
        fi

        while IFS= read -r id; do
          [[ -n "$id" ]] || continue
          current="$(${jqBin} -c --argjson id "$id" '.[] | select(.id == $id)' <<<"$indexers")"
          payload="$(${jqBin} -c --arg baseUrl "$base_url" '
            .fields |= map(
              if .name == "baseUrl" then
                .value = ($baseUrl + ((.value | tostring | sub("^https?://[^/]+"; ""))))
              else .
              end
            )' <<<"$current")"
          api_put "/indexer/$id" "$payload"
        done <<<"$ids"
      }

      wait_for_api "/downloadclient"
      reconcile_media_management
      reconcile_download_client_config
      reconcile_qbittorrent
      reconcile_prowlarr_indexers
    '';

  writeProwlarrApplicationsScript = {
    scriptName,
    containerName,
    networkName,
    configXmlPath,
    port,
    apiPath,
    applications,
  }:
    pkgs.writeShellScript scriptName ''
      set -euo pipefail

      container_name=${lib.escapeShellArg containerName}
      network_name=${lib.escapeShellArg networkName}
      config_xml_path=${lib.escapeShellArg configXmlPath}
      listen_port=${lib.escapeShellArg (toString port)}
      api_path=${lib.escapeShellArg apiPath}
      applications_json=${lib.escapeShellArg (builtins.toJSON applications)}

      get_container_ip() {
        ${dockerBin} inspect "$container_name" \
          | ${jqBin} -r --arg network "$network_name" '.[0].NetworkSettings.Networks[$network].IPAddress // empty'
      }

      get_api_key() {
        ${awkBin} -F'[<>]' '/ApiKey/{print $3; exit}' "$config_xml_path" 2>/dev/null || true
      }

      get_target_api_key() {
        local target_config="$1"
        ${awkBin} -F'[<>]' '/ApiKey/{print $3; exit}' "$target_config" 2>/dev/null || true
      }

      api_url() {
        local endpoint="$1"
        printf 'http://127.0.0.1:%s%s%s' "$listen_port" "$api_path" "$endpoint"
      }

      api_get() {
        local endpoint="$1"
        local api_key
        api_key="$(get_api_key)"
        ${dockerBin} exec "$container_name" \
          curl -fsS -H "X-Api-Key: $api_key" "$(api_url "$endpoint")"
      }

      api_put() {
        local endpoint="$1"
        local payload="$2"
        local api_key
        api_key="$(get_api_key)"
        printf '%s' "$payload" \
          | ${dockerBin} exec -i "$container_name" \
              curl -fsS \
                -X PUT \
                -H "Content-Type: application/json" \
                -H "X-Api-Key: $api_key" \
                --data-binary @- \
                "$(api_url "$endpoint")" \
                >/dev/null
      }

      api_post() {
        local endpoint="$1"
        local payload="$2"
        local api_key
        api_key="$(get_api_key)"
        printf '%s' "$payload" \
          | ${dockerBin} exec -i "$container_name" \
              curl -fsS \
                -X POST \
                -H "Content-Type: application/json" \
                -H "X-Api-Key: $api_key" \
                --data-binary @- \
                "$(api_url "$endpoint")" \
                >/dev/null
      }

      wait_for_api() {
        local probe_endpoint="$1"
        local deadline=$((SECONDS + 180))

        while true; do
          if [[ -n "$(get_api_key)" ]]; then
            if api_get "$probe_endpoint" >/dev/null 2>&1; then
              return 0
            fi
          fi

          if [[ "$SECONDS" -ge "$deadline" ]]; then
            echo "prowlarr: timed out waiting for API readiness at $probe_endpoint" >&2
            return 1
          fi

          sleep 2
        done
      }

      reconcile_application() {
        local name="$1"
        local base_url="$2"
        local prowlarr_url="$3"
        local target_config="$4"
        local target_api_key current_apps schema implementation id current payload template

        target_api_key="$(get_target_api_key "$target_config")"
        if [[ -z "$target_api_key" ]]; then
          echo "prowlarr: could not read target API key from $target_config for application $name" >&2
          return 0
        fi

        current_apps="$(api_get "/applications")"
        id="$(${jqBin} -r --arg name "$name" '.[] | select(.name == $name) | .id' <<<"$current_apps" | head -n1)"

        if [[ -z "$id" ]]; then
          schema="$(api_get "/applications/schema")"
          implementation="$name"
          template="$(${jqBin} -c \
            --arg implementation "$implementation" \
            --arg configContract "''${implementation}Settings" '
              map(select(
                ((.implementation // "") == $implementation)
                or ((.configContract // "") == $configContract)
              ))
              | .[0] // empty' <<<"$schema")"

          if [[ -z "$template" ]]; then
            echo "prowlarr: no application schema found for $name; skipping create" >&2
            return 0
          fi

          payload="$(${jqBin} -c \
            --arg name "$name" \
            --arg baseUrl "$base_url" \
            --arg prowlarrUrl "$prowlarr_url" \
            --arg apiKey "$target_api_key" '
              .name = $name
              | .enable = true
              | .syncLevel = ((.syncLevel // "") | if . == "" then "fullSync" else . end)
              | .fields |= map(
                  if .name == "baseUrl" then .value = $baseUrl
                  elif .name == "prowlarrUrl" then .value = $prowlarrUrl
                  elif .name == "apiKey" then .value = $apiKey
                  else .
                  end
                )' <<<"$template")"
          api_post "/applications" "$payload"
          echo "prowlarr: created application $name" >&2
          return 0
        fi

        current="$(${jqBin} -c --argjson id "$id" '.[] | select(.id == $id)' <<<"$current_apps")"
        payload="$(${jqBin} -c \
          --arg baseUrl "$base_url" \
          --arg prowlarrUrl "$prowlarr_url" \
          --arg apiKey "$target_api_key" '
            .fields |= map(
              if .name == "baseUrl" then .value = $baseUrl
              elif .name == "prowlarrUrl" then .value = $prowlarrUrl
              elif .name == "apiKey" then .value = $apiKey
              else .
              end
            )' <<<"$current")"
        api_put "/applications/$id" "$payload"
      }

      wait_for_api "/applications"
      while IFS= read -r app; do
        [[ -n "$app" ]] || continue
        if [[ "$(${jqBin} -r '.enable' <<<"$app")" != "true" ]]; then
          continue
        fi

        reconcile_application \
          "$(${jqBin} -r '.name' <<<"$app")" \
          "$(${jqBin} -r '.baseUrl' <<<"$app")" \
          "$(${jqBin} -r '.prowlarrUrl' <<<"$app")" \
          "$(${jqBin} -r '.configXmlPath' <<<"$app")"
      done < <(${jqBin} -c '.[]' <<<"$applications_json")
    '';
in {
  inherit
    downloadClientSubmodule
    importBehaviorSubmodule
    mkHttpUrlOption
    prowlarrApplicationSubmodule
    prowlarrIndexerSubmodule
    qbittorrentSubmodule
    urlRegex
    writeArrReconcileScript
    writeProwlarrApplicationsScript
    ;
}
