{
  description = "Best practice repository with AI-friendly file concatenation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
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
        pages = pkgs.runCommand "pages" {} ''
          mkdir -p $out
          bash ${./nix/concat-rust-example.sh} ${./.} $out/rust-example.txt
          bash ${./nix/render-readme.sh} ${./.} $out
        '';
      in {
        packages = {
          default = pages;
          pages = pages;
        };
      }
    );
}
