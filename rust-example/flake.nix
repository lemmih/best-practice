{
  description = "A simple Rust project example for illustrating best practices";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    crane.url = "github:ipetkov/crane";
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
      flake-utils,
      advisory-db,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        craneLib = crane.mkLib pkgs;

        # Common arguments for building the crate
        commonArgs = {
          src = craneLib.cleanCargoSource ./.;
          strictDeps = true;
        };

        # Build the crate
        crate = craneLib.buildPackage commonArgs;
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
          rustfmt = craneLib.cargoFmt { src = ./.; };

          # Run tests
          test = craneLib.cargoNextest (commonArgs // { cargoNextestExtraArgs = "--no-fail-fast"; });

          # Audit dependencies for security vulnerabilities
          audit = craneLib.cargoAudit {
            inherit advisory-db;
            src = ./.;
          };

          # Check Nix formatting
          nixfmt = pkgs.runCommand "nixfmt-check" { buildInputs = [ pkgs.nixfmt-rfc-style ]; } ''
            nixfmt --check ${./.}/*.nix
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
            nixfmt-rfc-style
          ];
        };
      }
    );
}
