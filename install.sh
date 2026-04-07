#!/usr/bin/env bash
# iterm-context-reminder installer
set -euo pipefail

INSTALL_DIR="$HOME/.iterm-context-reminder"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== iterm-context-reminder installer ==="
echo ""

# --- Step 1: Check prerequisites ---
if [[ "$(uname)" != "Darwin" ]]; then
  echo "Error: This tool requires macOS (iTerm2 is macOS-only)."
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not installed."
  echo "Install it with: brew install jq"
  exit 1
fi

# --- Step 2: Copy files to ~/.iterm-context-reminder ---
echo "[1/4] Installing files to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR/hooks"
cp "$SCRIPT_DIR/shell/context-reminder.sh" "$INSTALL_DIR/context-reminder.sh"
cp "$SCRIPT_DIR/hooks/claude-code.sh" "$INSTALL_DIR/hooks/claude-code.sh"
chmod +x "$INSTALL_DIR/hooks/claude-code.sh"
echo "  Done."

# --- Step 3: Add source line to shell rc file ---
echo "[2/4] Configuring shell integration..."
SOURCE_LINE="source \"$INSTALL_DIR/context-reminder.sh\""

# Detect shell
SHELL_RC=""
if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == */zsh ]]; then
  SHELL_RC="$HOME/.zshrc"
elif [[ -n "${BASH_VERSION:-}" ]] || [[ "$SHELL" == */bash ]]; then
  SHELL_RC="$HOME/.bashrc"
fi

if [[ -z "$SHELL_RC" ]]; then
  echo "  Warning: Could not detect shell. Add this line to your shell rc file manually:"
  echo "    $SOURCE_LINE"
else
  if grep -qF "iterm-context-reminder" "$SHELL_RC" 2>/dev/null; then
    echo "  Already present in $SHELL_RC, skipping."
  else
    echo "" >> "$SHELL_RC"
    echo "# iterm-context-reminder: iTerm2 status bar context" >> "$SHELL_RC"
    echo "$SOURCE_LINE" >> "$SHELL_RC"
    echo "  Added to $SHELL_RC"
  fi
fi

# --- Step 4: Add Claude Code hook ---
echo "[3/4] Configuring Claude Code hook..."
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

if [[ -f "$CLAUDE_SETTINGS" ]]; then
  # Check if hook already exists
  if jq -e '.hooks.UserPromptSubmit' "$CLAUDE_SETTINGS" &>/dev/null; then
    # Check if our hook is already there
    if jq -e '.hooks.UserPromptSubmit[] | select(.hooks[]?.command | contains("iterm-context-reminder"))' "$CLAUDE_SETTINGS" &>/dev/null; then
      echo "  Claude Code hook already configured, skipping."
    else
      # Append our hook to existing UserPromptSubmit array
      TEMP=$(mktemp)
      jq '.hooks.UserPromptSubmit += [{"matcher": "", "hooks": [{"type": "command", "command": "'"$INSTALL_DIR"'/hooks/claude-code.sh"}]}]' "$CLAUDE_SETTINGS" > "$TEMP"
      mv "$TEMP" "$CLAUDE_SETTINGS"
      echo "  Added hook to existing UserPromptSubmit hooks."
    fi
  else
    # Create UserPromptSubmit hooks array
    TEMP=$(mktemp)
    jq '.hooks.UserPromptSubmit = [{"matcher": "", "hooks": [{"type": "command", "command": "'"$INSTALL_DIR"'/hooks/claude-code.sh"}]}]' "$CLAUDE_SETTINGS" > "$TEMP"
    mv "$TEMP" "$CLAUDE_SETTINGS"
    echo "  Created UserPromptSubmit hook."
  fi
else
  echo "  Warning: $CLAUDE_SETTINGS not found."
  echo "  If you use Claude Code, add this hook manually to your settings.json:"
  echo '  "hooks": { "UserPromptSubmit": [{"matcher": "", "hooks": [{"type": "command", "command": "'"$INSTALL_DIR"'/hooks/claude-code.sh"}]}] }'
fi

# --- Step 5: Print iTerm2 configuration instructions ---
echo "[4/4] Almost done! Configure iTerm2 status bar manually:"
echo ""
echo "  1. Open iTerm2 → Settings (Cmd+,)"
echo "  2. Go to Profiles → Session"
echo "  3. Check 'Status bar enabled'"
echo "  4. Click 'Configure Status Bar'"
echo "  5. Drag 'Interpolated String' component to the status bar"
echo "  6. Click the component and set its value to:"
echo ""
echo "     📁 \(user.contextPwd)  ·  💬 \(user.lastInstruction)"
echo ""
echo "  7. Go to Appearance → Status bar location → select 'Top'"
echo ""
echo "=== Installation complete! ==="
echo "Restart your terminal or run: source $SHELL_RC"
