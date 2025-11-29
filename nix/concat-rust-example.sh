#!/usr/bin/env bash
# Concatenate rust-example files for AI consumption
# Usage: concat-rust-example.sh <source_dir> <output_file>

set -euo pipefail

src_dir="$1"
output="$2"

# Files to include (relative to source dir)
files=(
  "rust-example/.gitignore"
  "rust-example/Cargo.lock"
  "rust-example/Cargo.toml"
  "rust-example/flake.nix"
  "rust-example/rust-toolchain.toml"
  "rust-example/src/main.rs"
  ".github/workflows/rust-example.yml"
)

# Generate header with file list
echo "# rust-example" > "$output"
echo "" >> "$output"
echo "Files:" >> "$output"
for file in "${files[@]}"; do
  echo "- $file" >> "$output"
done
echo "" >> "$output"
echo "---" >> "$output"
echo "" >> "$output"

# Concatenate each file
for file in "${files[@]}"; do
  filepath="$src_dir/$file"
  if [[ -f "$filepath" ]]; then
    echo "## File: $file" >> "$output"
    echo "" >> "$output"
    echo '```' >> "$output"
    cat "$filepath" >> "$output"
    echo "" >> "$output"
    echo '```' >> "$output"
    echo "" >> "$output"
  fi
done
