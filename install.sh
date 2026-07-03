#!/bin/bash
# Installer for the Claude Code status line.
# Copies statusline.sh into ~/.claude and wires up settings.json.
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
SRC="$(cd "$(dirname "$0")" && pwd)/statusline.sh"

command -v jq >/dev/null 2>&1 || { echo "Error: jq is required but not found. Install it (e.g. 'brew install jq') and retry."; exit 1; }
[ -f "$SRC" ] || { echo "Error: statusline.sh not found next to this installer."; exit 1; }

mkdir -p "$CLAUDE_DIR"

REPO="$(cd "$(dirname "$0")" && pwd)"

# 1. Install the status line script
cp "$SRC" "$CLAUDE_DIR/statusline.sh"
chmod +x "$CLAUDE_DIR/statusline.sh"
echo "Installed $CLAUDE_DIR/statusline.sh"

# 1b. Install the usage/spend report + its /my-usd slash command
if [ -f "$REPO/my-usd.sh" ]; then
  cp "$REPO/my-usd.sh" "$CLAUDE_DIR/my-usd.sh"
  chmod +x "$CLAUDE_DIR/my-usd.sh"
  echo "Installed $CLAUDE_DIR/my-usd.sh"
fi
if [ -f "$REPO/commands/my-usd.md" ]; then
  mkdir -p "$CLAUDE_DIR/commands"
  cp "$REPO/commands/my-usd.md" "$CLAUDE_DIR/commands/my-usd.md"
  echo "Installed $CLAUDE_DIR/commands/my-usd.md  (use /my-usd in Claude Code)"
fi

# 2. Wire up settings.json (creating it if absent)
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

if jq -e '.statusLine' "$SETTINGS" >/dev/null 2>&1; then
  echo "A 'statusLine' setting already exists in $SETTINGS — leaving it untouched."
  echo "To use this one, set its command to: ~/.claude/statusline.sh"
  exit 0
fi

cp "$SETTINGS" "$SETTINGS.bak"
tmp="$(mktemp)"
jq '. + {statusLine: {type: "command", command: "~/.claude/statusline.sh"}}' "$SETTINGS" > "$tmp"
mv "$tmp" "$SETTINGS"
echo "Updated $SETTINGS (backup at $SETTINGS.bak)"
echo "Done. Start a new Claude Code session to see your status line."
