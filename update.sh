#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

files=$(find . -type f -name "*.tmpl.nix")
for file in $files; do
   echo "⚙️  Updating ${file%.tmpl.nix}.nix"
   nix-template-utils <"$file" >"${file%.tmpl.nix}.nix"
done
