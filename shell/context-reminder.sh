#!/usr/bin/env bash
# iterm-context-reminder: Shell integration for iTerm2 status bar
# Source this file in your .zshrc or .bashrc
#
# Sets iTerm2 user variables:
#   user.contextPwd        — working directory from the AI tool
#   user.lastInstruction   — summarized last instruction

# --- iTerm2 user variable setter ---
# Uses iTerm2's proprietary escape sequence to set per-session variables
# that can be referenced in the status bar as \(user.varName)
_iterm_context_set_user_var() {
  local key="$1"
  local value="$2"
  printf "\033]1337;SetUserVar=%s=%s\007" "$key" "$(printf '%s' "$value" | base64)"
}

# --- Resolve TTY ID for this session ---
_iterm_context_tty_id() {
  tty 2>/dev/null | tr '/' '_' || echo "unknown"
}

# --- Read context file and set iTerm2 user vars ---
_iterm_context_update() {
  local tty_id
  tty_id=$(_iterm_context_tty_id)

  local context_file="/tmp/iterm_context_${tty_id}.txt"

  local ctx_pwd="$PWD"
  local ctx_instruction=""

  if [[ -f "$context_file" ]]; then
    # Read key=value pairs
    while IFS='=' read -r key value; do
      case "$key" in
        pwd) ctx_pwd="$value" ;;
        instruction) ctx_instruction="$value" ;;
      esac
    done < "$context_file"
  fi

  _iterm_context_set_user_var "contextPwd" "$ctx_pwd"
  _iterm_context_set_user_var "lastInstruction" "$ctx_instruction"
}

# --- Cleanup: delete context file on shell exit ---
_iterm_context_cleanup() {
  local tty_id
  tty_id=$(_iterm_context_tty_id)
  rm -f "/tmp/iterm_context_${tty_id}.txt"
}

# --- Startup cleanup: remove stale files from dead TTYs ---
_iterm_context_cleanup_stale() {
  for f in /tmp/iterm_context_*; do
    [[ -f "$f" ]] || continue
    # Extract TTY path: iterm_context_dev_ttys003.txt -> /dev/ttys003
    local tty_name
    tty_name=$(basename "$f" .txt | sed 's/^iterm_context_//' | tr '_' '/')
    if [[ ! -e "/$tty_name" ]]; then
      rm -f "$f"
    fi
  done
}

# --- Wire everything up ---

# Clean stale files from previous sessions on startup
_iterm_context_cleanup_stale

# Register exit trap
trap _iterm_context_cleanup EXIT

# Register precmd hook (works in both zsh and bash)
if [[ -n "$ZSH_VERSION" ]]; then
  # zsh: use precmd_functions array
  precmd_functions+=(_iterm_context_update)
elif [[ -n "$BASH_VERSION" ]]; then
  # bash: append to PROMPT_COMMAND
  if [[ -z "$PROMPT_COMMAND" ]]; then
    PROMPT_COMMAND="_iterm_context_update"
  else
    PROMPT_COMMAND="_iterm_context_update;${PROMPT_COMMAND}"
  fi
fi
