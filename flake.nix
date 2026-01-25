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

              if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
                repo_root="$(git rev-parse --show-toplevel)"
                hook="$repo_root/.git/hooks/pre-commit"
                config="$repo_root/.pre-commit-config.yaml"

                if [[ -f "$config" && ( ! -e "$hook" || "$config" -nt "$hook" ) ]]; then
                  (cd "$repo_root" && prek install)
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
