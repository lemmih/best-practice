{
  description = "Best practice repository with AI-friendly file concatenation";

  inputs = {
    # Pinned to stable release for reproducible builds
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    # Pinned to specific tag for reproducibility
    flake-utils.url = "github:numtide/flake-utils/v1.0.0";
    # Sub-project flakes
    rust-example.url = "path:./rust-example";
    rust-cf-leptos.url = "path:./rust-cf-leptos";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    rust-example,
    rust-cf-leptos,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {inherit system;};

        # Generate GitHub Pages site with concatenated files and index.html
        pages = pkgs.runCommand "pages" {buildInputs = [pkgs.pandoc];} ''
          mkdir -p $out
          bash ${./nix/concat-project.sh} ${./.} rust-example $out/rust-example.txt
          bash ${./nix/concat-project.sh} ${./.} rust-cf-leptos $out/rust-cf-leptos.txt
          bash ${./nix/render-readme.sh} ${pkgs.pandoc}/bin/pandoc ${./.} $out
        '';
      in {
        packages = {
          default = pages;
          inherit pages;
        };

        # Linting and formatting checks
        checks =
          {
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

            # Shell script linting with shellcheck
            shellcheck = pkgs.runCommand "shellcheck-check" {buildInputs = [pkgs.shellcheck];} ''
              shellcheck ${./nix/concat-project.sh} ${./nix/render-readme.sh}
              touch $out
            '';

            # Shell script formatting with shfmt
            shfmt = pkgs.runCommand "shfmt-check" {buildInputs = [pkgs.shfmt];} ''
              shfmt -d --indent 2 --case-indent ${./nix/concat-project.sh} ${./nix/render-readme.sh}
              touch $out
            '';

            # GitHub Actions linting with actionlint
            actionlint = pkgs.runCommand "actionlint-check" {buildInputs = [pkgs.actionlint];} ''
              find ${./.github/workflows} -type f \( -name '*.yml' -o -name '*.yaml' \) | xargs -r actionlint
              touch $out
            '';
          }
          # Merge checks from sub-project flakes (prefixed to avoid collisions)
          // (pkgs.lib.mapAttrs' (name: value: pkgs.lib.nameValuePair "rust-example-${name}" value) (rust-example.checks.${system} or {}))
          // (pkgs.lib.mapAttrs' (name: value: pkgs.lib.nameValuePair "rust-cf-leptos-${name}" value) (rust-cf-leptos.checks.${system} or {}));

        # Development shell with linting and formatting tools
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.statix
            pkgs.alejandra
            pkgs.shellcheck
            pkgs.shfmt
            pkgs.actionlint
          ];
        };
      }
    );
}
