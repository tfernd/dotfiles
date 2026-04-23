# 🚀 Modern Dotfiles

A high-performance, modular, and cross-platform dotfiles ecosystem.

### 🖥️ Supported Platforms

| Platform                          | Shell     | Status          |
| --------------------------------- | --------- | --------------- |
| **macOS** (Apple Silicon & Intel) | Zsh, Bash | ✅ Full support |
| **Linux** (Debian/Ubuntu)         | Zsh, Bash | ✅ Full support |
| **WSL** (Debian)                  | Zsh, Bash | ✅ Full support |

---

## ⚡ Quick Start

### macOS & Linux

```bash
git clone https://github.com/tfernd/dotfiles.git /tmp/dotfiles
bash /tmp/dotfiles/install.sh
```

This copies everything to `~/.dotfiles/` (no `.git` in your home), sets up your shell configs, and installs all tools.

---

## 🛠️ Installed Tools

All tools are installed automatically by `install.sh`.

| Package / Binary                | Description                         | macOS | Linux/WSL | Install Source                 |
| ------------------------------- | ----------------------------------- | :---: | :-------: | ------------------------------ |
| **Core CLI Tools**              |                                     |       |           |                                |
| `starship`                      | Cross-shell prompt engine           |  ✅   |    ✅     | Homebrew / installer           |
| `zoxide`                        | Smart directory jumper (cd)         |  ✅   |    ✅     | Homebrew / installer           |
| `bat`                           | Syntax-highlighted cat              |  ✅   |    ✅¹    | Homebrew / APT                 |
| `eza`                           | Modern ls with icons                |  ✅   |    ✅     | Homebrew / Linuxbrew           |
| `rg` (ripgrep)                  | Fast recursive text search          |  ✅   |    ✅     | Homebrew / APT                 |
| `fd`                            | Fast find alternative               |  ✅   |    ✅²    | Homebrew / APT                 |
| `fzf`                           | Fuzzy finder                        |  ✅   |    ✅     | Homebrew / APT                 |
| `delta` (git-delta)             | Beautiful git diffs                 |  ✅   |    ✅     | Homebrew / .deb                |
| `jq`                            | JSON processor                      |  ✅   |    ✅     | Homebrew / APT                 |
| `yq`                            | YAML processor                      |  ✅   |    ✅     | Homebrew / Linuxbrew           |
| `xh`                            | HTTP client (curl replacement)      |  ✅   |    ✅     | Homebrew / Linuxbrew           |
| `tldr` (tealdeer)               | Quick command cheat sheets          |  ✅   |    ✅     | Homebrew / APT                 |
| **Git & GitHub**                |                                     |       |           |                                |
| `git`                           | Version control                     |  ✅   |    ✅     | Xcode CLT / APT                |
| `gh`                            | GitHub CLI                          |  ✅   |    ✅     | Homebrew / APT repo            |
| `lazygit`                       | Visual git TUI                      |  ✅   |    ✅     | Homebrew / Linuxbrew           |
| **File & System**               |                                     |       |           |                                |
| `trash` / `trash-put`           | Safe file deletion                  |  ✅   |    ✅³    | Homebrew / APT                 |
| `yazi`                          | Terminal file explorer              |  ✅   |    ✅     | Homebrew / Linuxbrew           |
| `btm` (bottom)                  | System monitor                      |  ✅   |    ✅     | Homebrew / Linuxbrew           |
| **Archive & Compression**       |                                     |       |           |                                |
| `7z` (p7zip / 7zip)             | 7-Zip archive support               |  ✅   |    ✅     | Homebrew / APT                 |
| `zip` / `unzip`                 | ZIP archive support                 |  ✅   |    ✅     | Homebrew / APT                 |
| `xz`                            | XZ compression                      |  ✅   |    ✅     | Homebrew / APT                 |
| `zstd`                          | Zstandard compression               |  ✅   |    ✅     | Homebrew / APT                 |
| `unrar`                         | RAR extraction                      |  ❌   |    ✅     | APT                            |
| `bzip2`                         | Bzip2 compression                   |  ✅⁴  |    ✅     | built-in / APT                 |
| **Runtimes & Package Managers** |                                     |       |           |                                |
| `bun`                           | Fast JS runtime (replaces node/npm) |  ✅   |    ✅     | Official installer             |
| `uv`                            | Fast Python package manager         |  ✅   |    ✅     | Official installer (astral.sh) |
| **Shell Plugins & Fonts**       |                                     |       |           |                                |
| zsh-autosuggestions             | Shell autocompletion plugin         |  ✅   |    ✅     | Homebrew / APT                 |
| zsh-syntax-highlighting         | Shell syntax coloring plugin        |  ✅   |    ✅     | Homebrew / APT                 |
| Oh My Zsh                       | Zsh framework                       |  ✅   |    ✅     | Official installer             |
| FiraCode Nerd Font              | Terminal font with icons            |  ✅   |    ✅     | Homebrew cask / download       |
| **Browser Integration**         |                                     |       |           |                                |
| `xdg-open` (xdg-utils)          | Open URLs/files in default browser  |  ❌   |    ✅     | APT                            |
| `wslview` (wslu)                | Open URLs in Windows browser (WSL)  |  ❌   |    ✅⁵    | APT / shim fallback            |
| **Linux/WSL Only**              |                                     |       |           |                                |
| `build-essential`               | Core dev tools (gcc, make)          |  ❌   |    ✅     | APT                            |
| `zsh`                           | Z Shell                             |  ✅⁴  |    ✅     | built-in / APT                 |
| `xclip`                         | Clipboard support                   |  ❌   |    ✅     | APT                            |
| `fontconfig`                    | Font management                     |  ❌   |    ✅     | APT                            |
| `bc`                            | Calculator                          |  ✅   |    ✅     | Homebrew / APT                 |
| `lsof`                          | Port/process scanner                |  ✅⁴  |    ✅     | built-in / APT                 |
| `cmatrix`                       | Terminal matrix animation           |  ✅   |    ✅     | Homebrew / APT                 |
| `telnet`                        | Telnet client (starwars easter egg) |  ✅   |    ✅     | Homebrew / APT                 |
| `curl` / `wget`                 | HTTP utilities                      |  ✅⁴  |    ✅     | built-in / APT                 |
| Linuxbrew                       | Homebrew for Linux                  |  ❌   |    ✅     | Official installer             |

