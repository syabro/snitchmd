#!/usr/bin/env bash
# Installs the latest snitchmd release binary into /usr/local/bin or ~/.local/bin.
# Usage: install.sh [--uninstall]
set -euo pipefail

RELEASES="https://github.com/syabro/snitchmd/releases/latest/download"
LOCAL_BIN="$HOME/.local/bin"
SYSTEM_TARGET="/usr/local/bin/snitchmd"
LOCAL_TARGET="$LOCAL_BIN/snitchmd"

uninstall() {
  for target in "$SYSTEM_TARGET" "$LOCAL_TARGET"; do
    if [[ -e "$target" ]]; then
      rm -f "$target" && echo "Removed $target"
    fi
  done
  echo "Optional cleanup: rm -rf \"\${XDG_CACHE_HOME:-\$HOME/.cache}/snitchmd\""
}

if [[ "${1:-}" == "--uninstall" ]]; then
  uninstall
  exit 0
fi

case "$(uname -s)-$(uname -m)" in
  Darwin-arm64) asset="snitchmd-darwin-arm64" ;;
  Linux-x86_64) asset="snitchmd-linux-x86_64" ;;
  *)
    echo "snitchmd: no prebuilt binary for $(uname -s) $(uname -m); build from source (see README)." >&2
    exit 1
    ;;
esac

if [[ -d /usr/local/bin && -w /usr/local/bin ]]; then
  target="$SYSTEM_TARGET"
else
  mkdir -p "$LOCAL_BIN"
  target="$LOCAL_TARGET"
  case ":$PATH:" in
    *":$LOCAL_BIN:"*) ;;
    *) echo "snitchmd: add $LOCAL_BIN to PATH if snitchmd is not found after install." >&2 ;;
  esac
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
curl -fSL "$RELEASES/$asset" -o "$tmp"
chmod +x "$tmp"
mv "$tmp" "$target"
echo "Installed to $target."
echo "Run: snitchmd https://example.com"
