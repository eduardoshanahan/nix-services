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
        unpollerModule = import ./services/unpoller/unpoller.nix;
        tailscaleModule = import ./services/tailscale/tailscale.nix;
        ghostModule = import ./services/ghost/ghost.nix;
        cadvisorModule = import ./services/cadvisor/cadvisor.nix;
        vikunjaComposeModule = import ./services/vikunja/vikunja.nix;
        owntracksRecorderModule = import ./services/owntracks-recorder/owntracks-recorder.nix;
        homepageDashboardModule = import ./services/homepage/homepage.nix;
        smtpRelayModule = import ./services/smtp-relay/smtp-relay.nix;
        homeAssistantModule = import ./services/home-assistant/home-assistant.nix;
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
          unpoller = unpollerModule;
          tailscale = tailscaleModule;
          ghost = ghostModule;
          cadvisor = cadvisorModule;
          vikunjaCompose = vikunjaComposeModule;
          owntracksRecorder = owntracksRecorderModule;
          homepageDashboard = homepageDashboardModule;
          smtpRelay = smtpRelayModule;
          homeAssistant = homeAssistantModule;
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
          unpoller = unpollerModule;
          tailscale = tailscaleModule;
          ghost = ghostModule;
          cadvisor = cadvisorModule;
          vikunjaCompose = vikunjaComposeModule;
          owntracksRecorder = owntracksRecorderModule;
          homepageDashboard = homepageDashboardModule;
          smtpRelay = smtpRelayModule;
          homeAssistant = homeAssistantModule;
        };
      }
    );
}