> ¹ Installed as `batcat` on Debian/Ubuntu; symlinked to `bat` automatically  
> ² Installed as `fdfind` on Debian/Ubuntu; symlinked to `fd` automatically  
> ³ Linux uses `trash-put` from trash-cli (APT)  
> ⁴ Pre-installed or bundled with the OS  
> ⁵ On WSL distros where `wslu` is not in apt repos, a lightweight shim is installed to `~/.local/bin/wslview`

---

## 📖 Command Reference

Type `help` in your terminal to see this list live, or `dotdoctor` to check system health.

### 📂 Files & Navigation

| Command                   | Description                                              | WSL | Linux | macOS |
| ------------------------- | -------------------------------------------------------- | :-: | :---: | :---: |
| `cd`                      | Smart directory jumping (Zoxide)                         | ✅  |  ✅   |  ✅   |
| `up <N>`                  | Go up N directory levels                                 | ✅  |  ✅   |  ✅   |
| `..` / `~` / `-`          | Up one, Home, Previous directory                         | ✅  |  ✅   |  ✅   |
| `ls` / `ll` / `lt`        | Modern ls with icons (Eza)                               | ✅  |  ✅   |  ✅   |
| `lsh` / `llh` / `lth`     | Same as above, includes hidden files                     | ✅  |  ✅   |  ✅   |
| `cat`                     | Syntax-highlighted file viewer (Bat)                     | ✅  |  ✅   |  ✅   |
| `ccat`                    | Full Bat with line numbers and paging                    | ✅  |  ✅   |  ✅   |
| `y`                       | Terminal file explorer (Yazi)                            | ✅  |  ✅   |  ✅   |
| `fd`                      | Fast find alternative                                    | ✅  |  ✅   |  ✅   |
| `cw`                      | Switch editor window to current folder                   | ✅  |  ✅   |  ✅   |
| `backup <file>`           | Timestamped copy: `file.20260419_120000.bak`             | ✅  |  ✅   |  ✅   |
| `note <msg>`              | Quick note with timestamp (`note-config` to set path)    | ✅  |  ✅   |  ✅   |
| `note-config`             | Set persistent notes save path (stored in ~/.custom.zsh) | ✅  |  ✅   |  ✅   |
| `symlink <link> <target>` | Create a symlink                                         | ✅  |  ✅   |  ✅   |
| `extract <file> [dest]`   | Extract any archive format                               | ✅  |  ✅   |  ✅   |
| `compress <name> <files>` | Create archive (defaults to .tar.gz)                     | ✅  |  ✅   |  ✅   |

