#!/usr/bin/env bash
# Concatenate rust-example files for AI consumption
# Usage: concat-rust-example.sh <source_dir> <output_file>

set -euo pipefail

src_dir="$1"
output="$2"

# Dynamically find all files in rust-example/, excluding auto-generated files
mapfile -t rust_example_files < <(find "$src_dir/rust-example" -type f -not -name "Cargo.lock" | sort)
extra_files=("$src_dir/.github/workflows/rust-example.yml")

# Generate header with file list
{
  echo "# rust-example"
  echo ""
  echo "Files:"
  for file in "${rust_example_files[@]}"; do
    relpath="${file#"$src_dir"/}"
    echo "- $relpath"
  done
  for file in "${extra_files[@]}"; do
    if [[ -f "$file" ]]; then
      relpath="${file#"$src_dir"/}"
      echo "- $relpath"
    fi
  done
  echo ""
  echo "---"
  echo ""
} >"$output"

# Concatenate each file from rust-example/
for file in "${rust_example_files[@]}"; do
  relpath="${file#"$src_dir"/}"
  {
    echo "## File: $relpath"
    echo ""
    echo '```'
    cat "$file"
    echo ""
    echo '```'
    echo ""
  } >>"$output"
done

# Concatenate extra files
for file in "${extra_files[@]}"; do
  if [[ -f "$file" ]]; then
    relpath="${file#"$src_dir"/}"
    {
      echo "## File: $relpath"
      echo ""
      echo '```'
      cat "$file"
      echo ""
      echo '```'
      echo ""
    } >>"$output"
  fi
done
