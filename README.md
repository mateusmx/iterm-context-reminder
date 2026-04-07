# iterm-context-reminder

Pin your current working directory and last AI instruction to iTerm2's status bar.

![status bar example](https://img.shields.io/badge/iTerm2-status_bar-blue)

```
┌─────────────────────────────────────────────────────────────┐
│ 📁 ~/projects/my-app  ·  💬 Add authentication to the API  │  ← status bar
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  (your terminal / Claude Code session)                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

Works with **Claude Code** out of the box. Extensible to other AI coding tools via a simple adapter pattern.

## Requirements

- macOS
- [iTerm2](https://iterm2.com/)
- [jq](https://jqlang.org/) (`brew install jq`)
- zsh or bash

## Install

```bash
git clone https://github.com/mateusmx/iterm-context-reminder.git
cd iterm-context-reminder
./install.sh
```

The installer will:
1. Copy files to `~/.iterm-context-reminder/`
2. Add shell integration to your `.zshrc` or `.bashrc`
3. Configure the Claude Code hook (if Claude Code is installed)
4. Print instructions for the one manual step: configuring iTerm2's status bar

### iTerm2 Status Bar Setup

After running the installer:

1. Open iTerm2 → **Settings** (Cmd+,)
2. Go to **Profiles → Session**
3. Check **"Status bar enabled"**
4. Click **"Configure Status Bar"**
5. Drag **"Interpolated String"** to the bar
6. Click the component and set its value to:
   ```
   📁 \(user.contextPwd)  ·  💬 \(user.lastInstruction)
   ```
7. Go to **Appearance → Status bar location** → select **"Top"**

## Uninstall

```bash
cd iterm-context-reminder
./uninstall.sh
```

Then remove the status bar component in iTerm2 Settings.

## How It Works

1. A **Claude Code hook** fires on every prompt you submit
2. It **summarizes** your instruction (strips code blocks, long URLs, pasted content) to ~80 chars
3. Writes the summary + working directory to a per-session file in `/tmp/`
4. Your shell's **precmd hook** reads that file and sets iTerm2 user variables
5. iTerm2's **status bar** displays the variables at the top of your terminal

Each terminal session uses its own file (keyed by TTY), so multiple sessions never collide. Files are cleaned up on shell exit and on next startup.

## Adding Support for Other Tools

iterm-context-reminder uses a simple file-based adapter pattern. Any tool can participate by writing to `/tmp/iterm_context_<tty_id>.txt`:

```
pwd=/path/to/working/directory
instruction=Short summary of last instruction
tool=tool-name
timestamp=1743984000
```

See [adapters/README.md](adapters/README.md) for the full contract and a template script.

## License

MIT
