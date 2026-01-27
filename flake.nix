{
  description = "Nix development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Nix toolchain
            nix
            nixVersions.latest

            # LSP and language tools
            nixd # Alternative Nix LSP
            nixfmt # Nix formatter

            # Utilities
            jq # JSON processor
          ];

          shellHook = ''
            # Set up Nix environment
            export NIX_CONFIG="experimental-features = nix-command flakes"

            echo "Nix $(nix --version)"
            echo "nixd LSP: $(nixd --version 2>/dev/null || echo 'available')"

            # Check for flake.nix in current directory
            if [ -f "flake.nix" ]; then
              echo "Found flake.nix"
              echo "Checking flake..."
              nix flake check --no-build 2>/dev/null || echo "Run 'check' to see flake issues"
            else
              echo "No flake.nix found. You can initialize with: nix flake init"
            fi

            # Set up direnv if .envrc doesn't exist
            if [ ! -f ".envrc" ] && [ -f "flake.nix" ]; then
              echo "Tip: Create .envrc with 'use flake' for automatic environment loading"
            fi

            # Define helpful aliases
            alias fmt="nixfmt *.nix"
            alias search="nix search nixpkgs"
            alias gc="nix-collect-garbage -d"
            alias store-size="nix-du -s=500MB | head -20"
            alias why-depends="nix why-depends"
            alias derivation="nix derivation show"
            alias path-info="nix path-info -rsSh"
            alias linux-builder="nix run nixpkgs/nixos-25.11#darwin.linux-builder"
          '';

          # Environment variables
          NIX_CONFIG = "experimental-features = nix-command flakes";
        };
      }
    );
}
