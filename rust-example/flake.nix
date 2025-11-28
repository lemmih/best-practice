{
  description = "A simple Rust project example for illustrating best practices";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    crane.url = "github:ipetkov/crane";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      crane,
      rust-overlay,
      flake-utils,
      advisory-db,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay) ];
        };

        # Use rust-toolchain.toml to configure the Rust toolchain
        rustToolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;

        # Source filtering - only include files relevant for Rust builds
        src = craneLib.cleanCargoSource ./.;

        # Common arguments for building the crate
        commonArgs = {
          inherit src;
          strictDeps = true;
        };

        # Build the crate
        crate = craneLib.buildPackage commonArgs;

        # Nix source - only include nix files for nix checks
        nixSrc = pkgs.lib.sources.sourceFilesBySuffices ./. [ ".nix" ];
      in
      {
        checks = {
          # Build the crate as a check
          inherit crate;

          # Run clippy
          clippy = craneLib.cargoClippy (
            commonArgs
            // {
              cargoClippyExtraArgs = "--all-targets -- --deny warnings";
            }
          );

          # Check formatting of Rust code
          rustfmt = craneLib.cargoFmt { inherit src; };

          # Check formatting of Cargo.toml
          taplo = craneLib.taploFmt { inherit src; };

          # Run tests
          test = craneLib.cargoNextest (commonArgs // { cargoNextestExtraArgs = "--no-fail-fast"; });

          # Audit dependencies for security vulnerabilities
          audit = craneLib.cargoAudit {
            inherit advisory-db src;
          };

          # Check Nix formatting with alejandra
          alejandra = pkgs.runCommand "alejandra-check" { buildInputs = [ pkgs.alejandra ]; } ''
            alejandra --check ${nixSrc}
            touch $out
          '';

          # Lint Nix files with statix
          statix = pkgs.runCommand "statix-check" { buildInputs = [ pkgs.statix ]; } ''
            statix check ${nixSrc}
            touch $out
          '';
        };

        packages.default = crate;

        devShells.default = pkgs.mkShell {
          # Include inputs from the package build
          inputsFrom = [ crate ];

          # Additional dev-shell tools
          packages = with pkgs; [
            cargo-audit
            cargo-nextest
            alejandra
            statix
            taplo
          ];
        };
      }
    );
}
