#!/usr/bin/env bash
# Concatenate rust-example files for AI consumption
# Usage: concat-rust-example.sh <source_dir> <output_file>

set -euo pipefail

src_dir="$1"
output="$2"

# Dynamically find all files in rust-example/ plus specific extra files
mapfile -t rust_example_files < <(find "$src_dir/rust-example" -type f | sort)
extra_files=("$src_dir/.github/workflows/rust-example.yml")

# Generate header with file list
echo "# rust-example" >"$output"
echo "" >>"$output"
echo "Files:" >>"$output"
for file in "${rust_example_files[@]}"; do
  relpath="${file#$src_dir/}"
  echo "- $relpath" >>"$output"
done
for file in "${extra_files[@]}"; do
  if [[ -f "$file" ]]; then
    relpath="${file#$src_dir/}"
    echo "- $relpath" >>"$output"
  fi
done
echo "" >>"$output"
echo "---" >>"$output"
echo "" >>"$output"

# Concatenate each file from rust-example/
for file in "${rust_example_files[@]}"; do
  relpath="${file#$src_dir/}"
  echo "## File: $relpath" >>"$output"
  echo "" >>"$output"
  echo '```' >>"$output"
  cat "$file" >>"$output"
  echo "" >>"$output"
  echo '```' >>"$output"
  echo "" >>"$output"
done

# Concatenate extra files
for file in "${extra_files[@]}"; do
  if [[ -f "$file" ]]; then
    relpath="${file#$src_dir/}"
    echo "## File: $relpath" >>"$output"
    echo "" >>"$output"
    echo '```' >>"$output"
    cat "$file" >>"$output"
    echo "" >>"$output"
    echo '```' >>"$output"
    echo "" >>"$output"
  fi
done
