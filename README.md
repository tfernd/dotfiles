# 🚀 Modern Dotfiles

A high-performance, modular, and cross-platform dotfiles ecosystem designed for **macOS**, **Linux**, and **Windows**. Optimized for a sub-50ms startup time and a frictionless developer workflow.

---

## ⚡ Quick Start

### macOS & Linux
Deploy the full environment and install all core tools with a single command (requires `gh auth` if private):
```bash
gh repo clone tfernd/dotfiles /tmp/dotfiles && bash /tmp/dotfiles/install.sh
```

### Windows (PowerShell Administrator)
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/tfernd/dotfiles/main/win.ps1'))
```
*Follow by running `~/dotfiles/install.sh` in Git Bash.*

---

## 🛠️ Core Tools
This environment replaces legacy commands with these modern alternatives:

| Tool             | Replacement For | Description                                             |
| :--------------- | :-------------- | :------------------------------------------------------ |
| **Starship**     | Default Prompt  | Extremely fast, customizable cross-shell prompt         |
| **Zoxide**       | `cd`            | Smarter, learning directory jumper                      |
| **Eza**          | `ls`            | Modern, colorized file listing with icons               |
| **Bat**          | `cat`           | Syntax highlighting and Git integration for files       |
| **Ripgrep (rg)** | `grep`          | The fastest recursive text searcher                     |
| **Fzf**          | `search`        | Interactive selector for files and history              |
| **Trash-cli**    | `rm`            | Safe deletion with specialized FZF recovery (`rt`/`rtt`) |
| **UV / Bun**     | `pip / npm`     | Shell guards automatically pointing to fast alternatives |

---

## 📖 Terminal Cheatsheet
Type `help` in your terminal to see this list live.

### 📂 Files & Navigation
- `cd` : Smarter cd (zoxide)
- `cw` : Switch editor window to current folder (Cursor/Code/Antigravity)
- `ls` / `ll` : Modern `ls` with icons (ll = long, lt = tree)
- `cat` : Modern `cat` with syntax highlighting (bat)
- `extract` / `compress` : Instant archive handling for ANY format
- `backup` : Quick dated copy of a file or folder
- `symlink` : Cross-platform symlink/junction creator

### 🔍 Search & System
- `f` / `ff` : Fuzzy file search (CWD / HOME) -> inject path at cursor
- `h` / `hh` : Fuzzy history search -> inject / copy to clipboard
- `y` : Terminal visual file explorer (yazi)
- `http` : API testing and cURL replacement (xh)
- `port` / `kill-port` : Port management and process termination
- `copy` / `cpwd` / `ccat` : Advanced clipboard utilities
- `myip` / `localip` : Quick network identity discovery
- `memhog` : Show top 15 memory-hogging processes

### 🐙 Git & GitHub
- `lg` : Open Lazygit TUI (Visual Git)
- `gs` / `gl` : Short status / Beautiful graph log
- `gu` / `gr` / `gam` : Undo commit / Redo state / Amend quietly
- `pr` / `prs` : GitHub CLI wrappers for PR management

#### 🎨 Git Prompt Symbols (`help git`)
| Sym | Name | Description |
| :--- | :--- | :--- |
| **⛶N** | Stashed | N stash entries saved |
| **⨳N** | Conflicted | N merge conflicts (resolve first!) |
| **⇡N** | Ahead | N commits away from remote (push) |
| **⇣N** | Behind | N commits behind remote (pull) |
| **+N** | Staged | N files added to index |
| **!N** | Modified | N files changed but not staged |
| **↦N** | Renamed | N files moved/renamed |
| **✘N** | Deleted | N files removed |
| **?N** | Untracked | N new files |

---

## ✨ Engineering Features
- **🚀 Sub-50ms Startup**: Custom **Tool Cache** plugin bypasses expensive `command -v` lookups.
- **🗑️ FZF Recovery**: `rt` (local) and `rtt` (global) use interactive filters to restore files from Trash.
- **🐍 Python & JS Guards**: Global aliases for `python`/`node` that warn and redirect to `uv`/`bun`.
- **🏗️ Strictly Modular**: Clean separation between `env`, `aliases`, `functions`, and `plugins`.
- **🧪 CI/CD Ready**: Built-in test suite (`bash test/suite.sh`) for environment health checks.
