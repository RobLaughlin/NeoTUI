# TUI Dev Environment -- Cheat Sheet

Quick reference for all key bindings and commands. View this file with:

    glow CHEATSHEET.md

---

## tmux

The **prefix key** is `Ctrl+b`. Press it, release, then press the action key.

### Windows (Tabs)

| Keys          | Action                        |
|---------------|-------------------------------|
| `prefix, c`   | Create new window             |
| `prefix, &`   | Close current window (confirm)|
| `prefix, n`   | Next window                   |
| `prefix, p`   | Previous window               |
| `prefix, 1-9` | Jump to window by number      |
| `prefix, ,`   | Rename current window         |
| `prefix, w`   | Window picker (interactive)   |

### Panes

| Keys            | Action                          |
|-----------------|---------------------------------|
| `prefix, \|`    | Split vertically (side by side) |
| `prefix, -`     | Split horizontally (top/bottom) |
| `prefix, x`     | Close current pane              |
| `prefix, h`     | Move to left pane               |
| `prefix, j`     | Move to pane below              |
| `prefix, k`     | Move to pane above              |
| `prefix, l`     | Move to right pane              |
| `prefix, H`     | Resize pane left (repeatable)   |
| `prefix, J`     | Resize pane down (repeatable)   |
| `prefix, K`     | Resize pane up (repeatable)     |
| `prefix, L`     | Resize pane right (repeatable)  |
| `prefix, z`     | Toggle pane zoom (fullscreen)   |

### TUI Toggles

| Keys          | Action                              |
|---------------|-------------------------------------|
| `prefix, T`   | Toggle tab bar (show/hide)          |
| `prefix, E`   | Toggle file explorer sidebar        |
| `prefix, v`   | Open Neovim in current directory    |
| `prefix, O`   | Open opencode in a new window       |
| `prefix, r`   | Reload tmux configuration           |

### Copy Mode (vi-style)

| Keys                  | Action                    |
|-----------------------|---------------------------|
| `prefix, [`           | Enter copy mode           |
| `v`                   | Begin selection           |
| `y`                   | Copy selection            |
| `q` or `Esc`          | Exit copy mode            |
| `/`                   | Search forward            |
| `?`                   | Search backward           |

### Session Commands (run from shell)

```
tui                       Launch / attach to TUI session
tmux ls                   List all sessions
tmux attach -t <name>     Attach to a session
tmux kill-session -t <name>  Kill a session
tmux detach  (or prefix, d)  Detach from session
```

---

## Neovim

**Leader key** is `Space`.

### File Navigation (Telescope)

| Keys           | Action              |
|----------------|---------------------|
| `Space ff`     | Find files          |
| `Space fg`     | Live grep (search)  |
| `Space fb`     | Find buffers        |
| `Space fr`     | Recent files        |
| `Space fs`     | Document symbols    |
| `Space fd`     | Diagnostics list    |
| `Space fh`     | Help tags           |

### LSP (Code Intelligence)

| Keys           | Action              |
|----------------|---------------------|
| `gd`           | Go to definition    |
| `gD`           | Go to declaration   |
| `gi`           | Go to implementation|
| `gr`           | Find references     |
| `K`            | Hover documentation |
| `Space rn`     | Rename symbol       |
| `Space ca`     | Code action         |
| `Space f`      | Format file         |
| `Space sh`     | Signature help      |
| `[d`           | Previous diagnostic |
| `]d`           | Next diagnostic     |
| `Space d`      | Float diagnostic    |

### Buffers & Windows

| Keys           | Action                   |
|----------------|--------------------------|
| `Shift+l`      | Next buffer              |
| `Shift+h`      | Previous buffer          |
| `Space bd`     | Close buffer             |
| `Ctrl+h/j/k/l` | Navigate windows        |
| `Ctrl+Up/Down`  | Resize window vertically |
| `Ctrl+Left/Right` | Resize window horizontally |

### Editing

| Keys           | Action                       |
|----------------|------------------------------|
| `Space w`      | Save file                    |
| `Space W`      | Save all files               |
| `Space q`      | Quit                         |
| `Space Q`      | Quit all                     |
| `Space h`      | Clear search highlight       |
| `v J` (visual) | Move selection down          |
| `v K` (visual) | Move selection up            |
| `< / >` (visual) | Indent and stay in visual |
| `Ctrl+d / Ctrl+u` | Half-page jump (centered)|

