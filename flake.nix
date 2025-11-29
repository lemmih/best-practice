{
  description = "Best practice repository with AI-friendly file concatenation";

  inputs = {
    # Pinned to stable release for reproducible builds
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    # Pinned to specific tag for reproducibility
    flake-utils.url = "github:numtide/flake-utils/v1.0.0";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {inherit system;};

        # Generate GitHub Pages site with concatenated files and index.html
        pages = pkgs.runCommand "pages" {buildInputs = [pkgs.pandoc];} ''
          mkdir -p $out
          bash ${./nix/concat-rust-example.sh} ${./.} $out/rust-example.txt
          bash ${./nix/render-readme.sh} ${pkgs.pandoc}/bin/pandoc ${./.} $out
        '';
      in {
        packages = {
          default = pages;
          pages = pages;
        };

        # Linting and formatting checks
        checks = {
          # Nix linting with statix
          statix = pkgs.runCommand "statix-check" {buildInputs = [pkgs.statix];} ''
            statix check ${./.}
            touch $out
          '';

          # Nix formatting with alejandra
          alejandra = pkgs.runCommand "alejandra-check" {buildInputs = [pkgs.alejandra];} ''
            alejandra --check ${./.}
            touch $out
          '';
        };

        # Development shell with linting and formatting tools
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.statix
            pkgs.alejandra
          ];
        };
      }
    );
}
