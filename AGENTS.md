# AGENTS.md — Guide for AI agents and contributors

The contract for anyone (human or AI) editing this repo. Read it before changing anything. If the code and this
file disagree, fix whichever is wrong in the same change. Cited names are greppable; line numbers are not kept here.

## 1. What this is

A **zsh-only** dotfiles framework for one person's machines: **macOS**, **Debian/Ubuntu**, **WSL2 (Debian)**. It
installs pinned CLI tools and wires them into zsh with aliases, small functions and a Starship prompt. The repo loads in
place, wherever it is cloned.

Goals, in priority order: **safe** (`rm` goes to the trash in every shell, tools are pinned with SHA256 checks and a
`.freshness` quarantine) → **predictable for agents** (plain output, builtin behaviour, §4) → **fast startup** (expensive
`init` output cached in `~/.cache`, big helpers autoloaded) → **small and readable** (delete a broken feature rather
than keep it; every command is in `help` and README).

Non-goals: bash support, native Windows, non-Debian Linux.

## 2. Layout

```
install.sh          bare-metal bootstrap (bash); --force, --no-shell, --tools-only
Makefile            task runner (`make help`): install setup tools doctor test lint check versions refresh clean; holds no logic
doctor.zsh          health check (exit 1 if a required tool/flag is missing)
update-versions.sh  proposes/applies newer pins past the `.freshness` window; REPOS maps tool -> owner/repo
verify-status.sh    visual Starship git-pill check (bash; builds .verify-status-worktree/)
versions.toml       pins + release dates ([tools] [fonts] [fixes] [osv]); .freshness = quarantine days
config/             app configs deployed to ~/.config (starship.toml, atuin.toml)
core/               every startup, fixed order: platform, paths, history, tool-cache; init.zsh is the loader
plugins/            cached tool integrations: shell (OMZ/compinit, Starship), zoxide, atuin
modules/            aliases + small functions, sourced recursively: files shell system
platform/           debian.zsh wsl.zsh (optional per-platform file; none for macos)
functions/          autoloaded, one file per function; dotdoctor{,-lib,-check,-scan,-update,-clean,-osv}, help, ...
test/               suite.zsh (mocks every tool), mock_tools.zsh, uninstall.sh (DESTRUCTIVE: never run unasked)
```

`.kiro/` is editor tooling, not shell: leave it alone unless asked.

## 3. Load order (`core/init.zsh`)

1. `core/platform.zsh` → `paths.zsh` → `history.zsh` → `tool-cache.zsh`
2. `plugins/shell.zsh` → `zoxide.zsh` → `atuin.zsh`
3. every `modules/**/*.zsh`, alphabetical by path
4. `platform/$DOTFILES_PLATFORM.zsh`
5. `functions/*` onto `fpath`, `autoload -Uz`'d (loaded on first call)

- Anything needing `HAS_*` or `IS_AGENT` loads after step 1. A new plugin must be added to the list in `core/init.zsh`;
  modules and function files are picked up by glob.
- `_path_add` (paths.zsh) **prepends** and is `unfunction`ed at the end of init. To append, use `path+=(...)`.
- `.zsh` files are **sourced**: a top-level `local` leaks into the user's session. `unset` temporaries at the end.
- An edit takes effect in a new shell (`exec zsh`); no re-install.

## 4. Agent / non-interactive mode (`IS_AGENT`)

`core/platform.zsh` sets `IS_AGENT=true` when the shell is non-interactive, `TERM=dumb`, `CLAUDECODE` is set, or
`DOTFILES_AGENT` is set.

