#!/usr/bin/env bash
# iterm-context-reminder: Claude Code UserPromptSubmit hook
# Reads the user's prompt from stdin JSON, summarizes it,
# and writes context to a per-TTY file for iTerm2 status bar display.

set -euo pipefail

# --- Read hook input from stdin ---
INPUT=$(cat)

PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# Exit silently if no prompt (shouldn't happen, but be safe)
if [[ -z "$PROMPT" ]]; then
  exit 0
fi

# Fall back to $PWD if cwd not in JSON
if [[ -z "$CWD" ]]; then
  CWD="$PWD"
fi

# --- Resolve TTY ID ---
TTY_ID=$(tty 2>/dev/null | tr '/' '_' || echo "unknown")
if [[ "$TTY_ID" == "unknown" || "$TTY_ID" == "not_a_tty" ]]; then
  # Try parent process TTY
  TTY_ID=$(ps -o tty= -p $PPID 2>/dev/null | tr '/' '_' | xargs || echo "unknown")
fi
if [[ "$TTY_ID" == "unknown" || -z "$TTY_ID" ]]; then
  exit 0
fi

# --- Summarization heuristic ---
summarize() {
  local text="$1"

  # 1. Strip markdown code blocks (```...```)
  text=$(echo "$text" | sed '/^```/,/^```/d')

  # 2. Strip URLs longer than 40 chars
  text=$(echo "$text" | sed -E 's|https?://[^ ]{40,}||g')

  # 3. Strip lines that look like file content
  #    - Indented 4+ spaces
  #    - Starting with { [ < #!
  text=$(echo "$text" | sed -E '/^[[:space:]]{4,}/d')
  text=$(echo "$text" | sed -E '/^[[:space:]]*[\{\[\<]/d')
  text=$(echo "$text" | sed -E '/^#!/d')

  # 4. Collapse consecutive whitespace
  text=$(echo "$text" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g')

  # 5. Trim leading/trailing whitespace
  text=$(echo "$text" | sed -E 's/^[[:space:]]+//;s/[[:space:]]+$//')

  # 6. If nothing remains, use placeholder
  if [[ -z "$text" ]]; then
    echo "[pasted content]"
    return
  fi

  # 7. Truncate to 80 chars, append ... if truncated
  if [[ ${#text} -gt 80 ]]; then
    echo "${text:0:80}..."
  else
    echo "$text"
  fi
}

INSTRUCTION=$(summarize "$PROMPT")

# --- Write context file ---
CONTEXT_FILE="/tmp/iterm_context_${TTY_ID}.txt"

cat > "$CONTEXT_FILE" <<EOF
pwd=${CWD}
instruction=${INSTRUCTION}
tool=claude-code
timestamp=$(date +%s)
EOF

exit 0
