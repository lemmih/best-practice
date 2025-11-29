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

        # Generate concatenated file for AI agents
        rust-example-concat = pkgs.runCommand "rust-example-concat" {} ''
          mkdir -p $out
          bash ${./nix/concat-rust-example.sh} ${./.} $out/rust-example.txt
        '';
      in {
        packages = {
          default = rust-example-concat;
          rust-example-concat = rust-example-concat;
        };
      }
    );
}
