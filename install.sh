#!/usr/bin/env bash
# Installs the latest snitchmd release binary into /usr/local/bin or ~/.local/bin,
# and copies SKILL.md into existing agent skill directories.
# Usage: install.sh [--uninstall]
set -euo pipefail

RELEASES="https://github.com/syabro/snitchmd/releases/latest/download"
SKILL_URL="https://raw.githubusercontent.com/syabro/snitchmd/master/skills/snitchmd/SKILL.md"
LOCAL_BIN="$HOME/.local/bin"
SYSTEM_TARGET="/usr/local/bin/snitchmd"
LOCAL_TARGET="$LOCAL_BIN/snitchmd"
SKILL_DIRS=(
  "$HOME/.claude/skills"
  "$HOME/.agents/skills"
  "$HOME/.cursor/skills"
)

uninstall() {
  for target in "$SYSTEM_TARGET" "$LOCAL_TARGET"; do
    if [[ -e "$target" ]]; then
      rm -f "$target" && echo "Removed $target"
    fi
  done
  for dir in "${SKILL_DIRS[@]}"; do
    if [[ -d "$dir/snitchmd" ]]; then
      rm -rf "$dir/snitchmd" && echo "Removed $dir/snitchmd"
    fi
  done
  echo "Optional cleanup: rm -rf \"\${XDG_CACHE_HOME:-\$HOME/.cache}/snitchmd\""
}

install_skill() {
  local existing=()
  for dir in "${SKILL_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
      existing+=("$dir")
    fi
  done
  if [[ ${#existing[@]} -eq 0 ]]; then
    return 0
  fi

  local skill_tmp
  skill_tmp="$(mktemp)"
  if curl -fsSL "$SKILL_URL" -o "$skill_tmp"; then
    for dir in "${existing[@]}"; do
      mkdir -p "$dir/snitchmd"
      cp "$skill_tmp" "$dir/snitchmd/SKILL.md"
      echo "Installed skill to $dir/snitchmd/SKILL.md"
    done
  else
    echo "snitchmd: skipped skill install (failed to download SKILL.md)." >&2
  fi
  rm -f "$skill_tmp"
}

if [[ "${1:-}" == "--uninstall" ]]; then
  uninstall
  exit 0
fi

case "$(uname -s)-$(uname -m)" in
  Darwin-arm64) asset="snitchmd-darwin-arm64" ;;
  Darwin-x86_64) asset="snitchmd-darwin-x86_64" ;;
  Linux-x86_64) asset="snitchmd-linux-x86_64" ;;
  Linux-aarch64) asset="snitchmd-linux-arm64" ;;
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
install_skill
echo "Run: snitchmd https://example.com"
