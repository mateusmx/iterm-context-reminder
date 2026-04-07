# Adapter Guide

iterm-context-reminder uses a file-based protocol. Any AI coding tool can integrate by writing a context file in the expected format.

## File Contract

**Path:** `/tmp/iterm_context_<tty_id>.txt`

Where `<tty_id>` is the TTY device path with `/` replaced by `_`. For example, `/dev/ttys003` becomes `dev_ttys003`.

**Format:**

```
pwd=/absolute/path/to/working/directory
instruction=Short summary of the last user instruction (max ~80 chars)
tool=your-tool-name
timestamp=1743984000
```

**Rules:**
- All fields are single-line, `key=value`, no quoting
- `pwd` — absolute path to the current working directory
- `instruction` — human-readable summary, kept short for the status bar
- `tool` — identifier for the tool that wrote the file (for debugging)
- `timestamp` — Unix epoch seconds when the file was written
- Write atomically if possible (write to temp file, then `mv`)

## Getting the TTY ID

```bash
TTY_ID=$(tty 2>/dev/null | tr '/' '_')
```

If your tool doesn't have a TTY (e.g., GUI app), you can use the terminal's TTY by inspecting the parent process.

## Template Adapter

```bash
#!/usr/bin/env bash
# Adapter template for iterm-context-reminder
# Hook this into your tool's "on user input" event

set -euo pipefail

# Your tool provides these:
USER_INSTRUCTION="$1"  # The raw user input
WORKING_DIR="$2"       # The current working directory

# Resolve TTY
TTY_ID=$(tty 2>/dev/null | tr '/' '_' || echo "unknown")
[[ "$TTY_ID" == "unknown" ]] && exit 0

# Summarize (adapt this to your needs)
INSTRUCTION="${USER_INSTRUCTION:0:80}"
[[ ${#USER_INSTRUCTION} -gt 80 ]] && INSTRUCTION="${INSTRUCTION}..."

# Write context file
cat > "/tmp/iterm_context_${TTY_ID}.txt" <<EOF
pwd=${WORKING_DIR}
instruction=${INSTRUCTION}
tool=your-tool-name
timestamp=$(date +%s)
EOF
```

## No Shell Integration Changes Needed

The shell integration (`context-reminder.sh`) reads the file format generically. It doesn't care which tool wrote it. Once your adapter writes the file, the status bar updates automatically.