### Git

| Keys           | Action              |
|----------------|---------------------|
| `Space gc`     | Git commits         |
| `Space gs`     | Git status          |
| `]c`           | Next git hunk       |
| `[c`           | Previous git hunk   |
| `Space hp`     | Preview hunk        |
| `Space hs`     | Stage hunk          |
| `Space hr`     | Reset hunk          |
| `Space hb`     | Blame line          |

### Autocomplete (Insert Mode)

| Keys           | Action                  |
|----------------|-------------------------|
| `Tab`          | Next completion item    |
| `Shift+Tab`    | Previous completion item|
| `Enter`        | Confirm selection       |
| `Ctrl+Space`   | Trigger completion      |
| `Ctrl+e`       | Dismiss completion      |
| `Ctrl+b / Ctrl+f` | Scroll docs         |

---

## Zsh (vi-mode)

Cursor shape indicates mode: **beam** = insert, **block** = normal.
Includes autosuggestions (gray text, accept with right arrow)
and syntax highlighting (valid commands in green, errors in red).

### Mode Switching

| Keys       | Action                    |
|------------|---------------------------|
| `Esc`      | Switch to normal mode     |
| `i`        | Insert mode (at cursor)   |
| `a`        | Insert mode (after cursor)|
| `A`        | Insert at end of line     |
| `I`        | Insert at start of line   |

### Insert Mode Shortcuts

| Keys       | Action               |
|------------|----------------------|
| `Ctrl+l`   | Clear screen         |
| `Ctrl+a`   | Beginning of line    |
| `Ctrl+e`   | End of line          |
| `Ctrl+w`   | Delete previous word |
| `Ctrl+u`   | Delete to start      |
| `Ctrl+k`   | Delete to end        |
| `Ctrl+p`   | Previous history     |
| `Ctrl+n`   | Next history         |

### fzf (Fuzzy Finder)

| Keys       | Action                  |
|------------|-------------------------|
| `Ctrl+r`   | Fuzzy history search    |
| `Ctrl+t`   | Fuzzy file search       |
| `Alt+c`    | Fuzzy directory jump    |

---

## lf (File Explorer)

The prompt bar at the top shows `[WD]` in green when you're viewing
the shell's working directory. When you navigate elsewhere in lf, the
indicator disappears. Preview pane (toggled with `zp`) is read-only;
only the file listing on the left is interactive.

### Navigation

| Keys           | Action                |
|----------------|-----------------------|
| `j / k`        | Move down / up        |
| `h`            | Go to parent directory|
| `l` or `Enter` | Open file / enter dir |
| `gg`           | Go to top             |
| `G`            | Go to bottom          |
| `.`            | Toggle hidden files   |
| `zp`           | Toggle preview pane   |
| `Ctrl+r`       | Reload directory      |

### File Operations

| Keys       | Action                    |
|------------|---------------------------|
| `Enter`    | Open file in Neovim       |
| `o`        | Open file in Neovim       |
| `yy`       | Copy (yank) file          |
| `dd`       | Trash file                |
| `dD`       | Delete file (permanent)   |
| `pp`       | Paste file                |
| `r`        | Rename                    |
| `R`        | Bulk rename (with editor) |
| `md`       | Create directory          |
| `mf`       | Create file               |
| `yp`       | Copy file path to clipboard|

### Quick Navigation

| Keys       | Destination         |
|------------|---------------------|
| `gh`       | Home (~)            |
| `gp`       | ~/projects          |
| `gd`       | ~/Documents         |
| `gD`       | ~/Downloads         |
| `g/`       | Root (/)            |

---

## Shell Aliases

| Alias      | Expands To                      |
|------------|---------------------------------|
| `v`        | `nvim`                          |
| `ll`       | `eza -la --icons --git`         |
| `la`       | `eza -a --icons`                |
| `lt`       | `eza --tree --icons --level=3`  |
| `gs`       | `git status`                    |
| `ga`       | `git add`                       |
| `gc`       | `git commit`                    |
| `gd`       | `git diff`                      |
| `gl`       | `git log --oneline --graph`     |
| `..`       | `cd ..`                         |
| `...`      | `cd ../..`                      |
| `reload`   | `source ~/.bashrc`              |

---

## Useful Commands

```
glow FILE.md         Render markdown in terminal
bat FILE             View file with syntax highlighting
fd PATTERN           Find files by name
rg PATTERN           Search file contents
```
