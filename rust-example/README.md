# rust-example

A simple Rust project demonstrating best practices from [AGENTS.md](../AGENTS.md).

## Design Guidelines Compliance

### Pinned Dependencies

- **Nix**: Uses `flake.nix` with pinned nixpkgs (`nixos-25.05`) for reproducible builds
- **Rust toolchain**: Pins exact version (`1.91.1`) in `rust-toolchain.toml`
- **CVE database**: Pins `advisory-db` for consistent security audits
- **Lock file**: Commits `Cargo.lock` for deterministic builds

### Automatic Linting

All linters run via `nix flake check`:
- **cargo clippy**: Rust linting with `--deny warnings`
- **statix**: Nix static analysis
- **cargo-audit**: Security vulnerability scanning

### Code Formatting

Formatting enforced in CI:
- **rustfmt**: Rust code formatting
- **taplo**: `Cargo.toml` formatting
- **alejandra**: Nix file formatting

## Usage

```bash
# Enter development shell
nix develop

# Build
nix build

# Run all checks (lint, format, test, audit)
nix flake check
```
