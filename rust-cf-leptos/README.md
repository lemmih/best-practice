# rust-cf-leptos

A Rust web application using Leptos for server-side rendering, deployed to Cloudflare Workers. Demonstrates best practices from [AGENTS.md](../AGENTS.md).

## Architecture

```
crates/
  app/      # Shared Leptos components (isomorphic)
  client/   # Client-side hydration (compiles to WASM)
  worker/   # Cloudflare Worker server (compiles to WASM)
e2e-tests/  # End-to-end tests with Selenium/Firefox
```

Both the server (worker) and client compile to WebAssembly. The worker handles SSR and serves static assets, while the client hydrates the page for interactivity.

## Design Guidelines Compliance

### Pinned Dependencies

- **Nix**: Uses `flake.nix` with pinned nixpkgs (`nixos-25.05`) for reproducible builds
- **Rust toolchain**: Pins exact version (`1.91.0`) in `rust-toolchain.toml`
- **CVE database**: Pins `advisory-db` for consistent security audits
- **Lock file**: Commits `Cargo.lock` for deterministic builds
- **wasm-bindgen**: Pins exact version (`0.2.105`) to match CLI and library

### Automatic Linting

All linters run via `nix flake check`:
- **cargo clippy**: Rust linting with `--deny warnings`
- **statix**: Nix static analysis
- **shellcheck**: Shell script linting
- **cargo-audit**: Security vulnerability scanning

### Code Formatting

Formatting enforced in CI:
- **rustfmt**: Rust code formatting
- **taplo**: `Cargo.toml` formatting
- **alejandra**: Nix file formatting
- **shfmt**: Shell script formatting

## Usage

```bash
# Enter development shell
nix develop

# Build the website (worker + client bundles)
nix build .#website

# Run all checks (lint, format, audit)
nix flake check

# Run end-to-end tests
nix run .#e2e-tests

# Deploy to Cloudflare (requires wrangler auth)
wrangler deploy
```

## Development

The `nix develop` shell provides all tools needed for local development:

```bash
# Start local dev server
wrangler dev

# Run clippy manually
cargo clippy --all-targets -- -D warnings

# Format code
cargo fmt
alejandra .
shfmt -w nix/*.sh
```
