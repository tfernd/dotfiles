# INSTALL.md — Installation Guide

Install this zsh-only dotfiles system from a **bare machine**. Supported:

- **macOS** (Apple Silicon and Intel)
- **Debian / Ubuntu** (and Pop!_OS)
- **WSL2** (Debian-based)

Windows hosts run the dotfiles **inside WSL**, not in PowerShell.

---

## Prerequisites

- Internet
- `sudo` (Linux/WSL) or admin (macOS Homebrew / Xcode CLT)
- Enough disk for Homebrew or APT plus pinned binaries under `~/.local`

You only need a **bootstrap git** to clone this repo. The installer then installs git from the system (apt on Debian / WSL, Homebrew on macOS) and the **pinned** `uv` / `gh` from `versions.toml` (`.freshness` quarantine).

---

## Windows: WSL2 (Debian) first

PowerShell **as Administrator**:

```powershell
wsl --install -d Debian
wsl -l -v
wsl
```

Continue the Linux steps **inside that Debian WSL**.

---

## Clone and install

**Linux / WSL** (bootstrap git only):

```bash
sudo apt update && sudo apt install -y git curl
git clone <repo-url> ~/path/to/dotfiles
bash ~/path/to/dotfiles/install.sh
```

**macOS** (Xcode CLT provides bootstrap git):

```bash
xcode-select --install   # if git/curl are missing
git clone <repo-url> ~/path/to/dotfiles
bash ~/path/to/dotfiles/install.sh
```

The clone stays where it is and is used in place. If you already cloned elsewhere, run `bash install.sh` from that tree. It copies nothing; it only appends the loader to `~/.zshrc`, when needed.

---

## What `install.sh` does

1. Detects platform: `macos` | `debian` | `wsl`
2. **System packages**
   - macOS: Xcode CLT if needed, Homebrew, then brew for zsh and most CLI (not git/uv/gh)
   - Debian/WSL: APT (`zsh`, `git`, `build-essential`, archive tools, `wslu` on WSL)
3. Sets **zsh** as the default shell
4. **Oh My Zsh** at a pinned commit + autosuggestions / syntax-highlighting
5. **FiraCode Nerd Font**
6. **Pinned tools** from `versions.toml` (skip any release **younger than the number of days in `.freshness`**, SHA256 checked)
   - **All platforms:** `uv`, `gh` (pinned). `git` is not pinned: step 2 installs it (apt on Debian / WSL, Homebrew on macOS)
   - **Linux/WSL also:** starship, zoxide, delta, eza, bat, bun, atuin, terraform, terraform-ls, ripgrep (`rg`), fd, fzf, just, lazygit, bottom (`btm`), yazi
   - macOS gets the rest of those via Homebrew in step 2
7. Configures **delta** as git pager; `merge.conflictstyle` is `zdiff3` if git ≥ 2.35, else `diff3`
8. Wires the repo in place (no copy): appends `[ -f "<repo>/core/init.zsh" ] && source "<repo>/core/init.zsh"` to `~/.zshrc`, only when no `core/init.zsh` line exists yet
9. Starts zsh

A run prints one line per step (`▸ [1/7] System packages ..... ✅ up to date (2s)`), detail lines only for an action or a problem, then a summary (installed / upgraded / unchanged / failed, total time) and a short box with the next steps. Colour is off with `NO_COLOR` or a piped stdout. Details of the run:

- **Packages:** missing ones are found with `dpkg-query` (macOS: `brew list`). `apt-get update` and `install` (and `sudo`) run only when something is missing; `update` is skipped when the package lists are under a day old. apt output is shown only on failure.
- **Pinned tools:** a tool already at its pin prints nothing. Installs run up to 4 at a time, each with its SHA256 check, and the results print in order. `--force` reinstalls every tool and prints one line each.
- **Verification:** `doctor.zsh --quiet` runs at the end: only failures and warnings, then one pass line.

Pins live in `versions.toml`. `~/.local/bin` is on PATH (see `core/paths.zsh`). The copy in `~/.local/bin` is the one that counts: a newer copy from apt or Homebrew does not keep the pin out, and `dotdoctor clean` lists such copies for removal. A tool with no row in `versions.toml` yet is skipped until `bash update-versions.sh --apply` adds it.

---

## After install

```bash
git-setup    # git user.name + user.email
ssh-setup    # SSH key + agent
```

Optional later:

```bash
./update-versions.sh          # list pins that have a safe (past the `.freshness` window) upstream
./update-versions.sh --apply  # write those pins into versions.toml
bash install.sh               # install the new pins

zsh -f test/suite.zsh         # alias/function suite
bash ./verify-status.sh       # Starship git pills (creates .verify-status-worktree/)
refresh                       # rebuild tool caches + reload zsh
```

---

## Updating

The clone is the install, so an update is a pull:

```bash
cd ~/path/to/dotfiles && git pull
```

- Edits load in a new shell, or after `exec zsh`. No re-install is needed.
- New pins in `versions.toml`: run `bash install.sh` (add `--force` to reinstall tools already at their pin). `bash install.sh --tools-only` installs only the pinned tools (no apt, no sudo); `dotdoctor update --apply` uses it.
- Older installs put their own git build in `~/.local`, which hides the system git. While `~/.local/bin/git` exists, `install.sh` stops with a ❌. Remove `~/.local/bin/git`, `~/.local/libexec/git-core` and `~/.local/share/git-core` (if they exist), then run `bash install.sh` again.
- Moved the clone? `install.sh` does not rewrite the loader in `~/.zshrc`; it only checks that a `core/init.zsh` line exists. Edit that line to the new path.
- Older installs had a copy in `~/.dotfiles`; it is no longer used and can be removed. If `~/.zshrc` still sources that copy, point its loader line at the clone (or delete that line and re-run `bash install.sh`).

---

## git, uv, gh (all three OSes)

| Tool | Pin file | Install |
|------|----------|---------|
| **git** | not pinned | apt (Debian / WSL), Homebrew (macOS) |
| **uv** | `versions.toml` → `uv` | GitHub musl/darwin tarball + SHA256 |
| **gh** | `versions.toml` → `gh` | GitHub release + checksums (not apt/brew latest) |

`update-versions.sh` checks **uv**, **gh**, and the other pinned tools. It **never** installs; it only updates `versions.toml` for releases **past the `.freshness` window**. Then re-run `install.sh`.

---

## Requirements the installer will not invent

- **Arch:** `x86_64` or `aarch64` / `arm64`
- **Linux:** Debian-family APT
- **Git merge style:** `zdiff3` only when git is ≥ 2.35; an older git gets `diff3` (see item 7 above)
