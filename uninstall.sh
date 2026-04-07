#!/usr/bin/env bash
# iterm-context-reminder uninstaller
set -euo pipefail

INSTALL_DIR="$HOME/.iterm-context-reminder"

echo "=== iterm-context-reminder uninstaller ==="
echo ""

# --- Step 1: Remove installed files ---
if [[ -d "$INSTALL_DIR" ]]; then
  rm -rf "$INSTALL_DIR"
  echo "[1/4] Removed $INSTALL_DIR"
else
  echo "[1/4] $INSTALL_DIR not found, skipping."
fi

# --- Step 2: Remove source line from shell rc ---
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  if [[ -f "$rc" ]]; then
    if grep -qF "iterm-context-reminder" "$rc"; then
      # Remove the comment line and the source line
      TEMP=$(mktemp)
      grep -vF "iterm-context-reminder" "$rc" > "$TEMP"
      mv "$TEMP" "$rc"
      echo "[2/4] Removed source line from $rc"
    fi
  fi
done

# --- Step 3: Remove Claude Code hook ---
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
if [[ -f "$CLAUDE_SETTINGS" ]]; then
  if jq -e '.hooks.UserPromptSubmit' "$CLAUDE_SETTINGS" &>/dev/null; then
    TEMP=$(mktemp)
    jq '.hooks.UserPromptSubmit = [.hooks.UserPromptSubmit[] | select(.hooks[]?.command | contains("iterm-context-reminder") | not)]' "$CLAUDE_SETTINGS" > "$TEMP"
    # If the array is now empty, remove the key
    if jq -e '.hooks.UserPromptSubmit | length == 0' "$TEMP" &>/dev/null; then
      jq 'del(.hooks.UserPromptSubmit)' "$TEMP" > "${TEMP}.2"
      mv "${TEMP}.2" "$TEMP"
    fi
    mv "$TEMP" "$CLAUDE_SETTINGS"
    echo "[3/4] Removed Claude Code hook from settings.json"
  else
    echo "[3/4] No Claude Code hook found, skipping."
  fi
else
  echo "[3/4] Claude Code settings not found, skipping."
fi

# --- Step 4: Clean up temp files ---
rm -f /tmp/iterm_context_*
echo "[4/4] Cleaned up /tmp/iterm_context_* files"

echo ""
echo "=== Uninstall complete! ==="
echo ""
echo "Note: Remove the status bar component manually in iTerm2:"
echo "  Settings → Profiles → Session → Configure Status Bar"
echo ""
echo "Restart your terminal to complete the cleanup."
