#!/usr/bin/env bash
# Render README.md to index.html for GitHub Pages using pandoc
# Usage: render-readme.sh <pandoc_path> <source_dir> <output_dir>

set -euo pipefail

pandoc="$1"
readme="$2/README.md"
output_dir="$3"

"$pandoc" "$readme" \
  --standalone \
  --metadata title="best-practice" \
  --css="" \
  --output "$output_dir/index.html" \
  --include-in-header=<(cat << 'STYLE'
<style>
  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
    line-height: 1.6;
    max-width: 800px;
    margin: 0 auto;
    padding: 2rem;
    color: #333;
  }
  h1, h2 {
    border-bottom: 1px solid #eee;
    padding-bottom: 0.3em;
  }
  a {
    color: #0366d6;
    text-decoration: none;
  }
  a:hover {
    text-decoration: underline;
  }
  ul {
    padding-left: 2em;
  }
  li {
    margin: 0.5em 0;
  }
</style>
STYLE
)
