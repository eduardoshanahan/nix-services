{
  description = "nix-services dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
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

              # --- Service authoring ---
              docker
              docker-compose

              # --- Optional helpers ---
              prek
              just
            ];

            shellHook = ''
              echo "Entering nix-services dev shell"
              echo "Architecture: ${system}"
            '';
          };
        })
    // (
      let
        traefikModule = import ./services/traefik/traefik.nix;
      in
      {
        nixosModules = {
          traefik = traefikModule;
        };

        services = {
          traefik = traefikModule;
        };
      }
    );
}