### 🔍 Search & Fuzzy Workflows (FZF)

| Command              | Description                                      | WSL | Linux | macOS |
| -------------------- | ------------------------------------------------ | :-: | :---: | :---: |
| `f` / `Alt+F`        | Fuzzy file search (CWD) → inject path at cursor  | ✅  |  ✅   |  ✅   |
| `ff` / `Alt+Shift+F` | Fuzzy file search (HOME) → inject path at cursor | ✅  |  ✅   |  ✅   |
| `h` / `Ctrl+H`       | Fuzzy history search → inject command at prompt  | ✅  |  ✅   |  ✅   |
| `hh`                 | Fuzzy history search → copy to clipboard         | ✅  |  ✅   |  ✅   |
| `rt` / `rtt`         | Interactive trash restore (FZF selector)         | ✅  |  ✅   |  ❌   |

### 🐙 Git & GitHub

| Command               | Description                                  | WSL | Linux | macOS |
| --------------------- | -------------------------------------------- | :-: | :---: | :---: |
| `lg`                  | Open Lazygit TUI                             | ✅  |  ✅   |  ✅   |
| `gs`                  | `git status -sb` (short branch status)       | ✅  |  ✅   |  ✅   |
| `gd` / `gds`          | Git diff / diff staged                       | ✅  |  ✅   |  ✅   |
| `gdss`                | Diff staged (side-by-side via delta)         | ✅  |  ✅   |  ✅   |
| `gb` / `gba`          | List branches / all branches                 | ✅  |  ✅   |  ✅   |
| `ga`                  | `git add --all`                              | ✅  |  ✅   |  ✅   |
| `gl`                  | Beautiful graph log (last 15 commits)        | ✅  |  ✅   |  ✅   |
| `gu`                  | Undo last commit (keeps changes staged)      | ✅  |  ✅   |  ✅   |
| `gam`                 | Amend last commit (with confirmation)        | ✅  |  ✅   |  ✅   |
| `gpf`                 | Force push with lease (with RED warning)     | ✅  |  ✅   |  ✅   |
| `gr`                  | Git Redo — fuzzy time machine via reflog     | ✅  |  ✅   |  ✅   |
| `pr` / `prs`          | Create PR (web) / List open PRs              | ✅  |  ✅   |  ✅   |
| `ghv` / `ghme`        | View repo on GitHub / List my PRs            | ✅  |  ✅   |  ✅   |
| `gstats`              | GitHub dashboard (notifs, mentions, reviews) | ✅  |  ✅   |  ✅   |
| `ghn` / `ghm` / `ghr` | Notifications / Mentions / Review requests   | ✅  |  ✅   |  ✅   |
| `help git`            | Git prompt symbol cheat sheet                | ✅  |  ✅   |  ✅   |

### 🌐 Network & System

