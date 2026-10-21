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

You only need a **bootstrap git** to clone this repo. The installer then installs the **pinned** `git` / `uv` / `gh` from `versions.toml` (14-day quarantine). Distro/Xcode git is not the final git.

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
git clone https://github.com/username/dotfiles.git ~/.dotfiles
bash ~/.dotfiles/install.sh
```

**macOS** (Xcode CLT provides bootstrap git):

```bash
xcode-select --install   # if git/curl are missing
git clone https://github.com/username/dotfiles.git ~/.dotfiles
bash ~/.dotfiles/install.sh
```

If you already cloned elsewhere, run `bash install.sh` from that tree; it copies into `~/.dotfiles` and writes `~/.zshrc`.

---

## What `install.sh` does

1. Detects platform: `macos` | `debian` | `wsl`
2. **System packages**
   - macOS: Xcode CLT if needed, Homebrew, then brew for zsh and most CLI (not git/uv/gh)
   - Debian/WSL: APT (`zsh`, bootstrap `git`, build deps, archive tools, `wslu` on WSL)
3. Sets **zsh** as the default shell
4. **Oh My Zsh** at a pinned commit + autosuggestions / syntax-highlighting
5. **FiraCode Nerd Font**
6. **Pinned tools** from `versions.toml` (skip any release **younger than 14 days**, SHA256 checked)
   - **All platforms:** `git` (built from the pinned kernel.org tarball into `~/.local`), `uv`, `gh`
   - **Linux/WSL also:** starship, ripgrep, zoxide, delta, eza, bat, xh, yq, bun, atuin, zellij
   - macOS gets the rest of those via Homebrew in step 2
7. Configures **delta** as git pager; `merge.conflictstyle` is `zdiff3` if git ≥ 2.35, else `diff3`
8. Bootstraps `~/.dotfiles` and appends the loader to `~/.zshrc`
9. Starts zsh

Pins live in `versions.toml`. `~/.local/bin` is on PATH (see `core/paths.zsh`).

---

## After install

```bash
git-setup    # git user.name + user.email
ssh-setup    # SSH key + agent
```

Optional later:

```bash
./update-versions.sh          # list pins that have a safe (≥ 14 day) upstream
./update-versions.sh --apply  # write those pins into versions.toml
bash install.sh               # install the new pins

zsh test/suite.zsh            # alias/function suite
bash ./verify-status.sh       # Starship git pills (creates .verify-status-worktree/)
refresh                       # rebuild tool caches + reload zsh
```

---

## git, uv, gh (all three OSes)

| Tool | Pin file | Install |
|------|----------|---------|
| **git** | `versions.toml` → `git` | Source tarball → `~/.local` (not apt/brew latest) |
| **uv** | `versions.toml` → `uv` | GitHub musl/darwin tarball + SHA256 |
| **gh** | `versions.toml` → `gh` | GitHub release + checksums (not apt/brew latest) |

`update-versions.sh` checks **git**, **uv**, **gh**, and the other pinned tools. It **never** installs; it only updates `versions.toml` for releases **≥ 14 days old**. Then re-run `install.sh`.

---

## Requirements the installer will not invent

- **Arch:** `x86_64` or `aarch64` / `arm64`
- **Linux:** Debian-family APT
- **Git merge style:** pinned git is 2.55.x so `zdiff3` is used once that binary is on PATH
