# 🚀 Modern Dotfiles

A high-performance, modular, and cross-platform dotfiles ecosystem designed for **macOS**, **Linux**, and **Windows**.

---

## ⚡ Quick Start

### macOS & Linux

Deploy the full environment and install all core tools with a single command (requires `gh auth` if private):

```bash
rm -rf /tmp/dotfiles && gh repo clone tfernd/dotfiles /tmp/dotfiles && bash /tmp/dotfiles/install.sh && source ~/.dotfiles/init.sh && setup-terminal
```

### Windows (PowerShell Administrator)

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/tfernd/dotfiles/main/win.ps1'))
```

_Follow by running `~/dotfiles/install.sh` in Git Bash._

---

## 🛠️ Core Tools

This environment replaces legacy commands with these modern alternatives:

| Tool             | Replacement For | Description                                              |
| :--------------- | :-------------- | :------------------------------------------------------- |
| **Starship**     | Default Prompt  | Extremely fast, customizable cross-shell prompt          |
| **Zoxide**       | `cd`            | Smarter, learning directory jumper                       |
| **Eza**          | `ls`            | Modern, colorized file listing with icons                |
| **Bat**          | `cat`           | Syntax highlighting and Git integration for files        |
| **Ripgrep (rg)** | `grep`          | The fastest recursive text searcher                      |
| **Fzf**          | `search`        | Interactive selector for files and history               |
| **Trash-cli**    | `rm`            | Safe deletion with specialized FZF recovery (`rt`/`rtt`) |
| **UV / Bun**     | `pip / npm`     | Shell guards automatically pointing to fast alternatives |

---

## 📖 Terminal Inventory

Type `help` in your terminal to see this list live or `dotdoctor` to check system health.

### 📂 Files & Navigation

- `cd` : Smarter directory jumping (powered by **Zoxide**)
- `ls` / `ll` / `lt` : Modern `ls` with icons/colors (**Eza**) — `ll`=long, `lt`=tree
- `cat` : Modern `cat` with syntax highlighting (**Bat**)
- `y` : Terminal visual file explorer (**Yazi**)
- `fd` : Simple and fast alternative to `find`
- `cw` : Instantly switch editor window to current folder (Cursor/Code/Antigravity)
- `backup <file>` : Create a dated copy: `filename.YYYYMMDD_HHMMSS.bak`
- `symlink <link> <target>` : Cross-platform symlink creator (handles Windows Junctions)
- `extract <file>` : Instant extraction for `.zip`, `.tar.gz`, `.rar`, `.7z`, etc.
- `compress <name> <files...>` : Smart compression (defaults to `.tar.gz` if no extension)

### 🔍 Search & Fuzzy Workflows (FZF)

- `f` / `ff` : Fuzzy file search (CWD / HOME) -> inject path at cursor position
- `h` / `hh` : Fuzzy history search -> `h` injects to prompt / `hh` copies to clipboard
- `rt` / `rtt` : Interactive Trash restore (interactive FZF selector)

### 🐙 Git & GitHub

- `lg` : Open **Lazygit** TUI (Visual Git)
- `gs` : Short branch status (`git status -sb`)
- `gds` : Diff staged changes (`git diff --staged`)
- `gb` / `gba` : List local branches / List all branches (including remote)
- `ga` : Stage all changes (`git add --all`)
- `gl` : High-contrast, beautiful graph log
- `gu` : Undo last commit (keeps changes staged)
- `gam` : Amend current commit quietly
- `gr` : **Git Redo** (Fuzzy Time Machine) — reset to any point in reflog
- `pr` / `prs` : GitHub CLI wrappers for browser-based PR creation and listing

### 🌐 Network & System

- `myip` : Show public IPv4 and IPv6 addresses
- `localip` : Show current local LAN IP (OS-aware)
- `port <num>` : See what process is listening on a specific port
- `kill-port <num>` : Force kill any process occupying a port
- `memhog` : Show top 15 memory-consuming processes
- `top` : Interactive system monitor (prefers `btm` if installed)
- `http` : Modern API testing and cURL replacement (**XH**)
- `copy` / `cpwd` : Clipboard utilities (`copy` reads stdin, `cpwd` copies current path)
- `path` : Pretty-print your `$PATH` one entry per line
- `please` : Re-run previous command with `sudo` (Linux/macOS only)

### 🛠️ Environment & Dev-Ops

- `dotdoctor` : Check if all core tools are installed and caches are healthy
- `envup <file>` : Load `.env` variables into your current shell session
- `pyclean` : Recursively delete Python bytecode and cache folders
- `setup-terminal` : Re-run installer to repair or update the environment
- `refresh` : Rebuild the tool cache and reload the shell configuration
- `hclear` : Securely wipe all terminal history with confirmation
- `c` : Shortcut for `clear`

### 🤖 AI Guard Aliases

Global aliases that warn you when using legacy tools and suggest modern, faster AI-optimized alternatives:

- `node`, `npm`, `npx` -> Suggests **Bun**
- `yarn`, `pnpm` -> Suggests **Bun**
- `nodemon`, `ts-node`, `tsx` -> Suggests **Bun**
- `python`, `pip`, `venv` -> Suggests **UV**
- `poetry` -> Suggests **UV**

---

## ☁️ Cloud & Infrastructure

Enhanced support for AWS and Terraform development:

- **Intelligent AWS Prompt**:
  -  **Profile name** and **Account ID** visibility.
  - **Region Flags** (e.g. 🇮🇪 for Ireland, 🇺🇸 for US).
  - **Session Duration**: Live countdown timer for temporary/SSO credentials.
- `aws who` : Dynamic identity summary (Account, Role, Profile, Region).
- `aws login` : Alias for modern AWS login sessions.
- `tf` : Shortcut for **Terraform**.
- `aws s3 ls` : Quickly list your cloud storage buckets.
