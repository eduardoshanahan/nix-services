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
    flake-utils.lib.eachDefaultSystem (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
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
      in
      {
        nixosModules = {
          traefik = traefikModule;
          pihole = piholeModule;
        };

        services = {
          traefik = traefikModule;
          pihole = piholeModule;
        };
      }
    );
}
