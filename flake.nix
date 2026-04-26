{
  description = "nix-services dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
      sessionPreflight = pkgs.writeShellApplication {
        name = "session-preflight";
        runtimeInputs = [pkgs.ripgrep];
        text = ''
          set -euo pipefail

          repo_root="$PWD"
          kb_root="''${HHLAB_WIKI_DIR:-$repo_root/../hhlab-wiki}"

          required_repo_docs=(
            "$repo_root/README.md"
            "$repo_root/DOCUMENTATION_INDEX.md"
            "$repo_root/docs/policy/repository_boundary_and_responsibility_guidelines.md"
          )

          required_kb_docs=(
            "$kb_root/README.md"
            "$kb_root/indexes/by-repo.md"
            "$kb_root/indexes/by-topic.md"
            "$kb_root/indexes/by-date.md"
          )

          echo "nix-services session pre-flight"
          echo "repo_root=$repo_root"
          echo "kb_root=$kb_root"
          echo

          missing=0
          for file in "''${required_repo_docs[@]}"; do
            if [ -f "$file" ]; then
              echo "OK   $file"
            else
              echo "MISS $file" >&2
              missing=1
            fi
          done

          for file in "''${required_kb_docs[@]}"; do
            if [ -f "$file" ]; then
              echo "OK   $file"
            else
              echo "MISS $file" >&2
              missing=1
            fi
          done

          if [ "$missing" -ne 0 ]; then
            cat >&2 <<'EOF'

Pre-flight failed: required docs are missing.
Set HHLAB_WIKI_DIR if your private wiki lives outside ../hhlab-wiki.
EOF
            exit 1
          fi

          echo
          echo "Relevant KB entries for nix-services:"
          rg -n "nix-services|nix-services-private" "$kb_root/indexes/by-repo.md" || true

          echo
          cat <<'EOF'
Next required steps:
1. Read the linked KB records.
2. Summarize grounded assumptions and open uncertainties.
3. Validate plan against decisions and anti-patterns before implementation.
EOF
        '';
      };
    in {
      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          # --- Core tooling ---
          git
          gitleaks
          zstd

          # --- Nix hygiene ---
          alejandra
          statix
          deadnix
          markdownlint-cli
          markdownlint-cli2

          # --- Service authoring ---
          docker
          docker-compose

          # --- Optional helpers ---
          prek
        ];

        shellHook = ''
          echo "Entering nix-services dev shell"
          echo "Architecture: ${system}"

          # Auto-install (and optionally run) prek hooks when entering the dev shell.
          # Opt out with `SKIP_PREK=1 nix develop`.
          if [ -z "''${SKIP_PREK:-}" ] && git rev-parse --is-inside-work-tree >/dev/null 2>&1 && command -v prek >/dev/null 2>&1; then
            repo_root="$(git rev-parse --show-toplevel)"

            if [ -f "$repo_root/.pre-commit-config.yaml" ]; then
              if [ -z "''${NIX_SERVICES_PREK_DONE:-}" ]; then
                export NIX_SERVICES_PREK_DONE=1

                echo "prek: installing git hooks"
                (cd "$repo_root" && prek install --install-hooks 2>/dev/null) || (cd "$repo_root" && prek install) || true

                # Run once on entry; disable with SKIP_PREK_RUN=1.
                if [ -z "''${SKIP_PREK_RUN:-}" ]; then
                  echo "prek: running hooks (all files)"
                  (cd "$repo_root" && prek run --all-files) || true
                fi
              fi
            fi
          fi
        '';
      };

      packages.session-preflight = sessionPreflight;

      apps.session-preflight = {
        type = "app";
        program = "${sessionPreflight}/bin/session-preflight";
      };
    })
    // (
      let
        traefikModule = import ./services/traefik/traefik.nix;
        piholeModule = import ./services/pihole/pihole.nix;
        piholeSyncModule = import ./services/pihole-sync/pihole-sync.nix;
        piholeExporterModule = import ./services/pihole-exporter/pihole-exporter.nix;
        alertmanagerModule = import ./services/alertmanager/alertmanager.nix;
        diagramsNetModule = import ./services/diagrams-net/diagrams-net.nix;
        excalidrawModule = import ./services/excalidraw/excalidraw.nix;
        uptimeKumaModule = import ./services/uptime-kuma/uptime-kuma.nix;
        grafanaModule = import ./services/grafana/grafana.nix;
        prometheusModule = import ./services/prometheus/prometheus.nix;
        lokiModule = import ./services/loki/loki.nix;
        promtailModule = import ./services/promtail/promtail.nix;
        snmpExporterModule = import ./services/snmp-exporter/snmp-exporter.nix;
        postgresExporterModule = import ./services/postgres-exporter/postgres-exporter.nix;
        redisExporterModule = import ./services/redis-exporter/redis-exporter.nix;
        mysqlExporterModule = import ./services/mysql-exporter/mysql-exporter.nix;
        mongodbExporterModule = import ./services/mongodb-exporter/mongodb-exporter.nix;
        unpollerModule = import ./services/unpoller/unpoller.nix;
        tailscaleModule = import ./services/tailscale/tailscale.nix;
        mysqlComposeModule = import ./services/mysql/mysql.nix;
        ghostModule = import ./services/ghost/ghost.nix;
        cadvisorModule = import ./services/cadvisor/cadvisor.nix;
        vikunjaComposeModule = import ./services/vikunja/vikunja.nix;
        owntracksRecorderModule = import ./services/owntracks-recorder/owntracks-recorder.nix;
        homepageDashboardModule = import ./services/homepage/homepage.nix;
        smtpRelayModule = import ./services/smtp-relay/smtp-relay.nix;
        homeAssistantModule = import ./services/home-assistant/home-assistant.nix;
        authentikComposeModule = import ./services/authentik/authentik.nix;
        timeTaggerComposeModule = import ./services/timetagger/timetagger.nix;
        traggoComposeModule = import ./services/traggo/traggo.nix;
        karakeepComposeModule = import ./services/karakeep/karakeep.nix;
        woodpeckerComposeModule = import ./services/woodpecker/woodpecker.nix;
        dozzleComposeModule = import ./services/dozzle/dozzle.nix;
        dockerSocketProxyComposeModule = import ./services/docker-socket-proxy/docker-socket-proxy.nix;
        fossflowComposeModule = import ./services/fossflow/fossflow.nix;
        searxngComposeModule = import ./services/searxng/searxng.nix;
        d2ComposeModule = import ./services/d2/d2.nix;
        n8nComposeModule = import ./services/n8n/n8n.nix;
        homarrModule = import ./services/homarr/homarr.nix;
        seerrModule = import ./services/seerr/seerr.nix;
        ankiSyncComposeModule = import ./services/anki-sync/anki-sync.nix;
        calibreWebAutomatedComposeModule = import ./services/calibre-web-automated/calibre-web-automated.nix;
        lazylibrarianComposeModule = import ./services/lazylibrarian/lazylibrarian.nix;
        lidarrComposeModule = import ./services/lidarr/lidarr.nix;
        radarrComposeModule = import ./services/radarr/radarr.nix;
        prowlarrComposeModule = import ./services/prowlarr/prowlarr.nix;
        sonarrComposeModule = import ./services/sonarr/sonarr.nix;
        umamiComposeModule = import ./services/umami/umami.nix;
        daysuntilComposeModule = import ./services/daysuntil/daysuntil.nix;
      in {
        nixosModules = {
          traefikCompose = traefikModule;
          pihole = piholeModule;
          piholeSync = piholeSyncModule;
          piholeExporter = piholeExporterModule;
          alertmanager = alertmanagerModule;
          diagramsNet = diagramsNetModule;
          excalidraw = excalidrawModule;
          uptimeKuma = uptimeKumaModule;
          grafana = grafanaModule;
          prometheus = prometheusModule;
          loki = lokiModule;
          promtail = promtailModule;
          snmpExporter = snmpExporterModule;
          postgresExporterCompose = postgresExporterModule;
          redisExporterCompose = redisExporterModule;
          mysqlExporterCompose = mysqlExporterModule;
          mongodbExporterCompose = mongodbExporterModule;
          unpoller = unpollerModule;
          tailscale = tailscaleModule;
          mysqlCompose = mysqlComposeModule;
          ghost = ghostModule;
          cadvisor = cadvisorModule;
          vikunjaCompose = vikunjaComposeModule;
          owntracksRecorder = owntracksRecorderModule;
          homepageDashboard = homepageDashboardModule;
          smtpRelay = smtpRelayModule;
          homeAssistant = homeAssistantModule;
          authentikCompose = authentikComposeModule;
          timeTaggerCompose = timeTaggerComposeModule;
          traggoCompose = traggoComposeModule;
          karakeepCompose = karakeepComposeModule;
          woodpeckerCompose = woodpeckerComposeModule;
          dozzleCompose = dozzleComposeModule;
          dockerSocketProxyCompose = dockerSocketProxyComposeModule;
          fossflowCompose = fossflowComposeModule;
          searxngCompose = searxngComposeModule;
          d2Compose = d2ComposeModule;
          n8nCompose = n8nComposeModule;
          homarr = homarrModule;
          seerr = seerrModule;
          ankiSyncCompose = ankiSyncComposeModule;
          calibreWebAutomatedCompose = calibreWebAutomatedComposeModule;
          lazylibrarianCompose = lazylibrarianComposeModule;
          lidarrCompose = lidarrComposeModule;
          radarrCompose = radarrComposeModule;
          prowlarrCompose = prowlarrComposeModule;
          sonarrCompose = sonarrComposeModule;
          umamiCompose = umamiComposeModule;
          daysuntilCompose = daysuntilComposeModule;
        };

        services = {
          traefikCompose = traefikModule;
          pihole = piholeModule;
          piholeSync = piholeSyncModule;
          piholeExporter = piholeExporterModule;
          alertmanager = alertmanagerModule;
          diagramsNet = diagramsNetModule;
          excalidraw = excalidrawModule;
          uptimeKuma = uptimeKumaModule;
          grafana = grafanaModule;
          prometheus = prometheusModule;
          loki = lokiModule;
          promtail = promtailModule;
          snmpExporter = snmpExporterModule;
          postgresExporterCompose = postgresExporterModule;
          redisExporterCompose = redisExporterModule;
          mysqlExporterCompose = mysqlExporterModule;
          mongodbExporterCompose = mongodbExporterModule;
          unpoller = unpollerModule;
          tailscale = tailscaleModule;
          mysqlCompose = mysqlComposeModule;
          ghost = ghostModule;
          cadvisor = cadvisorModule;
          vikunjaCompose = vikunjaComposeModule;
          owntracksRecorder = owntracksRecorderModule;
          homepageDashboard = homepageDashboardModule;
          smtpRelay = smtpRelayModule;
          homeAssistant = homeAssistantModule;
          authentikCompose = authentikComposeModule;
          timeTaggerCompose = timeTaggerComposeModule;
          traggoCompose = traggoComposeModule;
          karakeepCompose = karakeepComposeModule;
          woodpeckerCompose = woodpeckerComposeModule;
          dozzleCompose = dozzleComposeModule;
          dockerSocketProxyCompose = dockerSocketProxyComposeModule;
          fossflowCompose = fossflowComposeModule;
          searxngCompose = searxngComposeModule;
          d2Compose = d2ComposeModule;
          n8nCompose = n8nComposeModule;
          homarr = homarrModule;
          seerr = seerrModule;
          ankiSyncCompose = ankiSyncComposeModule;
          calibreWebAutomatedCompose = calibreWebAutomatedComposeModule;
          lazylibrarianCompose = lazylibrarianComposeModule;
          lidarrCompose = lidarrComposeModule;
          radarrCompose = radarrComposeModule;
          prowlarrCompose = prowlarrComposeModule;
          sonarrCompose = sonarrComposeModule;
          umamiCompose = umamiComposeModule;
          daysuntilCompose = daysuntilComposeModule;
        };
      }
    );
}
