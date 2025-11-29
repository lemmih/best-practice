#!/usr/bin/env bash
# Render README.md to index.html for GitHub Pages
# Usage: render-readme.sh <source_dir> <output_dir>

set -euo pipefail

readme="$1/README.md"
output_dir="$2"

# Convert markdown to simple HTML
# - Headers
# - Links
# - Lists
# - Paragraphs

html_content=""
in_list=false

while IFS= read -r line || [[ -n "$line" ]]; do
  # Handle headers
  if [[ "$line" =~ ^#[[:space:]] ]]; then
    if $in_list; then
      html_content+="</ul>"$'\n'
      in_list=false
    fi
    text="${line#\# }"
    html_content+="<h1>$text</h1>"$'\n'
  elif [[ "$line" =~ ^##[[:space:]] ]]; then
    if $in_list; then
      html_content+="</ul>"$'\n'
      in_list=false
    fi
    text="${line#\#\# }"
    html_content+="<h2>$text</h2>"$'\n'
  # Handle list items with links
  elif [[ "$line" =~ ^-[[:space:]] ]]; then
    if ! $in_list; then
      html_content+="<ul>"$'\n'
      in_list=true
    fi
    item="${line#- }"
    # Convert markdown links [text](url) to HTML <a href="url">text</a>
    item=$(echo "$item" | sed -E 's/\[([^]]+)\]\(([^)]+)\)/<a href="\2">\1<\/a>/g')
    html_content+="<li>$item</li>"$'\n'
  # Handle empty lines
  elif [[ -z "$line" ]]; then
    if $in_list; then
      html_content+="</ul>"$'\n'
      in_list=false
    fi
  # Handle regular paragraphs
  else
    if $in_list; then
      html_content+="</ul>"$'\n'
      in_list=false
    fi
    # Convert markdown links in paragraph text
    line=$(echo "$line" | sed -E 's/\[([^]]+)\]\(([^)]+)\)/<a href="\2">\1<\/a>/g')
    html_content+="<p>$line</p>"$'\n'
  fi
done < "$readme"

# Close any open list
if $in_list; then
  html_content+="</ul>"$'\n'
fi

# Generate the HTML file
cat > "$output_dir/index.html" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>best-practice</title>
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
</head>
<body>
$html_content
</body>
</html>
EOF
