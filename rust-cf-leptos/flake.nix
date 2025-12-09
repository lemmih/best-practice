{
  description = "Rust + Leptos + Cloudflare Workers example";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
    crane.url = "github:ipetkov/crane";
    wrangler = {
      url = "github:emrldnix/wrangler";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    alejandra = {
      url = "github:kamadorueda/alejandra";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    rust-overlay,
    crane,
    wrangler,
    alejandra,
    advisory-db,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      overlays = [
        (import rust-overlay)
      ];
      pkgs = import nixpkgs {inherit system overlays;};
      inherit (pkgs) lib;
      fakeHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      rustToolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
      wasmToolchain = rustToolchain.override {
        targets = ["wasm32-unknown-unknown"];
      };
      craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;
      craneLibWasm = (crane.mkLib pkgs).overrideToolchain wasmToolchain;
      # Configure build parallelism to reduce disk/memory pressure in CI
      buildJobsEnv = pkgs.lib.optionalAttrs (builtins.getEnv "CI" != "") {
        CARGO_BUILD_JOBS = "2";
      };
      wranglerPkg = wrangler.packages.${system}.default;
      wasmBindgenVersion = "0.2.106";
      wasmBindgenCli = pkgs.rustPlatform.buildRustPackage {
        pname = "wasm-bindgen-cli";
        version = wasmBindgenVersion;
        src = pkgs.fetchCrate {
          pname = "wasm-bindgen-cli";
          version = wasmBindgenVersion;
          sha256 = "sha256-M6WuGl7EruNopHZbqBpucu4RWz44/MSdv6f0zkYw+44=";
        };
        cargoHash = "sha256-ElDatyOwdKwHg3bNH/1pcxKI7LXkhsotlDPQjiLHBwA=";
      };
      src = craneLib.cleanCargoSource (craneLib.path ./.);
      # Base args for WASM packages (app, client, worker)
      # Note: use worker@0.1.0 to disambiguate from the worker crate dependency
      wasmBaseArgs = {
        inherit src;
        strictDeps = true;
        cargoExtraArgs = "--locked --package app --package client --package worker@0.1.0";
        cargoHash = fakeHash;
        cargoLock = ./Cargo.lock;
        CARGO_BUILD_TARGET = "wasm32-unknown-unknown";
        pname = "wasm-packages";
      };
      clientArgs =
        wasmBaseArgs
        // {
          pname = "client";
          cargoExtraArgs = "--locked --package client";
        };
      workerArgs =
        wasmBaseArgs
        // {
          pname = "worker";
          cargoExtraArgs = "--locked --package worker@0.1.0";
        };
      e2eArgs =
        {
          inherit src;
          strictDeps = true;
          pname = "e2e-tests";
          cargoExtraArgs = "--locked --package e2e-tests";
          cargoHash = fakeHash;
          cargoLock = ./Cargo.lock;
        }
        // buildJobsEnv;
      clientArtifacts = craneLibWasm.buildDepsOnly clientArgs;
      workerArtifacts = craneLibWasm.buildDepsOnly workerArgs;
      e2eTests = craneLib.buildPackage (e2eArgs
        // {
          cargoArtifacts = craneLib.buildDepsOnly e2eArgs;
          doCheck = false;
        });
      clientBundle = craneLibWasm.buildPackage (clientArgs
        // {
          cargoArtifacts = clientArtifacts;
          doCheck = false;
          nativeBuildInputs = [
            wasmBindgenCli
            pkgs.binaryen
          ];
          installPhase = ''
            runHook preInstall
            client_wasm="target/wasm32-unknown-unknown/release/client.wasm"
            out_pkg="$out/assets/pkg"
            mkdir -p "$out_pkg"
            wasm-bindgen "$client_wasm" \
              --out-dir "$out_pkg" \
              --out-name client \
              --target web \
              --no-typescript
            wasm-opt \
              "$out_pkg/client_bg.wasm" \
              -o "$out_pkg/client_bg.wasm" \
              -Oz \
              --enable-bulk-memory \
              --enable-mutable-globals \
              --enable-sign-ext \
              --enable-nontrapping-float-to-int
            runHook postInstall
          '';
        });
      workerBundle = craneLibWasm.buildPackage (workerArgs
        // {
          cargoArtifacts = workerArtifacts;
          doCheck = false;
          nativeBuildInputs = [
            wasmBindgenCli
            pkgs.binaryen
          ];
          installPhase = ''
            runHook preInstall
            worker_wasm="target/wasm32-unknown-unknown/release/worker.wasm"
            out_worker="$out/worker"
            mkdir -p "$out_worker"
            wasm-bindgen "$worker_wasm" \
              --out-dir "$out_worker" \
              --out-name index \
              --target web \
              --no-typescript
            wasm-opt \
              "$out_worker/index_bg.wasm" \
              -o "$out_worker/index_bg.wasm" \
              -Oz \
              --enable-bulk-memory \
              --enable-mutable-globals \
              --enable-sign-ext \
              --enable-nontrapping-float-to-int
            install -Dm644 ${./nix/worker-entrypoint.js} "$out_worker/worker.js"
            runHook postInstall
          '';
        });
      inputCssFile = pkgs.writeText "input.css" ''
        @tailwind base;
        @tailwind components;
        @tailwind utilities;
      '';
      tailwindConfigFile = pkgs.writeText "tailwind.config.js" ''
        /** @type {import('tailwindcss').Config} */
        module.exports = {
          content: [
            "./crates/**/*.rs",
          ],
          theme: {
            extend: {},
          },
          plugins: [],
        }
      '';
      tailwindCss = pkgs.stdenv.mkDerivation {
        pname = "tailwindcss";
        version = "0.1.0";
        src = null;
        dontUnpack = true;
        nativeBuildInputs = [
          pkgs.tailwindcss_4
          pkgs.nodejs_20
        ];
        buildPhase = ''
          runHook preBuild
          # Create a temporary directory with the files we need
          BUILD_DIR="$PWD/build-dir"
          mkdir -p "$BUILD_DIR"
          cd "$BUILD_DIR"

          # Copy input.css and config
          cp ${inputCssFile} input.css
          cp ${tailwindConfigFile} tailwind.config.js

          # Copy crates directory for content scanning
          cp -r ${lib.cleanSource ./crates} crates

          # Build CSS
          tailwindcss -i input.css -o styles.css --minify

          # Move back to original directory and save path
          cd "$OLDPWD"
          echo "$BUILD_DIR/styles.css" > styles-css-path.txt
          runHook postBuild
        '';
        installPhase = ''
          runHook preInstall
          mkdir -p $out
          BUILD_DIR="$(pwd)/build-dir"
          if [ -f "$BUILD_DIR/styles.css" ]; then
            install -Dm644 "$BUILD_DIR/styles.css" $out/styles.css
          else
            echo "Error: styles.css not found in $BUILD_DIR"
            find . -name "styles.css" || true
            exit 1
          fi
          runHook postInstall
        '';
        meta = with lib; {
          description = "Compiled Tailwind CSS";
          platforms = platforms.all;
        };
      };
      website = pkgs.stdenv.mkDerivation {
        pname = "website";
        version = "0.1.0";
        src = null;
        dontUnpack = true;
        installPhase = ''
          runHook preInstall
          mkdir -p $out
          # Copy CSS first to ensure directory is writable
          install -Dm644 ${tailwindCss}/styles.css $out/assets/pkg/styles.css
          # Then copy other assets (this will overwrite if needed, but CSS is already there)
          cp -r ${clientBundle}/assets/* $out/assets/ || true
          cp -r ${workerBundle}/worker $out/
          # Ensure CSS is still there after copying assets
          cp ${tailwindCss}/styles.css $out/assets/pkg/styles.css
          runHook postInstall
        '';
        meta = with lib; {
          description = "Worker bundle with client assets";
          platforms = platforms.all;
        };
      };
      webappPath = website;
      e2eBinPath = e2eTests;
    in {
      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          # Rust toolchain
          cargo
          rustc
          rustfmt
          clippy
          # WASM tools
          wasm-pack
          binaryen
          # Cloudflare tools
          nodejs_20
          wranglerPkg
          # Testing tools
          geckodriver
          # Linting tools
          shellcheck
          statix
          cargo-audit
          # Formatting tools
          alejandra.packages.${system}.default
          leptosfmt
          shfmt
          taplo
        ];

        RUSTFLAGS = "-C target-feature=+simd128";
      };

      packages.e2e-tests = e2eTests;

      packages.website = website;

      apps.e2e-tests = flake-utils.lib.mkApp {
        drv = pkgs.writeShellApplication {
          name = "e2e-tests";
          runtimeInputs = with pkgs; [geckodriver firefox curl wranglerPkg];
          text = ''
            WEBAPP_PATH=${webappPath}
            CURL_BIN=${pkgs.curl}/bin/curl
            WRANGLER_BIN=${wranglerPkg}/bin/wrangler
            E2E_TESTS_BIN=${e2eBinPath}/bin/e2e-tests
            export WEBAPP_PATH CURL_BIN WRANGLER_BIN E2E_TESTS_BIN
            ${./nix/run-e2e-tests.sh}
          '';
        };
      };

      checks = let
        nixSrc = lib.sources.sourceFilesBySuffices ./. [".nix"];
        shellSrc = lib.sources.sourceFilesBySuffices ./nix [".sh"];
      in {
        # Nix formatting with alejandra
        alejandra = pkgs.runCommand "alejandra-check" {} ''
          ${alejandra.packages.${system}.default}/bin/alejandra --check ${nixSrc}
          touch $out
        '';

        # Nix linting with statix
        statix = pkgs.runCommand "statix-check" {buildInputs = [pkgs.statix];} ''
          statix check ${nixSrc}
          touch $out
        '';

        # Shell script linting with shellcheck
        shellcheck = pkgs.runCommand "shellcheck" {buildInputs = [pkgs.shellcheck];} ''
          shellcheck ${shellSrc}/*.sh
          touch $out
        '';

        # Shell script formatting with shfmt
        shfmt = pkgs.runCommand "shfmt-check" {buildInputs = [pkgs.shfmt];} ''
          shfmt -d ${shellSrc}/*.sh
          touch $out
        '';

        # Rust clippy linting (WASM packages only - excludes e2e-tests)
        clippy = craneLibWasm.cargoClippy (wasmBaseArgs
          // {
            pname = "clippy-wasm";
            cargoArtifacts = craneLibWasm.buildDepsOnly wasmBaseArgs;
            cargoClippyExtraArgs = "--package app --package client --package worker@0.1.0 -- --deny warnings";
          });

        # Rust formatting
        rustfmt = craneLib.cargoFmt {inherit src;};

        # Cargo.toml formatting
        taplo = craneLib.taploFmt {inherit src;};

        # Leptos view! macro formatting
        leptosfmt = pkgs.runCommand "leptosfmt-check" {buildInputs = [pkgs.leptosfmt];} ''
          leptosfmt --config-file ${./leptosfmt.toml} --check ${src}/crates
          touch $out
        '';

        # Security audit
        audit = craneLib.cargoAudit {
          inherit advisory-db src;
        };
      };
    });
}
