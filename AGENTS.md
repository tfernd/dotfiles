# AGENTS.md — Guide for AI agents and contributors

This file is the contract for anyone (human or AI) editing this repository.
Read it fully before changing anything. If the code and this file disagree,
fix whichever is wrong in the same change.

---

## 1. What this repo is, and the goal

A **zsh-only** dotfiles framework for one person's machines: **macOS**,
**Debian/Ubuntu**, and **WSL2 (Debian)**. It installs a curated set of CLI
tools and wires them into zsh with aliases, small functions and a Starship
prompt.

The goals, in priority order:

1. **Safe.** Nothing in the shell should destroy data by accident. `rm` goes to
   the trash in *every* shell, AI/agent shells included. Tools are installed
   from pinned versions with SHA256 checks and a 14-day quarantine.
2. **Predictable for agents.** Shells that no human types into (AI agents,
   scripts, `TERM=dumb`) get plain output and builtin behaviour: real `ls`,
   builtin `cd`, no prompt or history hooks. See §4.
3. **Fast startup.** Expensive `init` output (starship, zoxide, atuin, gh
   completions, tool detection) is cached in `~/.cache` and only regenerated
   when its source changes. Larger helpers are autoloaded (zero startup cost).
4. **Small and readable.** Prefer deleting a feature over keeping one that
   doesn't work. Every command should be discoverable via `help` and README.

Non-goals: bash support, Windows-native (PowerShell) support, non-Debian Linux.

---

## 2. Repository layout

```
dotfiles/
├── install.sh          # Bare-metal bootstrap (bash). Installs packages + pinned tools,
│                       # copies the repo to ~/.dotfiles, adds the loader to ~/.zshrc.
├── doctor.zsh          # Health check (alias: doctor). Exit 1 if a required tool/flag is missing.
├── update-versions.sh  # Proposes/applies newer pins in versions.toml (≥ 14 days old only).
├── verify-status.sh    # Visual Starship git-pill verifier (builds .verify-status-worktree/).
├── versions.toml       # Pinned tool versions + release dates (source of truth for install.sh).
├── config/             # App configs deployed to ~/.config: starship.toml, atuin.toml, zellij/
├── core/               # Sourced on EVERY startup, in a fixed order (see §3)
│   ├── init.zsh        # The loader. ~/.zshrc sources this file.
│   ├── platform.zsh    # DOTFILES_PLATFORM, IS_MAC/IS_LINUX/IS_WSL, IS_AGENT
│   ├── paths.zsh       # PATH: Homebrew first, then ~/.bun, ~/.cargo, ~/.local/bin (pins win)
│   ├── history.zsh     # zsh history options
│   └── tool-cache.zsh  # HAS_* flags, cached in ~/.cache/dotfiles_tools; `refresh` alias
├── plugins/            # Integrations with cached init output
│   ├── shell.zsh       # Oh My Zsh (or plain compinit) + gh completions + Starship
│   ├── zoxide.zsh      # zoxide + smart `cd` (humans only)
│   ├── atuin.zsh       # atuin history (humans only)
│   └── zellij.zsh      # zellij config deploy + zj/zja/zjs/zjk/zjl/zjd
├── modules/            # Aliases + small functions, sourced recursively (modules/**/*.zsh)
│   ├── dev/            # http (xh), json
│   ├── files/          # listing (ls/ll/cat), navigation (.. ~ -), trash (rm/del/rl/rt)
│   ├── git/            # git aliases, gh aliases
│   ├── shell/          # general aliases, clipboard (copy/cpwd)
│   └── system/         # network (myip, localip, port, kill-port)
├── platform/           # Per-platform overrides: macos.zsh, debian.zsh, wsl.zsh
├── functions/          # Autoloaded functions: one file per function, file name = function name
└── test/
    ├── suite.zsh       # Main test suite (mocks every tool; runs non-interactively)
    ├── mock_tools.zsh  # Creates fake binaries in /tmp/dotfiles_mock_bin
    └── uninstall.sh    # DESTRUCTIVE helper to simulate a bare machine. Never run it casually.
```

`.kiro/` holds hooks/scripts for the Kiro editor (smart commit, PR review). They are
editor tooling, not part of the shell; leave them alone unless asked.

---

## 3. Load order (core/init.zsh)

1. `core/platform.zsh` → `core/paths.zsh` → `core/history.zsh` → `core/tool-cache.zsh`
2. `plugins/shell.zsh` → `plugins/zoxide.zsh` → `plugins/atuin.zsh` → `plugins/zellij.zsh`
3. Every `modules/**/*.zsh` (alphabetical by path)
4. `platform/$DOTFILES_PLATFORM.zsh`
5. `functions/*` are added to `fpath` and `autoload -Uz`'d (loaded on first call)

Consequences:

- Anything that needs `HAS_*` or `IS_AGENT` must load **after** step 1. All plugins and
  modules can rely on them.
- `_path_add` (from `paths.zsh`) exists until the end of init, then is `unfunction`ed.
  It **prepends**. To append (e.g. slow Windows paths on WSL), use `path+=(...)`.
