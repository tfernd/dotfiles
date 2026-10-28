# 🚀 Dotfiles

A fast, modular, zsh-only dotfiles framework with autoloaded functions and supply chain security.

## Quick Start

```bash
git clone <repo-url> ~/path/to/dotfiles
bash ~/path/to/dotfiles/install.sh
```

The clone is the install. Nothing is copied: `~/.zshrc` loads `core/init.zsh` from wherever you cloned, so edits take effect in a new shell (or `exec zsh`) with no re-install.

The installer configures everything from a bare machine:

1. System packages (zsh, curl, archive tools, etc.)
2. Sets zsh as default shell + installs Oh My Zsh (pinned commit)
3. Installs FiraCode Nerd Font
4. Installs git from the system (apt on Debian / WSL, Homebrew on macOS) and the pinned CLI tools: **uv, gh** on Debian / WSL / macOS, plus the rest on Linux (SHA256 verified, **`.freshness` quarantine**)
5. Wires dotfiles in place: appends the loader to `~/.zshrc`, only if no `core/init.zsh` line is there yet
6. Drops you into zsh

## Post-Install

```bash
git-setup    # Configure git identity (name + email)
ssh-setup    # Generate SSH key + configure agent
```

Changed a file in the repo? It loads in the next shell (or `exec zsh`). Tool pins live in `versions.toml`; `./update-versions.sh --apply` bumps them.

## Key Commands

### Files & Navigation

- `cd` (zoxide smart jump), `..`, `~`, `-`
- `ls` is always the plain, real `ls`; the colourful listing is `l` (what `ls` used to be); the eza views are `ll`/`lt` (long, tree; with icons), `lsh`/`llh`/`lth` (same, hidden files)
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
- `dotdoctor check` — installed vs pinned versions, and known advisories from `versions.toml [fixes]` (`--latest` also asks GitHub for releases past the quarantine; `--advisories` asks OSV.dev about the tools in `versions.toml [osv]`, the only network call and it sends only the package name and version)
- `dotdoctor scan` — local indicators of compromise (start-up items, listeners, connections to addresses outside your network, processes, shell hooks, setuid). `--facts`, `--save` and `--diff` make it reproducible: a saved baseline in `~/.local/state/dotdoctor` shows what changed. `--save` keeps the previous baseline as `baseline.tsv.prev`. `--deep` verifies package files on Linux
- `dotdoctor update` — what can be updated or removed (apt, snap, Flatpak, firmware via fwupd, uv, rustup, bun and npm globals, Homebrew, old kernels). It prints the commands in three groups: *No root needed*, *Need your password* (sudo) and *Deletes files* (old kernels, Flatpak unused runtimes). `--apply` asks before each step: a letter, then Enter: y runs it, n skips it, q stops, and `a` runs the rest without asking, except steps that delete files. It also offers to bump the pins (`update-versions.sh --apply`) and to run `install.sh --tools-only` (the pinned tools only: no apt, no sudo) when a tool is behind its pin. Each step shows one line; its output goes to `~/.cache/dotdoctor/update.log`, and a failed step shows its last lines. In a terminal, `dotdoctor check` offers it when it finds something (`y` asks before each step, `a` runs them all), then checks again and shows only what still needs attention
- `dotdoctor clean` — dangling user systemd units, broken git URL rewrites, Brotli-affected Python packages, copies of pinned tools that apt or Homebrew installed next to the pinned one, and old `name.backup-*` copies that self-updates left behind. Report only; `--apply` moves what you confirm into `~/.local/state/dotdoctor/removed/` instead of deleting it
- `help`, `help git` — cheatsheet and prompt-symbol guide
- `./update-versions.sh` — check & update pinned tool versions (`.freshness` quarantine rule)
- `./verify-status.sh` — rebuild `.verify-status-worktree/` and print Starship git pills (merge/rebase/tag/…)

## Architecture

```
dotfiles/
├── install.sh            # Bare-metal bootstrap (re-runnable; wires the repo in place)
├── doctor.zsh            # Health check (run via `doctor`)
├── update-versions.sh    # Bump pins in versions.toml (`.freshness` quarantine)
├── verify-status.sh      # Visual Starship git-state verifier (creates .verify-status-worktree/)
├── versions.toml         # Pinned tool versions (`.freshness` quarantine)
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
│   └── dotdoctor*        # `dotdoctor` + helpers: check, scan, update, clean, osv
├── platform/             # Conditional: macos, debian, wsl
├── plugins/              # OMZ + Starship, zoxide, atuin, zellij (cached init)
└── test/                 # Test suite + mocks
```

The repo loads in place: `~/.zshrc` sources `<repo>/core/init.zsh`, so there is no copy and no sync step.

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
- `ls` is the plain, real `ls` in every shell (never aliased); the eza views `l`, `ll`, `lt`, `lsh`, `llh`, `lth` stay available with `--color=auto --icons=auto`
- `cd` is the builtin (no zoxide fuzzy jumps on a mistyped path)
- `rm` **still goes to the trash**

## Supported Platforms

- macOS (Apple Silicon + Intel)
- Debian/Ubuntu Linux
- WSL2 (Debian-based)