| Command           | Description                                 | WSL | Linux | macOS |
| ----------------- | ------------------------------------------- | :-: | :---: | :---: |
| `myip`            | Show public IPv4 and IPv6                   | ✅  |  ✅   |  ✅   |
| `localip`         | Show local LAN IP                           | ✅  |  ✅   |  ✅   |
| `port [num]`      | List listeners or check specific port       | ✅  |  ✅   |  ✅   |
| `kill-port <num>` | Kill process on a port                      | ✅  |  ✅   |  ✅   |
| `memhog`          | Top 15 memory-consuming processes           | ✅  |  ✅   |  ✅   |
| `top`             | Interactive monitor (btm preferred)         | ✅  |  ✅   |  ✅   |
| `http`            | HTTP client (xh)                            | ✅  |  ✅   |  ✅   |
| `copy` / `cpwd`   | Copy stdin / copy current path to clipboard | ✅¹ |  ✅²  |  ✅³  |
| `df` / `free`     | Disk / Memory usage (human-readable)        | ✅  |  ✅   |  ✅   |
| `weather`         | 3-day ASCII weather forecast                | ✅  |  ✅   |  ✅   |
| `path`            | Pretty-print $PATH one entry per line       | ✅  |  ✅   |  ✅   |
| `please`          | Re-run last command with sudo               | ✅  |  ✅   |  ✅   |
| `reload` / `x`    | Reload shell / Exit terminal                | ✅  |  ✅   |  ✅   |
| `daemonize <cmd>` | Run in background with log file             | ✅  |  ✅   |  ✅   |
| `sleep <sec>`     | Cross-platform sleep                        | ✅  |  ✅   |  ✅   |

> ¹ Uses `clip.exe`  
> ² Uses `xclip`, `wl-copy`, or `xsel`  
> ³ Uses `pbcopy`

### 🗑️ Safe Deletion & Trash

| Command       | Description                     | WSL | Linux | macOS |
| ------------- | ------------------------------- | :-: | :---: | :---: |
| `rm` / `del`  | Move to trash (never permanent) | ✅  |  ✅   |  ✅   |
| `trash-list`  | List trash contents             | ✅  |  ✅   |  ❌   |
| `empty-trash` | Empty trash                     | ✅  |  ✅   |  ❌   |
| `rl`          | Alias for `trash-list`          | ✅  |  ✅   |  ❌   |
| `rt` / `rtt`  | FZF-powered trash restore       | ✅  |  ✅   |  ❌   |

### 🐍 Development & Data

| Command         | Description                               | WSL | Linux | macOS |
| --------------- | ----------------------------------------- | :-: | :---: | :---: |
| `json`          | Pretty-print JSON (jq or Python fallback) | ✅  |  ✅   |  ✅   |
| `calc <expr>`   | Calculator (bc or awk fallback)           | ✅  |  ✅   |  ✅   |
| `server [port]` | Python HTTP server (via UV)               | ✅  |  ✅   |  ✅   |
| `envup [file]`  | Load .env variables into session          | ✅  |  ✅   |  ✅   |
| `pyclean`       | Remove all Python cache/bytecode          | ✅  |  ✅   |  ✅   |
| `jq`            | JSON processor                            | ✅  |  ✅   |  ✅   |
| `yq`            | YAML processor                            | ✅  |  ✅   |  ✅   |

### 🤖 AI Guard Aliases

These aliases warn when using legacy tools and suggest modern alternatives:

| Blocked Command                    | Suggested Alternative     | Condition      |
| ---------------------------------- | ------------------------- | -------------- |
| `node`, `npm`, `npx`               | `bun run`, `bun`, `bun x` | `HAS_BUN=true` |
| `yarn`, `pnpm`                     | `bun`                     | `HAS_BUN=true` |
| `nodemon`, `ts-node`, `tsx`        | `bun --watch`, `bun`      | `HAS_BUN=true` |
| `python`, `python3`, `pip`, `pip3` | `uv run`, `uv`            | `HAS_UV=true`  |
| `venv`, `poetry`                   | `uv venv`, `uv`           | `HAS_UV=true`  |

### 🛡️ Setup & Maintenance

