#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== OSS Hunter Installer ==="
echo ""

# Detect which agents are installed and offer to install
INSTALLED=()

if command -v opencode &>/dev/null; then
  INSTALLED+=("opencode")
fi

if command -v claude &>/dev/null; then
  INSTALLED+=("claude-code")
fi

if command -v codex &>/dev/null; then
  INSTALLED+=("codex")
fi

# Kimi Code has no reliable CLI check; skip auto-detect

if [ ${#INSTALLED[@]} -eq 0 ]; then
  echo "No supported coding agents detected on PATH."
  echo "Supported: OpenCode, Claude Code, Codex CLI, Kimi Code"
  echo ""
  echo "Install one of those first, then re-run this script."
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
      cp "$REPO_DIR/.opencode/plugins/oss-hunter.md" "$PLUGIN_DIR/"
      echo "  [OK] OpenCode: copied to $PLUGIN_DIR/oss-hunter.md"
      echo "       Add to opencode.json:"
      echo '       "plugin": ["oss-hunter@git+https://github.com/<your-username>/oss-hunter.git"]'
      echo ""
      ;;
    claude-code)
      COMMAND_DIR="${HOME}/.claude/commands"
      mkdir -p "$COMMAND_DIR"
      cp "$REPO_DIR/.claude-plugin/commands/oss-hunter.md" "$COMMAND_DIR/"
      echo "  [OK] Claude Code: copied to $COMMAND_DIR/oss-hunter.md"
      echo ""
      ;;
    codex)
      COMMAND_DIR="${HOME}/.codex/commands"
      mkdir -p "$COMMAND_DIR"
      cp "$REPO_DIR/.codex-plugin/oss-hunter.md" "$COMMAND_DIR/"
      echo "  [OK] Codex CLI: copied to $COMMAND_DIR/oss-hunter.md"
      echo ""
      ;;
  esac
done

# Offer Kimi install manually
echo "---"
echo "Kimi Code:"
echo "  Copy .kimi-plugin/commands/oss-hunter.md to ~/.kimi/commands/"
echo ""
echo "Done! Restart your agent and try /oss-hunter."
