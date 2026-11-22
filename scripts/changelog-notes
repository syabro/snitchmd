#!/usr/bin/env bash
# Print the CHANGELOG.md section body for a given version (no heading).
# Usage: scripts/changelog-notes 0.2.1
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: scripts/changelog-notes VERSION" >&2
  exit 1
fi

version="$1"
awk -v ver="$version" '
  $0 ~ "^## \\[" ver "\\]" { grab = 1; next }
  grab && /^## \[/         { exit }
  grab && !seen && /^$/    { next }      # skip leading blank lines
  grab                     { seen = 1; print }
' CHANGELOG.md