| Command               | Description                             | WSL | Linux | macOS |
| --------------------- | --------------------------------------- | :-: | :---: | :---: |
| `setup-terminal`      | Re-run installer (fix/update tools)     | ✅  |  ✅   |  ✅   |
| `dotdoctor`           | Health check (tools, caches, browser)   | ✅  |  ✅   |  ✅   |
| `editor-config`       | Print recommended VS Code/Kiro settings | ✅  |  ✅   |  ✅   |
| `refresh`             | Rebuild tool cache + reload shell       | ✅  |  ✅   |  ✅   |
| `hclear`              | Securely wipe terminal history          | ✅  |  ✅   |  ✅   |
| `git-setup`           | Interactive git user.name/email config  | ✅  |  ✅   |  ✅   |
| `ssh-setup`           | Generate ed25519 key + add to agent     | ✅  |  ✅   |  ✅   |
| `ssh-login`           | Start ssh-agent + load key              | ✅  |  ✅   |  ✅   |
| `ssh-test`            | Test SSH connection to GitHub           | ✅  |  ✅   |  ✅   |
| `dotfiles-share-root` | Share dotfiles with root user           | ✅  |  ✅   |  ✅   |

### 🎮 Fun & Aesthetics

| Command    | Description                             | WSL | Linux | macOS |
| ---------- | --------------------------------------- | :-: | :---: | :---: |
| `matrix`   | Falling green code (requires `cmatrix`) | ✅  |  ✅   |  ✅   |
| `starwars` | Star Wars IV in ASCII (telnet)          | ✅  |  ✅   |  ✅   |

---

## 📁 Architecture

```
~/.dotfiles/
├── init.sh                  # Master loader (sourced from .bashrc/.zshrc)
├── install.sh               # Cross-platform installer (macOS/Linux/WSL)
├── starship.toml            # Starship prompt configuration
├── custom.example.sh        # Template for personal overrides
│
├── core/
│   ├── path-utils.sh        # _path_add, _path_clean helpers
│   ├── os-detect.sh         # IS_MAC, IS_LINUX, IS_WSL detection
│   ├── paths.sh             # PATH construction (platform-aware)
│   └── history.sh           # Shell history config + hclear
│
├── plugins/
│   ├── tool-cache.sh        # HAS_* flag detection (cached)
│   ├── zoxide.sh            # Zoxide (smart cd) initialization
│   └── shell.sh             # Oh My Zsh, Starship, Zsh plugins
│
├── modules/
│   ├── archives.sh          # extract, compress
│   ├── dev.sh               # AI guards, pyclean, envup, json, calc, server
│   ├── doctor.sh            # dotdoctor health check
│   ├── dotfiles.sh          # setup-terminal, note, share-root
│   ├── editor-config.sh     # editor-config (VS Code/Kiro settings)
│   ├── fzf.sh              # f, ff, h, hh (fuzzy workflows)
│   ├── git.sh              # Git aliases + gr, gu, gam, gpf, gstats
│   ├── help.sh             # help, myhelp, help_git
│   ├── navigation.sh       # ls/ll/lt, cat, backup, cw, symlink, up
│   ├── network.sh          # myip, localip, port, kill-port
│   ├── setup-wizard.sh     # git-setup, ssh-setup, ssh-login, ssh-test
│   └── system.sh           # rm/del, copy, memhog, top, sleep, daemonize, etc.
│
├── platform/
│   ├── macos.sh            # Homebrew path, BSD ls colors
│   └── linux.sh            # GPG_TTY, GNU ls colors
│
└── test/
    ├── suite.sh            # Interactive mode test suite
    └── mock_tools.sh       # Mock binaries for testing
```

### Loading Order

1. **Core** — `path-utils.sh` → `os-detect.sh` → `paths.sh` → `history.sh`
2. **Plugins** — `tool-cache.sh` → `shell.sh` → `zoxide.sh`
3. **Modules** — All `modules/*.sh` files (alphabetical)
4. **Platform** — `macos.sh` / `linux.sh` (based on OS detection)

---

## ⚡ Performance Profiling

To measure startup time of each module:

```bash
PROFILE_DOTFILES=true source ~/.dotfiles/init.sh
```

This prints a breakdown of how long each file takes to load, helping identify bottlenecks.

---