| | Human shell | Agent shell |
|---|---|---|
| Oh My Zsh, Starship, gh completions, atuin hooks | loaded | skipped (`PROMPT='%# '`) |
| `ls` | real `ls`, never aliased (listing.zsh removes OMZ's alias) | same |
| `l ll lt lsh llh lth` | eza when installed, else plain `ls` (`lt`/`lth` absent) | same, `--color=auto` |
| `cat` | `bat --style=plain --paging=never` when installed | same |
| `cd` | zoxide wrapper when installed | builtin |
| `rm`, `del` | **trash** | **trash**, deliberately identical |

- Never make agent-shell output depend on a TTY: `--color=auto`, never `--color=always` or bare `--icons`.
- Never weaken `rm` → trash for agents. `rm`/`del` are one function in `modules/files/trash.zsh` on every machine: one
  guard refuses `/`, `$HOME`, `.`, `..` and unknown options, then it calls `trash-put`, else `trash`; with neither, agent
  shells refuse and human shells get `command rm -i` without `-f`. It uses only builtins and
  `command trash-put`/`command trash`, because an agent shell once had `rm` but not its helper. `command rm`, `/bin/rm`,
  scripts and `find -delete` bypass it; real enforcement is the agent's permission settings.
- Gate human-UX features (prompts, key bindings, fuzzy pickers, anything reading `/dev/tty`) behind `[[ "$IS_AGENT" != "true" ]]`.

## 5. Conventions

**Shell style.** zsh only (`install.sh`, `update-versions.sh`, `verify-status.sh`, `test/uninstall.sh` are bash). Use
`[[ ]]`, `(( ))`, `$+commands[x]`, `$match[1]`, `(N)` qualifiers. Feature flags are strings: `[[ "$HAS_EZA" == "true" ]]`.
Section headers use the existing `# ====` / `# --- Name ---` style. Comments: `harness:comments` is the keep/delete
test; match the density of the surrounding file; comment a shell trap with its symptom. Messages use the emoji + ANSI
style (`❌` error, `✅` success, `⚠️` confirm, `📝 Usage:`). Destructive helpers ask `(y/N)`, print ✅ only when the
command succeeded, and `return 1` on failure.

**Where new things go.** One-line alias or small (< ~15 lines) frequent function → `modules/<area>/*.zsh`. Larger or
rare function → `functions/<name>`. Tool `init` integration → `plugins/<tool>.zsh` + `core/init.zsh`. Platform-only →
`platform/`. App config → `config/` + deploy in `install.sh`.

**Autoloaded function files.** The file is the body; no `function name() {}` wrapper. `return`, never `exit` (it would
close the shell). `local` for every variable, once per name per function (a repeat prints `x=<value>`).

**Caching.** Plugins cache generated init in `~/.cache/<tool>_init.zsh` with a trailing `#hash:<mtime-size>` line and
regenerate when it changes. Write in a `( umask 077; … )` subshell. The tool-detection cache (`~/.cache/dotfiles_tools`)
is keyed on `core/tool-cache.zsh` only: a new tool needs `refresh`. A new cache file must join the `refresh` alias.

**Startup is side-effect light.** Every shell, agent ones included, runs it. It may copy a config file when it differs
and write caches. It must not use the network, call `sudo`, prompt, or print output in agent shells.

**Boundaries.**
- No git write (`commit`, `push`, `reset`, `checkout`, …) unless the owner asks; the suite's own git in /tmp is fine.
- No `sudo`, and no `apt`/`snap`/`flatpak` installs: print the command for the owner.
- No new dependency or tool without the owner's yes.
- No network by agents (`curl`, `wget`, `git fetch`, `gh api`, package-manager lookups). Repo commands that use it are
  fine when the owner asks: `myip`, `dotdoctor check --latest|--advisories`, `dotdoctor update`.
- Never read a credential file (`auth.json`, tokens): `stat -c '%s %a' FILE` (macOS `stat -f '%z %Lp'`), never `cat`.

## 6. Tools, pins and the `.freshness` quarantine

`versions.toml [tools]` is the source of truth: `eza = { version = "0.23.5", released = "2026-07-09" }`.

- **Never** pin a release younger than `.freshness` days. `install.sh` refuses it; `update-versions.sh` proposes only
  releases past it, picking the highest version (not the newest date). The quarantine applies to `[fixes]` too; do not
  override it without the owner's say-so.
- `[fixes]` lists fixed releases per known advisory (`fixed`, `released`, `affected`); `dotdoctor check` fails an
  installed version inside `affected`. `[osv]` maps a tool to its OSV.dev package for `check --advisories`.
  `install.sh` and `update-versions.sh` read pins from `[tools]` and `[fonts]` only, because `[fixes]` and `[osv]`
  reuse tool names.
- Every binary, archive and font `install.sh` downloads gets a **SHA256 check** (`_install_bin`: checksum URL or the
  GitHub release asset digest; the font). Exceptions: Oh My Zsh/plugin git clones and the Homebrew bootstrap. **Never**
  add a `curl | sh` install.
- `uv` and `gh` are pinned on all platforms (in `~/.local`); `git` comes from apt/Homebrew and `install.sh` never builds
  it. Other tools: Homebrew on macOS, pinned binaries on Linux/WSL.
- `~/.local/bin` stays **ahead** of Homebrew and system paths (`core/paths.zsh`), so the pins win. The copy there **is**
  the pin (`_ensure` looks only at it); `dotdoctor clean` lists other copies. A `git` in `~/.local/bin` would hide the
  system one: `install.sh` stops on it.
- `dotdoctor` stays portable (Linux + macOS), hard-codes no account names, machine paths or vendor names, reports
  checks a platform lacks as skipped, and writes the home folder as `~` in `scan --facts`.

**Adding a tool `foo`:**
1. Add `["foo"]="owner/repo"` to `REPOS` in `update-versions.sh`; run `bash update-versions.sh --apply` (never hand-type
   the row; its date comes from GitHub). Add `foo = "ecosystem:pkg"` under `[osv]` when OSV knows it.
2. `install.sh`: brew formula and/or an `_ensure "foo" …` block with a checksum source (`gh:<owner/repo>|<version>|<asset regex>`
   finds the asset and its GitHub digest).
3. `core/tool-cache.zsh`: `export HAS_FOO=$(has_tool foo)`, only if a module uses the flag.
4. Aliases gated on `[[ "$HAS_FOO" == "true" ]]`; `doctor.zsh` (`require_cmd`, `require_flag`, `require_shell`).
5. `test/mock_tools.zsh` `TOOLS`; `test/suite.zsh` an `assert_var` per `HAS_*` and tests for aliases.
6. `functions/help` and `README.md`.

## 7. Testing

```bash
make check                  # lint (bash -n / zsh -n on every script) + the suite
zsh -f test/suite.zsh       # must print "Results: N Passed, 0 Failed" and "SUCCESS"
bash ./verify-status.sh     # only when touching config/starship.toml (needs real starship)
zsh doctor.zsh              # on a real machine, after install changes
```

- The suite sets `HOME=/tmp/dotfiles_test_home`, builds mock binaries in `/tmp/dotfiles_mock_bin`, prepends them to
  `PATH`, sources `core/init.zsh`. It runs non-interactively, so `IS_AGENT=true`. Test human mode with
  `env -i HOME=… TERM=xterm-256color zsh -f -i -c '…'`.
- Inside the suite `rm` is the trash wrapper and `cat` is bat: use `command rm` / `command cat`. Use paths under
  `/tmp/test_*` and clean with `command rm -rf`.
- Count only through `assert_eq` / `assert_defined` / `assert_var` / `assert_contains`.
- A fake tool prints exactly what the real one printed (text and exit status); run the real tool once and copy it.
- Fixture dates are relative to `date` (`date -d "-7 days"`), never fixed. `DOTDOCTOR_NOW` fixes the clock;
  `DOTDOCTOR_OFFLINE=1` keeps fixtures from reaching real `brew`/`snap`/`flatpak`.
- `--apply` needs a tty: `printf 'y\n' | script -qfec 'zsh -f -c "…"' /dev/null`, with a fake `systemctl` first on `PATH`.
- An assert label must not contain `command not found` (the last check counts it in the run log). A check that greps for
  a forbidden word builds the pattern from adjacent quoted pieces and tells grep's exit 1 from 2.
- **Every bug fix gets a regression test that fails on the old code** (restore the old file from `git show HEAD:path`,
  run, put the fix back). A test must run the path that broke (`rm -f` on a missing path never reaches the trash code).
  A "must not pick X" assert passes when the old code picks Y: name the old-code result of every new assert.

## 8. Documentation that must stay in sync

When a command is added, renamed or removed, update: `README.md` (Key Commands, layout), `functions/help`, `INSTALL.md`
(install steps, pins, platforms), `doctor.zsh` (tools/integrations), `test/suite.zsh` (`assert_defined` + a functional
test), and this file (structure, load order, conventions). Docs write the clone URL as `<repo-url>`.

## 9. Don'ts (each bit this repo once)

- Don't override core commands (`sleep`, `top`, `python`, …). Exceptions: `rm`/`del` (trash), `cd` (zoxide, humans only),
  `cat` (bat). `grep` is aliased to `--color=auto`: use `command grep` in functions.
- Aliases and functions leak into autoloaded functions in human shells (`ls` eza, `cat` bat, `grep`, `diff`): call
  `command NAME` or a builtin; check with `whence -w NAME`; test in a human-mode shell.
- Don't name a zsh local `path` (tied to `$PATH`). `(( n++ ))` returns 1 while `n` is 0: use `(( n += 1 ))`. No
  `BASH_REMATCH` (`$match`), no `[ a == b ]`, no `ls $glob_in_a_variable`. No `setopt local_options` outside a function.
  `${var/#$HOME/~}` takes a bare `~`. `"${(j:, :)${(nou)arr}}"` joins twice: write `${(@nou)arr}`. `(@ok)` plus `(q)`
  escapes names: keep a plain array and test membership with `(Ie)`.
- Don't combine `INC_APPEND_HISTORY` with `SHARE_HISTORY`.
- Don't make `install.sh` back up or rewrite `~/.zshrc`/`~/.bashrc`; it only appends the loader line if missing.
- Don't add `editor-config` back (dropped on purpose). Don't commit generated artifacts (`.verify-status-worktree/`,
  caches, `*.log`). Don't run `test/uninstall.sh` unasked.
- Bash under `set -euo pipefail`: `set -e` is off inside a function used as an `if` condition or before `&&`/`||` (give
  each step `|| return 1`). A pipeline whose `grep` finds nothing aborts `v=$(…)`: end it with `|| true`. Never pipe `curl`
  into a reader that exits early (`head`, `awk … exit`): capture first (`sums=$(curl -fsSL …)`). `pgrep -f` matches
  itself: use `pgrep -x`. `cp -f` over a running binary or a symlink fails or writes through it: copy to `x.new` and
  `mv -f`. A new `versions.toml` section reusing tool names breaks any `^name =` lookup: scope to `[tools]`/`[fonts]`.
- Calendar dates (release ages, quarantine ends) use calendar arithmetic (`date -d "$d + N days"`), never 86400-second
  steps. Elapsed-time checks are fine.
- `read -k 1` leaves the Enter queued, and the next prompt reads it (apt's `[Y/n]` takes it as yes): use `read -r` and
  print the prompt yourself. A step with hidden output must not wait for input (`_dd_run_step` closes stdin; apt runs
  `-y`).
- dotdoctor: match kernels by ABI and keep the running and newest (not by `-generic`); prune the XDG Trash and
  `~/.Trash` from globs; a distro backport keeps the upstream version, so look for the CVE id in
  `/usr/share/doc/<pkg>/changelog.Debian.gz`; `[ -r /proc/PID/fd ]` tests mode bits only, so list the fds with a glob;
  Node inside a uv tool is at find depth 9; `sed -E 's/…/\1/'` prints the whole line when the field is missing, use
  `sed -nE '…/p'`.
- The Bash tool here runs zsh and inherits `CLAUDECODE=1`: an unmatched glob is an error (use `find`; `(N)` did not
  apply), `echo =====` fails (quote it), `print "-- x"` reads as an option (`print -r -- …`), `whence -v` shows no file
  for an autoloaded function (`print -l $^fpath/NAME(N)`). Test with `env -i HOME="$HOME" TERM=xterm-256color zsh -i -c '…'`
  (human) or `TERM=dumb` (agent). `zsh -i` on a scratch `.zshrc` runs every line: use `zsh -f` and set `fpath`.
  An alias defined by a file sourced inside a `zsh -c '…'` string is not expanded later in that same string (the
  string is parsed first): test aliases with `eval "rm x"` or from a script file. `env -i` drops prefix assignments
  (`X=1 env -i …`): put them in the `env` words.
- Tracked files never hold the owner's GitHub handle, account name, e-mail or machine paths. A clean tree is not a clean
  history: also run `git log --all -i -G <handle> --oneline` (`-S` misses moved lines) and
  `git log --all --format='%an <%ae>' | sort | uniq -c`.

## 10. Commits

Conventional commits: `feat(scope): …`, `fix: …`, `refactor(scope): …`, `docs: …`, `test: …`; scopes are area names
(`install`, `git`, `files`, `history`, …). One logical change per commit; run `make check` first.

## 11. Agents and reports

The main session loads `harness:orchestrator`. A brief to a sub-agent carries Role, Goal, Tree, Input, Write set, Judge,
Runs, Budget, Report; every fact is marked READ, DERIVED or PROBED, with current `path:line` for cited code. Sub-agents
keep no task list and end with `harness:report`. An agent proposes; the main session applies. No agent edits this file.
