#!/usr/bin/env bash
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/syabro/snitchmd/master"
LOCAL_BIN="$HOME/.local/bin"
LOCAL_TARGET="$LOCAL_BIN/snitchmd"
SYSTEM_TARGET="/usr/local/bin/snitchmd"

uninstall() {
  for target in "$SYSTEM_TARGET" "$LOCAL_TARGET"; do
    if [[ -e "$target" ]]; then
      rm -f "$target" && echo "Removed $target"
    fi
  done
  cat <<CLEANUP

Optional cleanup:
  docker rmi syabro/snitchmd
  rm -rf "\${XDG_CACHE_HOME:-\$HOME/.cache}/snitchmd"
CLEANUP
}

if [[ "${1:-}" == "--uninstall" ]]; then
  uninstall
  exit 0
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "snitchmd: Docker is not installed or not in PATH." >&2
  exit 1
fi

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

curl -fsSL "$REPO_RAW/scripts/snitchmd" -o "$target"
chmod +x "$target"
echo "Installed to $target."
echo "Run: snitchmd https://example.com"
