#!/usr/bin/env bash
# iterm-context-reminder: Claude Code UserPromptSubmit hook
# Reads the user's prompt from stdin JSON, summarizes it,
# and updates iTerm2's status bar via escape sequences.

# Ensure we never block the prompt — always exit 0
trap 'exit 0' ERR

# --- Read hook input from stdin ---
INPUT=$(cat)

PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# Exit silently if no prompt
if [[ -z "$PROMPT" ]]; then
  exit 0
fi

# Fall back to $PWD if cwd not in JSON
if [[ -z "$CWD" ]]; then
  CWD="$PWD"
fi

# --- Resolve TTY device ---
# The hook runs as a subprocess, so `tty` won't work.
# Walk up the process tree to find the controlling TTY.
_resolve_tty() {
  local pid=$$
  local tty_short=""
  while [[ -n "$pid" && "$pid" != "0" ]]; do
    tty_short=$(ps -o tty= -p "$pid" 2>/dev/null | xargs)
    if [[ -n "$tty_short" && "$tty_short" != "??" ]]; then
      # ps -o tty= returns "ttys003" on macOS (already includes "tty" prefix)
      echo "/dev/${tty_short}"
      return
    fi
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | xargs)
  done
  echo ""
}

TTY_DEVICE=$(_resolve_tty)
if [[ -z "$TTY_DEVICE" || ! -e "$TTY_DEVICE" ]]; then
  exit 0
fi
TTY_ID=$(echo "$TTY_DEVICE" | tr '/' '_')

# --- Summarization heuristic ---
summarize() {
  local text="$1"

  # 1. Strip markdown code blocks (```...```)
  text=$(echo "$text" | sed '/^```/,/^```/d')

  # 2. Strip URLs longer than 40 chars
  text=$(echo "$text" | sed -E 's|https?://[^ ]{41,}||g')

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

# --- Write context file (for precmd fallback and other tools) ---
CONTEXT_FILE="/tmp/iterm_context_${TTY_ID}.txt"

cat > "$CONTEXT_FILE" <<EOF
pwd=${CWD}
instruction=${INSTRUCTION}
tool=claude-code
timestamp=$(date +%s)
EOF

# --- Update iTerm2 status bar immediately ---
# Write escape sequences directly to the TTY device so the status bar
# updates while Claude Code is running (precmd won't fire until you exit).
if [[ -w "$TTY_DEVICE" ]]; then
  printf "\033]1337;SetUserVar=%s=%s\007" "contextPwd" "$(printf '%s' "$CWD" | base64)" > "$TTY_DEVICE"
  printf "\033]1337;SetUserVar=%s=%s\007" "lastInstruction" "$(printf '%s' "$INSTRUCTION" | base64)" > "$TTY_DEVICE"
fi

exit 0
