{
  description = "Best practice repository with AI-friendly file concatenation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {inherit system;};

        # Generate concatenated file for AI agents
        rust-example-concat = pkgs.runCommand "rust-example-concat" {} ''
          mkdir -p $out

          # Source directory
          src="${./rust-example}"

          # Output file
          output="$out/rust-example.txt"

          # Generate header with file list
          echo "# rust-example" > "$output"
          echo "" >> "$output"
          echo "Files:" >> "$output"
          find "$src" -type f | sort | while read -r file; do
            relpath="''${file#$src/}"
            echo "- $relpath" >> "$output"
          done
          echo "" >> "$output"
          echo "---" >> "$output"
          echo "" >> "$output"

          # Find all files and concatenate them
          find "$src" -type f | sort | while read -r file; do
            # Get relative path
            relpath="''${file#$src/}"

            echo "## File: $relpath" >> "$output"
            echo "" >> "$output"
            echo '```' >> "$output"
            cat "$file" >> "$output"
            echo "" >> "$output"
            echo '```' >> "$output"
            echo "" >> "$output"
          done
        '';
      in {
        packages = {
          default = rust-example-concat;
          rust-example-concat = rust-example-concat;
        };
      }
    );
}
