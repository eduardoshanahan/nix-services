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
        seerrModule = import ./services/seerr/seerr.nix;
      in {
        nixosModules = {
          traefik = traefikModule;
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
          seerr = seerrModule;
        };

        services = {
          traefik = traefikModule;
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
          seerr = seerrModule;
        };
      }
    );
}
