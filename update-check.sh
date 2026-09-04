#!/usr/bin/env bash
set -euo pipefail

REPO="Fenomen-Alex/oss-hunter"
BRANCH="main"
RAW_VERSION_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/VERSION"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

need() { command -v "$1" >/dev/null 2>&1; }
version_gte() {
  [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" = "$2" ]
}

local_version() {
  if [ -f "${SCRIPT_DIR}/VERSION" ]; then
    cat "${SCRIPT_DIR}/VERSION" | tr -d '\n'
  else
    echo "0.0.0"
  fi
}

cmd="${1:-check}"

case "$cmd" in
  check)
    if [ -f "${SCRIPT_DIR}/.update-dismissed" ]; then
      echo '{"status":"dismissed"}'
      exit 0
    fi

    local="$(local_version)"
    remote=""
    if need curl; then
      remote="$(curl -fsSL --max-time 10 "$RAW_VERSION_URL" | tr -d '\n' || true)"
    fi

    if [ -z "$remote" ]; then
      echo "{\"status\":\"offline\",\"local\":\"${local}\"}"
      exit 0
    fi

    if version_gte "$local" "$remote"; then
      echo "{\"status\":\"up-to-date\",\"local\":\"${local}\",\"remote\":\"${remote}\"}"
      exit 0
    fi

    echo "{\"status\":\"update-available\",\"local\":\"${local}\",\"remote\":\"${remote}\"}"
    ;;
  apply)
    if [ ! -w "${SCRIPT_DIR}" ]; then
      echo '{"status":"error","message":"Cannot write to plugin directory"}' >&2
      exit 1
    fi

    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT

    fetch() {
      local src="$1" dst="$2"
      mkdir -p "$(dirname "$dst")"
      curl -fsSL --max-time 30 "https://raw.githubusercontent.com/${REPO}/${BRANCH}/$src" -o "$dst"
    }

    fetch "VERSION" "${tmp}/VERSION"
    fetch ".opencode/plugins/oss-hunter.md" "${tmp}/opencode/oss-hunter.md"
    fetch ".opencode/plugins/oss-issue.md" "${tmp}/opencode/oss-issue.md"
    fetch ".claude-plugin/commands/oss-hunter.md" "${tmp}/claude/oss-hunter.md"
    fetch ".claude-plugin/commands/oss-issue.md" "${tmp}/claude/oss-issue.md"
    fetch ".codex-plugin/oss-hunter.md" "${tmp}/codex/oss-hunter.md"
    fetch ".codex-plugin/oss-issue.md" "${tmp}/codex/oss-issue.md"
    fetch ".kimi-plugin/commands/oss-hunter.md" "${tmp}/kimi/oss-hunter.md"
    fetch ".kimi-plugin/commands/oss-issue.md" "${tmp}/kimi/oss-issue.md"

    if [ -f "${SCRIPT_DIR}/.update-dismissed" ]; then
      rm -f "${SCRIPT_DIR}/.update-dismissed"
    fi

    install -m 0644 "${tmp}/VERSION" "${SCRIPT_DIR}/VERSION"

    if [ -d "${SCRIPT_DIR}/.opencode/plugins" ]; then
      install -m 0644 "${tmp}/opencode/oss-hunter.md" "${SCRIPT_DIR}/.opencode/plugins/oss-hunter.md"
      install -m 0644 "${tmp}/opencode/oss-issue.md" "${SCRIPT_DIR}/.opencode/plugins/oss-issue.md"
    fi

    if [ -d "${SCRIPT_DIR}/.claude-plugin/commands" ]; then
      install -m 0644 "${tmp}/claude/oss-hunter.md" "${SCRIPT_DIR}/.claude-plugin/commands/oss-hunter.md"
      install -m 0644 "${tmp}/claude/oss-issue.md" "${SCRIPT_DIR}/.claude-plugin/commands/oss-issue.md"
    fi

    if [ -d "${SCRIPT_DIR}/.codex-plugin" ]; then
      install -m 0644 "${tmp}/codex/oss-hunter.md" "${SCRIPT_DIR}/.codex-plugin/oss-hunter.md"
      install -m 0644 "${tmp}/codex/oss-issue.md" "${SCRIPT_DIR}/.codex-plugin/oss-issue.md"
    fi

    if [ -d "${SCRIPT_DIR}/.kimi-plugin/commands" ]; then
      install -m 0644 "${tmp}/kimi/oss-hunter.md" "${SCRIPT_DIR}/.kimi-plugin/commands/oss-hunter.md"
      install -m 0644 "${tmp}/kimi/oss-issue.md" "${SCRIPT_DIR}/.kimi-plugin/commands/oss-issue.md"
    fi

    remote="$(cat "${tmp}/VERSION" | tr -d '\n')"
    echo "{\"status\":\"updated\",\"local\":\"$(local_version)\",\"remote\":\"${remote}\"}"
    ;;
  dismiss)
    touch "${SCRIPT_DIR}/.update-dismissed"
    echo '{"status":"dismissed"}'
    ;;
  *)
    echo "Usage: $0 [check|apply|dismiss]"
    exit 1
    ;;
esac
