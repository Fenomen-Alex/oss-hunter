#!/usr/bin/env bash
set -euo pipefail

REPO="Fenomen-Alex/oss-hunter"
BRANCH="main"

echo "=== OSS Hunter Installer ==="
echo ""

# Prefer local files if script is run from repo checkout, else fetch from GitHub
if [ -f "$(dirname "$0")/.opencode/plugins/oss-hunter.md" ]; then
  SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
  echo "Installing from local checkout: $SRC_DIR"
  echo ""
else
  SRC_DIR=""
  echo "Installing from GitHub..."
  echo ""
fi

fetch() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -n "$SRC_DIR" ]; then
    cp "$SRC_DIR/$src" "$dst"
  else
    curl -sL "https://raw.githubusercontent.com/$REPO/$BRANCH/$src" -o "$dst"
  fi
}

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Fetch commands
fetch ".opencode/plugins/oss-hunter.md"       "$TMPDIR/opencode/oss-hunter.md"
fetch ".opencode/plugins/oss-issue.md"        "$TMPDIR/opencode/oss-issue.md"
fetch ".claude-plugin/commands/oss-hunter.md"  "$TMPDIR/claude/oss-hunter.md"
fetch ".claude-plugin/commands/oss-issue.md"   "$TMPDIR/claude/oss-issue.md"
fetch ".codex-plugin/oss-hunter.md"            "$TMPDIR/codex/oss-hunter.md"
fetch ".codex-plugin/oss-issue.md"             "$TMPDIR/codex/oss-issue.md"
fetch ".kimi-plugin/commands/oss-hunter.md"    "$TMPDIR/kimi/oss-hunter.md"
fetch ".kimi-plugin/commands/oss-issue.md"     "$TMPDIR/kimi/oss-issue.md"

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
      COMMAND_DIR="$CONFIG_DIR/commands"
      mkdir -p "$COMMAND_DIR"
      cp "$TMPDIR/opencode/oss-hunter.md" "$COMMAND_DIR/"
      cp "$TMPDIR/opencode/oss-issue.md" "$COMMAND_DIR/"
      echo "  [OK] OpenCode: copied to $COMMAND_DIR/oss-hunter.md"
      echo "  [OK] OpenCode: copied to $COMMAND_DIR/oss-issue.md"
      echo ""
      ;;
    claude)
      COMMAND_DIR="${HOME}/.claude/commands"
      mkdir -p "$COMMAND_DIR"
      cp "$TMPDIR/claude/oss-hunter.md" "$COMMAND_DIR/"
      cp "$TMPDIR/claude/oss-issue.md" "$COMMAND_DIR/"
      echo "  [OK] Claude Code: copied to $COMMAND_DIR/oss-hunter.md"
      echo "  [OK] Claude Code: copied to $COMMAND_DIR/oss-issue.md"
      echo ""
      ;;
    codex)
      COMMAND_DIR="${HOME}/.codex/commands"
      mkdir -p "$COMMAND_DIR"
      cp "$TMPDIR/codex/oss-hunter.md" "$COMMAND_DIR/"
      cp "$TMPDIR/codex/oss-issue.md" "$COMMAND_DIR/"
      echo "  [OK] Codex CLI: copied to $COMMAND_DIR/oss-hunter.md"
      echo "  [OK] Codex CLI: copied to $COMMAND_DIR/oss-issue.md"
      echo ""
      ;;
  esac
done

echo "---"
echo "Kimi Code:"
echo "  mkdir -p ~/.kimi/commands"
echo "  curl -sL https://raw.githubusercontent.com/Fenomen-Alex/oss-hunter/main/.kimi-plugin/commands/oss-hunter.md -o ~/.kimi/commands/oss-hunter.md"
echo "  curl -sL https://raw.githubusercontent.com/Fenomen-Alex/oss-hunter/main/.kimi-plugin/commands/oss-issue.md -o ~/.kimi/commands/oss-issue.md"
echo ""
echo "Done! Restart your agent and try /oss-hunter or /oss-issue."
