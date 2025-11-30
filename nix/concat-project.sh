#!/usr/bin/env bash
# Concatenate project files for AI consumption
# Usage: concat-project.sh <source_dir> <project_name> <output_file>
# Example: concat-project.sh /path/to/repo rust-example /path/to/output.txt

set -euo pipefail

src_dir="$1"
project_name="$2"
output="$3"

# Dynamically find all files in project directory, excluding auto-generated files
# Excludes: *.lock (Cargo.lock, flake.lock, etc.)
mapfile -t project_files < <(find "$src_dir/$project_name" -type f -not -name "*.lock" | sort)
extra_files=("$src_dir/.github/workflows/$project_name.yml")

# Generate header with file list
{
  echo "# $project_name"
  echo ""
  echo "Files:"
  for file in "${project_files[@]}"; do
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

# Concatenate each file from project directory
for file in "${project_files[@]}"; do
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
