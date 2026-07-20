#!/usr/bin/env bash
set -euo pipefail

REPO="Fenomen-Alex/oss-hunter"
BRANCH="main"

echo "=== OSS Hunter Installer ==="
echo ""

# Download a single file from the repo without cloning
fetch() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  curl -sL "https://raw.githubusercontent.com/$REPO/$BRANCH/$src" -o "$dst"
}

# Temporary directory for command files
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

fetch ".opencode/plugins/oss-hunter.md"       "$TMPDIR/opencode/oss-hunter.md"
fetch ".claude-plugin/commands/oss-hunter.md"  "$TMPDIR/claude/oss-hunter.md"
fetch ".codex-plugin/oss-hunter.md"            "$TMPDIR/codex/oss-hunter.md"
fetch ".kimi-plugin/commands/oss-hunter.md"    "$TMPDIR/kimi/oss-hunter.md"

# Detect agents
INSTALLED=()
command -v opencode &>/dev/null && INSTALLED+=("opencode")
command -v claude &>/dev/null   && INSTALLED+=("claude")
command -v codex &>/dev/null    && INSTALLED+=("codex")

if [ ${#INSTALLED[@]} -eq 0 ]; then
  echo "No supported coding agents detected on PATH."
  echo "Supported: OpenCode, Claude Code, Codex CLI, Kimi Code"
  echo ""
  echo "Install one of those first, then re-run:"
  echo "  curl -sL https://raw.githubusercontent.com/$REPO/$BRANCH/install.sh | bash"
  exit 1
fi

echo "Detected agents: ${INSTALLED[*]}"
echo ""

for agent in "${INSTALLED[@]}"; do
  case "$agent" in
    opencode)
      CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
      PLUGIN_DIR="$CONFIG_DIR/plugins"
      mkdir -p "$PLUGIN_DIR"
      cp "$TMPDIR/opencode/oss-hunter.md" "$PLUGIN_DIR/"
      echo "  [OK] OpenCode: copied to $PLUGIN_DIR/oss-hunter.md"
      echo "       Add to opencode.json:"
      echo '       "plugin": ["oss-hunter@git+https://github.com/Fenomen-Alex/oss-hunter.git"]'
      echo ""
      ;;
    claude)
      COMMAND_DIR="${HOME}/.claude/commands"
      mkdir -p "$COMMAND_DIR"
      cp "$TMPDIR/claude/oss-hunter.md" "$COMMAND_DIR/"
      echo "  [OK] Claude Code: copied to $COMMAND_DIR/oss-hunter.md"
      echo ""
      ;;
    codex)
      COMMAND_DIR="${HOME}/.codex/commands"
      mkdir -p "$COMMAND_DIR"
      cp "$TMPDIR/codex/oss-hunter.md" "$COMMAND_DIR/"
      echo "  [OK] Codex CLI: copied to $COMMAND_DIR/oss-hunter.md"
      echo ""
      ;;
  esac
done

# Kimi instructions
echo "---"
echo "Kimi Code: copy the file manually:"
echo "  mkdir -p ~/.kimi/commands"
echo "  curl -sL https://raw.githubusercontent.com/Fenomen-Alex/oss-hunter/main/.kimi-plugin/commands/oss-hunter.md -o ~/.kimi/commands/oss-hunter.md"
echo ""
echo "Done! Restart your agent and try /oss-hunter."