- A new plugin must be added to the list in `core/init.zsh`; a new module is picked up
  automatically by the glob. A new function file is picked up automatically.
- `.zsh` files here are **sourced**, not run. `local` at the top level of a sourced file
  does not create a local scope — the variable leaks into the user's session. `unset`
  temporaries at the end of the file (see `plugins/zellij.zsh`, `core/tool-cache.zsh`).

---

## 4. Agent / non-interactive mode (`IS_AGENT`)

`core/platform.zsh` sets `IS_AGENT=true` when **any** of these hold:

- the shell is not interactive (`[[ ! -o interactive ]]`) — scripts, `zsh -c`, test suite
- `TERM=dumb` (many AI terminals)
- `CLAUDECODE` is set (Claude Code)
- `DOTFILES_AGENT` is set (manual override, e.g. for other agents)

When `IS_AGENT=true`:

| Feature | Human shell | Agent shell |
|---|---|---|
| Oh My Zsh, Starship, gh completions | loaded | skipped (`PROMPT='%# '`) |
| atuin history hooks | loaded | skipped |
| `ls` | `eza --icons=auto --color=auto …` | real `ls` (no alias) |
| `ll`, `lt`, `lsh`, `llh`, `lth` | eza | eza (still `--color=auto`, plain when piped) |
| `cd` | zoxide wrapper (fuzzy jump if the path doesn't exist) | builtin `cd` |
| `rm`, `del` | **trash** | **trash** — deliberately identical |

Rules:

- **Never** make output in agent shells depend on a TTY-only feature. Use
  `--color=auto`, never `--color=always`, in any alias an agent might hit.
- **Never** weaken the `rm` → trash wrapper for agents. The owner explicitly wants
  agent shells unable to permanently delete through `rm`. (It is only a shell
  function: `command rm`, `/bin/rm`, scripts and `find -delete` bypass it. Real
  enforcement belongs in the agent's own permission settings.)
- Gate new "human UX" features (prompts, key bindings, fuzzy pickers, anything that
  reads from `/dev/tty`) behind `[[ "$IS_AGENT" != "true" ]]`.

---

## 5. Conventions

### Shell style

- zsh only. Use `[[ ... ]]`, `(( ... ))`, `$+commands[x]`, `$+functions[x]`,
  `${var:t}`, `$match[1]` (not `BASH_REMATCH`), glob qualifiers like `(N)`.
  `install.sh`, `update-versions.sh`, `verify-status.sh` and `test/uninstall.sh`
  are the exceptions: they are **bash** scripts (they run before zsh exists).
- Feature flags are strings: `[[ "$HAS_EZA" == "true" ]]`, never `if $HAS_EZA`.
- Prefer `(( $+commands[tool] ))` over `command -v` in `.zsh` files.
- Section headers use the existing `# ====` banner + `# --- Name ---` style; keep
  comments short and about *why*.
- User-facing messages use the existing emoji + ANSI colour style
  (`❌` error, `✅` success, `⚠️` confirmation, `📝 Usage:`).
- Destructive helpers ask `(y/N)` first and report failure honestly: print ✅ only
  when the command actually succeeded, and `return 1` on failure.

### Where new things go

| You are adding… | Put it in |
|---|---|
| A one-line alias | the matching `modules/<area>/*.zsh` |
| A small function (< ~15 lines) used often | `modules/<area>/*.zsh` |
| A larger or rarely used function | `functions/<name>` (autoloaded) |
| Integration with a tool's `init` output | `plugins/<tool>.zsh` + add it to `core/init.zsh` |
| Platform-only behaviour | `platform/<platform>.zsh` |
| Config for an app | `config/` + deploy it in `install.sh` (and plugin self-heal if needed) |

### Autoloaded function files (`functions/<name>`)

- The file **is the function body**. Do not wrap it in `function name() { … }`.
- Use `return`, never `exit` (an `exit` would close the user's shell). Existing files
  use `return 1 2>/dev/null || exit 1` only where they may also be run as scripts.
- Declare variables with `local`.
- The function is not loaded until first call, so the test suite checks it with
  `assert_defined` (autoload stubs count as defined).

### Caching pattern (startup speed)

Plugins cache generated init code in `~/.cache/<tool>_init.zsh` with a trailing
`#hash:<mtime-size>` line and regenerate when the hash no longer matches:

```zsh
(umask 077; tool init zsh > "$_CACHE"; echo "#hash:$_HASH" >> "$_CACHE")
```

- Write caches inside a `( umask 077; … )` **subshell** so the user's umask is never changed.
- The tool-detection cache (`~/.cache/dotfiles_tools`) is keyed only on
  `core/tool-cache.zsh`'s mtime and `$OSTYPE`. Installing a new tool does **not**
  invalidate it: the user runs `refresh`. Any new cache file must also be added to
  the `refresh` alias.

### Startup must stay side-effect light

Startup code runs in every shell, including every agent command. It may copy a
config file into `~/.config` when it differs (existing self-heal pattern) and write
caches. It must **not**: use the network, call `sudo`, prompt for input, or print
output in agent shells.

---

## 6. Tools, pins and the 14-day quarantine

`versions.toml` is the source of truth:

```toml
[tools]
eza = { version = "0.23.5", released = "2026-07-09" }
```

- **Never** pin a release younger than **14 days** (supply-chain quarantine).
  `install.sh` refuses it; `update-versions.sh` only proposes releases ≥ 14 days old.
- Every downloaded binary must be **SHA256 verified** (`_install_bin` in `install.sh`:
  a checksum URL, or the GitHub release asset digest). Never add a `curl | sh` install.
- `git`, `uv`, `gh` are pinned on **all** platforms (installed into `~/.local`).
  On macOS the other tools come from Homebrew; on Linux/WSL they are pinned binaries.
- `~/.local/bin` must stay **ahead** of Homebrew and system paths in `PATH`
  (`core/paths.zsh`), so the pins win. Don't re-prepend brew paths anywhere else.

### Checklist: adding a new tool `foo`

1. `versions.toml`: add `foo = { version = "...", released = "YYYY-MM-DD" }` (≥ 14 days old).
2. `update-versions.sh`: add `["foo"]="owner/repo"` to `REPOS`.
3. `install.sh`: brew formula (macOS list) and/or an `_ensure "foo" ...` block with a checksum source.
4. `core/tool-cache.zsh`: `export HAS_FOO=$(has_tool foo)`.
5. Aliases/functions: gated on `[[ "$HAS_FOO" == "true" ]]`, in the right module.
6. `doctor.zsh`: `require_cmd foo` / `require_flag HAS_FOO` / `require_shell <alias>`.
7. `test/mock_tools.zsh`: add `foo` to `TOOLS`; `test/suite.zsh`: assert the flag and aliases.
8. `functions/help` and `README.md` (Key Commands).

---

## 7. Testing

```bash
zsh -f test/suite.zsh       # main suite — must end with "0 Failed"
bash ./verify-status.sh     # only when touching config/starship.toml (needs real starship)
zsh doctor.zsh              # on a real machine, after install changes
```

How the suite works:

- It sets `HOME=/tmp/dotfiles_test_home`, generates mock binaries for every tool in
  `/tmp/dotfiles_mock_bin`, prepends them to `PATH`, then sources `core/init.zsh`.
- It runs **non-interactively**, so `IS_AGENT=true` inside it. Human-mode behaviour is
  tested by spawning `zsh -f -i -c` with `CLAUDECODE` unset and `TERM=xterm-256color`
  (see "Agent mode" tests). Copy that pattern for new human-only features.
- Inside the suite `rm` is the trash wrapper and `cat` is aliased to the `bat` mock.
  Use `command rm` / `command cat` (or `print -r --`) for test setup and cleanup.
- Use the `assert_eq` / `assert_defined` / `assert_var` helpers; increment
  `test_passed` / `test_failed` only through them.
- Use paths under `/tmp/test_*` and clean them up with `command rm -rf`.

Every bug fix gets a regression test that **fails on the old code**. Verify that by
temporarily restoring the old file (`git show HEAD:path > path`), running the suite,
and putting the fix back.

---

## 8. Documentation that must stay in sync

When you add, rename or remove a command, update **all** of:

- `README.md` — Key Commands and Architecture tree
- `functions/help` — the in-shell cheatsheet
- `INSTALL.md` — if install steps, pins or platforms changed
- `doctor.zsh` — if it's a tool or a promised integration
- `test/suite.zsh` — `assert_defined` + a functional test where possible
- this file — if you changed structure, load order, conventions or rules

The canonical clone URL is `https://github.com/tfernd/dotfiles.git`.

---

## 9. Don'ts (things that have bitten this repo before)

- Don't use `--color=always` or bare `--icons` in aliases (breaks piped/agent output).
- Don't override core commands (`sleep`, `top`, `python`, …) with "smart" wrappers;
  `rm`/`del` → trash is the one intentional exception.
- Don't use `setopt local_options` outside a function — it has no effect there and
  leaks the option into the session. Use glob qualifiers (`*(N)`) instead.
- Don't combine `INC_APPEND_HISTORY` with `SHARE_HISTORY` (zsh docs: pick one).
- Don't use `BASH_REMATCH` (zsh uses `$match`), `[ a == b ]` (use `[[ ]]`), or
  `ls $pattern` to expand a glob held in a variable (zsh doesn't glob parameters).
- Don't run `test/uninstall.sh` unless the user explicitly asks — it deletes tools and configs.
- Don't commit generated artifacts: `.verify-status-worktree/`, caches, `*.log`, `*.bak`.

---

## 10. Commits

Conventional commits, matching the history: `feat(scope): …`, `fix: …`,
`refactor(scope): …`, `docs: …`, `test: …`. Scopes are the area names
(`install`, `git`, `files`, `zellij`, `history`, …). One logical change per commit;
run `zsh -f test/suite.zsh` before committing.
