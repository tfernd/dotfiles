# 🚀 Dotfiles

A fast, modular, zsh-only dotfiles framework with autoloaded functions and supply chain security.

## Quick Start

```bash
git clone https://github.com/tfernd/dotfiles.git ~/.dotfiles
bash ~/.dotfiles/install.sh
```

The installer configures everything from a bare machine:

1. System packages (zsh, curl, archive tools, etc.)
2. Sets zsh as default shell + installs Oh My Zsh (pinned commit)
3. Installs FiraCode Nerd Font
4. Installs pinned CLI tools: **git, uv, gh** on Debian / WSL / macOS, plus the rest on Linux (SHA256 verified, **14-day quarantine**)
5. Bootstraps dotfiles (copies to `~/.dotfiles`, adds the loader to `~/.zshrc`)
6. Drops you into zsh

## Post-Install

```bash
git-setup    # Configure git identity (name + email)
ssh-setup    # Generate SSH key + configure agent
```

## Key Commands

### Files & Navigation

- `cd` (zoxide smart jump), `..`, `~`, `-`
- `ls`/`ll`/`lt` (eza with icons), `lsh`/`llh`/`lth` (hidden files)
- `cat` (bat with syntax highlighting)
- `extract`, `compress`

### History

- `atuin` — rich shell history with SQLite search (`Ctrl+R` / `Up`)

### Git & GitHub

- `gs`, `gd`, `gds`, `gl`, `ga`, `gp`, `gb`, `gba`
- `pr` (create PR), `prs` (list PRs), `ghv` (view repo)
- `gstat` — GitHub dashboard (PRs, reviews, repo stats)

### System & Workspace

- `zj` (zellij), `zja` (attach main), `zjs` (session picker), `zjl` (list), `zjk` (delete session), `zjd` (delete all)
- `myip`, `localip`, `port`, `kill-port`
- `sudok` (forget sudo credentials)
- `c` (clear), `x` (exit), `reload`, `path`, `ssh-login`, `ssh-test`
- `rm`/`del` (safe trash, also in AI/agent shells), `rl` (list trash), `rt` (restore), `empty-trash` (with preview)

### Development

- `http` (xh), `json` (jq), `jq`, `yq`
- `server` — quick HTTP server

### Setup & Maintenance

- `git-setup` — git identity wizard
- `ssh-setup` — SSH key wizard
- `refresh` — rebuild cache + reload (run after installing a new tool)
- `doctor` — health check of tools, configs and caches
- `help`, `help git` — cheatsheet and prompt-symbol guide
- `./update-versions.sh` — check & update pinned tool versions (14-day quarantine rule)
- `./verify-status.sh` — rebuild `.verify-status-worktree/` and print Starship git pills (merge/rebase/tag/…)

## Architecture

```
dotfiles/
├── install.sh            # Bare-metal bootstrap (run once)
├── doctor.zsh            # Health check (run via `doctor`)
├── update-versions.sh    # Bump pins in versions.toml (14-day quarantine)
├── verify-status.sh      # Visual Starship git-state verifier (creates .verify-status-worktree/)
├── versions.toml         # Pinned tool versions (14-day quarantine)
├── AGENTS.md             # Guide for AI agents / contributors editing this repo
├── config/               # Starship, Atuin, Zellij
├── core/                 # Sourced every startup (fast, minimal)
├── modules/              # Aliases + lightweight functions
│   ├── git/              # Git aliases + GitHub CLI
│   ├── files/            # ls, navigation, trash
│   ├── dev/              # HTTP, JSON
│   ├── shell/            # General aliases
│   └── system/           # Network
├── functions/            # Autoloaded (lazy) — zero startup cost
├── platform/             # Conditional: macos, debian, wsl
├── plugins/              # OMZ + Starship, zoxide, atuin, zellij (cached init)
└── test/                 # Test suite + mocks
```

## Testing

```bash
zsh -f test/suite.zsh       # aliases, flags, agent mode, compress/git helpers
bash ./verify-status.sh     # Starship git_branch / tag / DETACHED / MERGING / …
```

Prompt git pills (Starship):

- Branch pill while attached; **DETACHED** hash (+ tag) only when detached
- **Tag pill** (` vX.Y.Z`) on an attached branch whose HEAD is an exact tag
- State pills: MERGING, REBASING, PICKING, REVERTING, BISECTING, APPLYING

## AI / Agent Shells

Shells that no human types into get plain, predictable behaviour. `IS_AGENT=true`
when the shell is non-interactive, `TERM=dumb`, inside Claude Code (`CLAUDECODE`),
or `DOTFILES_AGENT=1` is set. Then:

- no Oh My Zsh, Starship or atuin hooks
- `ls` is the real `ls` (eza aliases use `--color=auto --icons=auto` everywhere)
- `cd` is the builtin (no zoxide fuzzy jumps on a mistyped path)
- `rm` **still goes to the trash**

## Supported Platforms

- macOS (Apple Silicon + Intel)
- Debian/Ubuntu Linux
- WSL2 (Debian-based)
