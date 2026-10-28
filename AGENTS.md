# AGENTS.md — Guide for AI agents and contributors

This file is the contract for anyone (human or AI) editing this repository.
Read it fully before changing anything. If the code and this file disagree,
fix whichever is wrong in the same change.

---

## 1. What this repo is, and the goal

A **zsh-only** dotfiles framework for one person's machines: **macOS**,
**Debian/Ubuntu**, and **WSL2 (Debian)**. It installs a curated set of CLI
tools and wires them into zsh with aliases, small functions and a Starship
prompt. The repo loads in place, wherever it is cloned (§3).

The goals, in priority order:

1. **Safe.** Nothing in the shell should destroy data by accident. `rm` goes to
   the trash in *every* shell, AI/agent shells included, and falls back to
   `rm -i` only where no trash tool exists. Tools are installed from pinned
   versions with SHA256 checks and a `.freshness` quarantine.
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
│                       # adds the loader to ~/.zshrc (the repo loads in place, see §3).
├── doctor.zsh          # Health check (alias: doctor). Exit 1 if a required tool/flag is missing.
├── update-versions.sh  # Proposes/applies newer pins in versions.toml (past the `.freshness` window only); adds the row of a tool in `REPOS` that has none.
├── verify-status.sh    # Visual Starship git-pill verifier (builds .verify-status-worktree/).
├── versions.toml       # Pinned tool versions + release dates (source of truth for install.sh).
├── config/             # App configs deployed to ~/.config: starship.toml, atuin.toml, zellij/
├── core/               # Sourced on EVERY startup, in a fixed order (see §3)
│   ├── init.zsh        # The loader. ~/.zshrc sources this file.
│   ├── platform.zsh    # DOTFILES_PLATFORM, IS_MAC/IS_LINUX/IS_WSL, IS_AGENT
│   ├── paths.zsh       # PATH: Homebrew, trash-cli keg, ~/.bun, ~/.cargo, ~/.local/bin, each prepended: ~/.local/bin ends first (pins win)
│   ├── history.zsh     # zsh history options
│   └── tool-cache.zsh  # HAS_* flags, cached in ~/.cache/dotfiles_tools; `refresh` alias
├── plugins/            # Integrations with cached init output
│   ├── shell.zsh       # Oh My Zsh (or plain compinit) + gh completions + Starship
│   ├── zoxide.zsh      # zoxide + smart `cd` (humans only)
│   ├── atuin.zsh       # atuin history (humans only)
│   └── zellij.zsh      # zellij config deploy + zj/zja/zjs/zjk/zjl/zjd
├── modules/            # Aliases + small functions, sourced recursively (modules/**/*.zsh)
│   ├── dev/            # http (xh), json
│   ├── files/          # listing (l/ll/lt/lsh/llh/lth, cat; ls stays plain), navigation (.. ~ -), trash (rm/del/rl/rt)
│   ├── git/            # git aliases, gh aliases
│   ├── shell/          # general aliases (c, x, reload, path, sudok, ssh-login/ssh-test)
│   └── system/         # network (myip, localip, port, kill-port)
├── platform/           # Per-platform overrides: macos.zsh, debian.zsh, wsl.zsh
├── functions/          # Autoloaded functions: one file per function, file name = function name
│   ├── dotdoctor       # entry point: check [--latest] [--advisories], scan [--deep], update [--apply], clean [--apply]
│   ├── dotdoctor-lib   # shared helpers (colours, facts, _dd_* functions), loaded first by the others
│   ├── dotdoctor-check # pinned versions and advisories from versions.toml; network only with --latest
│   ├── dotdoctor-scan  # local indicators of compromise; read-only (lists outbound connections to read), --save writes the baseline
│   ├── dotdoctor-update # inventory of updates; --apply asks y/n/a/q per step, one line each (log: ~/.cache/dotdoctor/update.log)
│   ├── dotdoctor-clean # leftovers (units, git rules, Brotli, apt/brew copies of pinned tools, old self-update copies); report only, --apply offers each removal
│   └── dotdoctor-osv   # OSV.dev lookup for the versions.toml [osv] tools; only with check --advisories
└── test/
    ├── suite.zsh       # Main test suite (mocks every tool; runs non-interactively)
    ├── mock_tools.zsh  # Creates fake binaries in /tmp/dotfiles_mock_bin
    └── uninstall.sh    # DESTRUCTIVE helper to simulate a bare machine. Never run it casually.
```

`.kiro/` holds hooks/scripts for the Kiro editor (smart commit, PR review). They are
editor tooling, not part of the shell; leave them alone unless asked.

`.claude/agents/feedback.md` is the scorecard log (§11); `.claude/skills/code-comments/` holds the comment skill (§5).

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
- The repo loads **in place**: `~/.zshrc` sources `<repo>/core/init.zsh`, wherever the repo is cloned.
  An edit takes effect in a new shell (or `exec zsh`); no re-install is needed.

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
| `ls` | real `ls`, never aliased (`modules/files/listing.zsh:8` removes Oh My Zsh's alias) | real `ls` |
| `l`, `ll`, `lt`, `lsh`, `llh`, `lth` | eza, when installed; without it `l`, `ll`, `lsh`, `llh` are plain `ls` and `lt`, `lth` do not exist | as the human shell (eza with `--color=auto`, plain when piped) |
| `cat` | `bat --style=plain --paging=never` when bat is installed; else real `cat` | as the human shell (not gated by `IS_AGENT`) |
| `cd` | zoxide wrapper, when zoxide is installed (fuzzy jump if the path doesn't exist) | builtin `cd` |
| `rm`, `del` | **trash** | **trash** — deliberately identical |

Rules:

- **Never** make output in agent shells depend on a TTY-only feature. Use
  `--color=auto`, never `--color=always`, in any alias an agent might hit.
- **Never** weaken the `rm` → trash wrapper for agents. The owner explicitly wants
  agent shells unable to permanently delete through `rm`. (`rm` is the function at
  `modules/files/trash.zsh:9` when `trash-put` exists; with only `trash` it is alias `trash` (:136); with neither, alias `rm -i` (:140).
  `command rm`, `/bin/rm`, scripts and `find -delete` bypass it. Real enforcement
  belongs in the agent's own permission settings.)
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
- Section headers use the existing `# ====` banner + `# --- Name ---` style. After every
  comment you write, ask: "Is this information the next Claude would spend multiple tool
  calls trying to understand?" If the answer isn't clearly yes, the comment is noise:
  delete it (`.claude/skills/code-comments/SKILL.md`).
- User-facing messages use the existing emoji + ANSI colour style
  (`❌` error, `✅` success, `⚠️` confirmation, `📝 Usage:`).
- Destructive helpers ask `(y/N)` first and report failure honestly: print ✅ only
  when the command actually succeeded, and `return 1` on failure. Known breaks to fix:
  `trash.zsh:87-130` and `network.zsh:68` print ✅ without checking the command's status.

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
  `core/tool-cache.zsh`'s mtime, size and `$OSTYPE`. Installing a new tool does **not**
  invalidate it: the user runs `refresh`. Any new cache file must also be added to
  the `refresh` alias.

### Startup must stay side-effect light

Startup code runs in every shell, including every agent command. It may copy a
config file into `~/.config` when it differs (existing self-heal pattern) and write
caches. It must **not**: use the network, call `sudo`, prompt for input, or print
output in agent shells.

### Boundaries

- Agents never run a git command that writes (`commit`, `push`, `reset`, `checkout`, ...) unless the owner asks. The suite's own git writes in /tmp are allowed.
- Agents never run `sudo`, or `apt`, `snap` or `flatpak` installs. They print the command for the owner instead.
- Agents never add a dependency or a new tool without the owner's yes.
- Agents never use the network themselves (`curl`, `wget`, `git fetch`, `gh api`, a package manager's lookups). Running a repo command that uses it is fine when the owner asks for it: `myip`, `gstat`, `dotdoctor check --latest`, `dotdoctor check --advisories`, `dotdoctor update`.
- Agents never read a credential file (`auth.json`, tokens). Check it with `stat -c '%s %a' FILE` (size and mode; macOS: `stat -f '%z %Lp'`), never `cat`.

---

## 6. Tools, pins and the `.freshness` quarantine

`versions.toml` is the source of truth:

```toml
[tools]
eza = { version = "0.23.5", released = "2026-07-09" }
```

- **Never** pin a release younger than the number of days in **`.freshness`** (supply-chain quarantine).
  `install.sh` refuses it; `update-versions.sh` only proposes releases past the `.freshness` window.
- `versions.toml [fixes]` lists fixed releases for known advisories (one `fixed` version
  per release line, with release dates in the same order). The quarantine applies to
  fixes too: `dotdoctor check` shows the date a fix becomes installable. Do not override
  it without the owner's say-so.
- A release line with no `fixed` entry is never left unknown: `[fixes]` gives it one.
  `dotdoctor check` fails an installed version inside `affected` on such a line
  (`functions/dotdoctor-lib:157`: Node 20 under node-brotli, range `0 26.12.0`).
  Node 20 is an open item (feedback.md wishlist).
- `versions.toml [osv]` maps a tool to its OSV.dev package (`ecosystem:name`, e.g. `Go:github.com/cli/cli/v2`). `dotdoctor check --advisories` asks OSV.dev about the installed version (`functions/dotdoctor-osv`), so a new CVE needs no repo change. Node and Bun are runtimes, not OSV packages: their bundled Brotli stays in `[fixes]`. `install.sh` and `update-versions.sh` read pins from `[tools]` and `[fonts]` only, because `[fixes]` and `[osv]` reuse tool names.
- `dotdoctor` must stay portable (Linux and macOS) and must not hard-code account names,
  machine paths or hardware-vendor names. Checks a platform lacks are reported as skipped.
  `dotdoctor scan --facts` writes the home folder as `~` so baselines compare across machines.
- Every binary, archive and font `install.sh` downloads gets a **SHA256 check**: `_install_bin` (a checksum URL or the GitHub release asset digest, `install.sh:407-416`), the font (`install.sh:250-255`). Exceptions: the Oh My Zsh and plugin git clones (`install.sh:199`, `:217`, `:221`) and the Homebrew bootstrap (`install.sh:94`, only when `brew` is missing, Homebrew's own installer). apt and brew verify their own packages. Never add a `curl | sh` install.
- `uv` and `gh` are pinned on **all** platforms (installed into `~/.local`). `git` is not pinned and
  `install.sh` never builds it: apt provides it on Debian/WSL, Homebrew on macOS. Other tools come
  from Homebrew on macOS; on Linux/WSL they are pinned binaries.
- `~/.local/bin` must stay **ahead** of Homebrew and system paths in `PATH`
  (`core/paths.zsh`), so the pins win. Don't re-prepend brew paths anywhere else.
- The copy in `~/.local/bin` **is** the pin. `_ensure` (`install.sh:475`) looks only at it, so a newer apt or Homebrew copy no longer keeps the pinned one from being installed (apt's gh was 2.103.3 against the pin, so the pin was never installed). `dotdoctor clean` lists the other copies and offers to remove the package. A tool with no `[tools]` row yet is skipped with a ⏳ line until `bash update-versions.sh --apply` adds the row: its date comes from GitHub, never typed by hand.
- A `git` in `~/.local/bin` hides the system git because that directory comes first on `PATH`; `install.sh` stops with an error when it finds one.

### Checklist: adding a new tool `foo`

1. `versions.toml`: no hand-typed row. Do step 2, then run `bash update-versions.sh --apply`: it adds `foo = { version, released }` with the date GitHub reports (past the `.freshness` window). Add `foo = "ecosystem:package"` under `[osv]` when OSV.dev knows it (crates.io, PyPI, npm, Go).
2. `update-versions.sh`: add `["foo"]="owner/repo"` to `REPOS`.
3. `install.sh`: brew formula (macOS list, `BREW_FORMULAE`) and/or an `_ensure "foo" ...` block with a checksum source. A URL of the form `gh:<owner/repo>|<version>|<asset regex>` finds the GitHub asset by name and uses the digest GitHub lists for it (`_resolve_gh_asset`), so no file name is guessed.
4. `core/tool-cache.zsh`: `export HAS_FOO=$(has_tool foo)`, only when a module uses the flag (terraform-ls, rg, fd, just, lazygit, btm and yazi have none).
5. Aliases/functions: gated on `[[ "$HAS_FOO" == "true" ]]`, in the right module.
6. `doctor.zsh`: `require_cmd foo` / `require_flag HAS_FOO` / `require_shell <alias>`.
7. `test/mock_tools.zsh`: add `foo` to `TOOLS`; `test/suite.zsh`: every `HAS_*` flag gets an `assert_var`, and the aliases get tests.
8. `functions/help` and `README.md` (Key Commands).

---

## 7. Testing

```bash
zsh -f test/suite.zsh       # main suite — must print "Results: N Passed, 0 Failed" and end with "SUCCESS"
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
  `test_passed` / `test_failed` only through them (known break: `suite.zsh:149-178` increments inline inside `&&`/`||`, see §9).
- Use paths under `/tmp/test_*` and clean them up with `command rm -rf`.
- To prove a repo ignore rule, bypass the owner's global one: `git -c core.excludesFile=/dev/null check-ignore -v PATH` must name `.gitignore:N`.
- For `--apply` tests that need a terminal: `printf 'y\n' | script -qfec 'zsh -f -c "…"' /dev/null`, with a fake `systemctl` first on `PATH` so a daemon-reload never reaches the real user manager. No `</dev/null` in that runner: `--apply` needs a tty on stdin.
- After `source core/init.zsh`, `PATH` holds Homebrew: reset it, or set `DOTDOCTOR_OFFLINE=1`, so a fixture never reaches a real `brew`, `snap` or `flatpak`.
- A suite check that greps for a forbidden word must not spell it whole: build the pattern from adjacent quoted pieces (`"ab""cd"`). Tell grep's exit 1 (no match) from 2 or more (failure), or a broken `.git` passes silently.
- An assert label must not contain the text `command not found`: the last suite check counts that text in the whole run log (`test/suite.zsh:604-609`).
- A regression test must run the path that broke: `rm -f` on a missing path never reaches the trash code and passes on the old file; use an existing file.

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

The clone URL is the repository's own, shown on its page. Docs write it as `<repo-url>`, so no account name is hard-coded.

---

## 9. Don'ts (things that have bitten this repo before)

- Don't use `--color=always` or bare `--icons` in aliases (breaks piped/agent output).
- Don't override core commands (`sleep`, `top`, `python`, …) with "smart" wrappers. The
  intentional exceptions are `rm`/`del` (trash), `cd` (zoxide, humans only) and `cat` (bat,
  when installed). `grep` is aliased to `grep --color=auto` (`modules/shell/aliases.zsh:10`):
  harmless in pipes, but use `command grep` inside functions.
- Don't use `setopt local_options` outside a function — it has no effect there and
  leaks the option into the session. Use glob qualifiers (`*(N)`) instead.
- Don't combine `INC_APPEND_HISTORY` with `SHARE_HISTORY` (zsh docs: pick one).
- Don't use `BASH_REMATCH` (zsh uses `$match`), `[ a == b ]` (use `[[ ]]`), or
  `ls $pattern` to expand a glob held in a variable (zsh doesn't glob parameters).
- Don't run `test/uninstall.sh` unless the user explicitly asks — it deletes tools and configs.
- Don't commit generated artifacts: `.verify-status-worktree/`, caches, `*.log`.
- Don't make `install.sh` back up or rewrite the user's `~/.zshrc`/`~/.bashrc`. It only
  appends the loader line if missing. (An older version replaced them and left a
  timestamped `.bak` on every run; that destroyed real config and is gone for good.)
- Don't add an `editor-config` (VS Code/Kiro settings printer) back; it was dropped on purpose.
- Don't name a zsh local `path`: it is tied to `$PATH`, so assigning it rewrites the search path. Use `file`, `pkgfile`, etc.
- `(( n++ ))` returns status 1 while `n` is 0, so `(( n++ )) && …` silently misfires. Use `(( n += 1 ))`.
- Don't write `'~'` inside `${var/#$HOME/…}` to get a tilde: the quotes stay in the output. Use `~` bare.
- Calendar dates (release ages, quarantine ends) use calendar arithmetic: `date -d "$d + $DD_QUARANTINE_DAYS days"`, as `_dd_quarantine_end` (`functions/dotdoctor-lib:90`) does. Never add or subtract 86400-second steps to get a date. Elapsed-time checks (a file older than 7 days) and a rounded gap between two midnights are fine.
- Aliases leak into autoloaded functions in human shells: `ls` was eza there and broke `dotdoctor-update` (`functions/dotdoctor-update:46`). Inside a function call `command <name>` or a builtin, and test in a human-mode shell (`cat` is bat there too, when installed). Oh My Zsh's `ls` alias (`~/.oh-my-zsh/lib/theme-and-appearance.zsh:95`) is removed at `modules/files/listing.zsh:8`.
- Under `set -euo pipefail` (`install.sh:16`), `set -e` is off inside a function that runs as an `if` condition or on the left of `&&`/`||`: give each step `|| return 1`. Re-check: `bash -c 'set -e; f(){ false; echo still-running; }; if f; then :; fi'`.
- `pgrep -f` matches its own command line (`bash -c 'pgrep -f NAME'` finds its own shell): use `pgrep -x NAME`.
- The Bash tool here runs zsh: an unmatched glob is an error (`no matches found`), and the `(N)` qualifier did not apply there (`for f in functions/nomatch*(.N); do :; done` still errors). Use `find`.
- A shell started from the Bash tool inherits `CLAUDECODE=1`; `env -i` strips it. An open shell keeps old definitions after an rc change. Test with `env -i HOME="$HOME" TERM=xterm-256color zsh -i -c '…'` (human) or `TERM=dumb` (agent), and run `exec zsh` or open a new terminal.
- `whence -v` shows no file for an autoloaded function: use `print -l $^fpath/<name>(N)`.
- `rm` is the function at `modules/files/trash.zsh:9` when `trash-put` exists; `del` is an alias of `rm` (`:44`). With only `trash`, `rm` is alias `trash` (`:136`); with neither, alias `rm -i` (`:140`). Check the branch before you say either.
- A function an agent shell calls must not depend on a helper defined elsewhere at startup. In the Claude Code Bash tool shell `rm` existed but `_trash_items` did not, so `rm` exited 127 and deleted nothing (cause of the missing helper unproven). `rm` (`modules/files/trash.zsh:9`) now uses only builtins and `command trash-put`/`command trash`; `test/suite.zsh:247-273` runs it in a shell that has only `rm`.
- Node inside a uv tool sits at find depth 9 (`~/.local/share/uv/tools/<tool>/lib/pythonX.Y/site-packages/nodejs_wheel/bin/node`): `find -maxdepth 8` misses it. `functions/dotdoctor-check:116` uses 9.
- `${(@ok)assoc}` gives plain keys, but the `(q)` flag escapes them (`my\ key`). Keep names in a plain array and test membership with `(Ie)`, as `functions/dotdoctor-clean:192` does.
- `sed -E 's/…/\1/'` prints the whole line when the field is missing. Use `sed -nE '…/p'`, which prints nothing (`_dd_field`, `functions/dotdoctor-lib:59`).
- `[ -r /proc/PID/fd ]` tests mode bits only. Check that the fds can be listed with a glob, as `functions/dotdoctor-scan:327` does.
- A `-generic$` grep filter dropped every kernel, and matching the image's version string missed Pop!_OS's flavourless `linux-headers-<abi>`. Match kernel packages by ABI and keep the running and the newest one (`functions/dotdoctor-update:72-95`).
- Globbing `~/.local/share` reports trashed copies. Prune the XDG Trash and `~/.Trash` (`DD_TRASH_PRUNE`, `functions/dotdoctor-lib:37`).
- A distro backport keeps the upstream version number. Before calling a package affected, look for the CVE id in `/usr/share/doc/<pkg>/changelog.Debian.gz` (`functions/dotdoctor-check:99`).
- A new `versions.toml` section that reuses tool names (`[fixes]` bun-brotli, `[osv]` uv) breaks any `^name =` lookup over the whole file: install.sh's `_ver` returned `uv = "crates.io:uv"` and the download URL broke (curl exit 3). Scope the lookup to `[tools]`/`[fonts]` (`awk`, `install.sh` `_ver`); the suite checks it.
- `"${(j:, :)${(nou)arr}}"` in double quotes joins the inner result with spaces before the outer `(j)` runs, so a port list printed as `443 80`. Write `${(@nou)arr}` (`functions/dotdoctor-scan:219`).
- `cp -f src ~/.local/bin/x` fails on a running binary (text file busy) and, onto a symlink, writes through it into the file it points at (a `~/.local/bin/fd` link to the system `fdfind`). `_place_bin` copies to `x.new` and `mv -f`s it over (`install.sh:383`).
- Never pipe curl into a reader that exits early (`awk '…exit'`, `head`) under pipefail: curl fails with error 23, a write error (closed pipe, bad output path, full disk). Capture first, then parse: `sums=$(curl -fsSL "$checksum_url")` (`install.sh:407`).
- `read -k 1` takes the key and leaves the Enter typed after it queued: the next program's prompt reads an empty answer (apt's `[Y/n]` takes it as yes). Read a line with `read -r`, as `_dd_ask` does (`functions/dotdoctor-lib:277`). zsh shows `read`'s `?prompt` only in an interactive shell: print the prompt yourself.
- A step whose output is hidden must not wait for an answer: `_dd_run_step` closes its stdin (`functions/dotdoctor-lib:312`), so apt runs with `-y` and noninteractive debconf, and the steps that ask on purpose (apt purge, flatpak uninstall) run `visible`. A full `install.sh` right after an apt upgrade failed on the apt lock (packagekitd held it): the update runs `install.sh --tools-only`, which needs no apt.
- `local x` for a name already declared in the same function prints `x=<value>` (`zsh -f -c 'f(){ local a=1; local a; }; f'` prints `a=1`). `dotdoctor check` declared `line` at `functions/dotdoctor-check:34` and again in the re-check, so every re-check began with a stray `line='zoxide …'`. Declare a name once per function; the suite now fails on a stray `line=`.

- A human shell defines `diff` as a function (`command diff --color "$@"`) besides the aliased `ls`, `cat`, `grep`: check a bare external with `whence -w NAME`, and call `command diff` in functions (`functions/dotdoctor-scan`).
- In the Bash tool's zsh, `echo =====` fails (the leading `=` expands as a command) and `print "-- x"` is read as an option: quote separators and use `print -r -- …`.
- `zsh -i` on a scratch `.zshrc` runs every line in it (a `bash <(curl …)` fixture would execute): test with `zsh -f` and set `fpath` yourself.
- Don't put the owner's GitHub handle, account name, e-mail or machine paths in any tracked file: docs write the clone URL as `<repo-url>`, and `.claude/settings.local.json` is in `.gitignore`. A clean tree is not a clean history: also run `git log --all -i -G <handle> --oneline` (`-S` misses a line that moved: 6 of 9 commits) and `git log --all --format='%an <%ae>' | sort | uniq -c`.

---

## 10. Commits

Conventional commits, matching the history: `feat(scope): …`, `fix: …`,
`refactor(scope): …`, `docs: …`, `test: …`. Scopes are the area names
(`install`, `git`, `files`, `zellij`, `history`, …). One logical change per commit;
run `zsh -f test/suite.zsh` before committing.

## 11. Scorecards and learning

The main session writes every sub-agent's brief from this template, with every field present. Sub-agents keep no task list (the plan tool refuses them), so their report and scorecard are their whole output.

```
Scope:      files it may edit; read-only for the rest, and whether a read-only grep of the repo is allowed
Rules:      first the output marks (❌, ✅), the alias rule (§4, §9) and the comment rule (§5), then the frameworks that define
            aliases it touches (Oh My Zsh loads before the modules), then the rest that applies
Facts:      each fact and cited rule is marked READ, DERIVED or PROBED; a rule is checked against the code
            (path:line) or marked OPEN; the current behaviour stated exactly, path:line
Check:      does the code obey each cited rule? Answer with path:line, or OPEN; for a test, which asserts
            must fail on the old code and which only guard a path
Task:       one question or one change, and what done means; never a broad review; the steps in order,
            and whether a failed step aborts the run or continues
Verify:     exact commands in the exact shell, e.g. env -i HOME="$HOME" TERM=xterm-256color zsh -i -c '…';
            the shell's glob rule (zsh nomatch: use find; `(N)` failed in the Bash tool); for files with
            uncommitted work, `cp -p` a snapshot first and `diff -u` (git diff shows nothing for untracked
            files); how to test one section alone (call dotdoctor-lib first), or a fixture; one function alone:
            `zsh -f -c 'source FILE; typeset -f NAME'` (`$(typeset -f NAME)` printed nothing in the Bash tool)
Settle:     the main session's signal that the files you depend on are done; a check run before it is stale
Report:     the five lines below
Scorecard:  required: a report without one is incomplete
```

The report comes first, answer first, in five lines in this order; "none" when a line has nothing to say. Mark each claim READ (from code or docs), DERIVED (worked by hand) or PROBED (run: the command and its exit code). A bug is a suspect until PROBED.

```
Changed:      the files written, by path
Checked:      the command run and its result (exit code, counts); "not run" and why
NOT CHECKED:  what the report does not cover
OUTSIDE:      things seen but out of scope
DECIDE:       the choices for the owner: option, cost; option, cost
```

The scorecard closes the report. The main session asks for a missing one before it accepts the work.

```markdown
## Scorecard: <role>, <task in six words>

| Score | Value | 5 means |
| --- | --- | --- |
| Brief | N/5 | nothing had to be guessed |
| Ease | N/5 | nothing was looked up twice |
| Job | N/5 | every question answered with a marked claim |

**Lessons learned** (at most 3; each a rule with its reason, re-checkable: path:line, a command, a version; never a story)
- one fact the next agent needs

**Troubles** (what cost time or went wrong, and where it came from: the brief, a tool, a rule, a file)
- what happened

**Wishlist for the next assignment** (the change that would have saved the trouble; "none" when empty)
- the brief field, tool, rule or file
```

Score honestly: a low score about the brief helps more than a polite one.

Each scorecard changes something. The main session does this after every one; a session that worked alone does it for itself:

- **Log it:** one numbered entry in `.claude/agents/feedback.md` before the task is closed: the three scores, the open wishlist items it takes on, and what changed because of them. An item leaves the open list when its change lands, and the entry names that change.
- **Route it:** each lesson and trouble goes to one home: a trap to section 9 (one seen twice becomes a rule), a rule to the section it belongs to, a missing fact to the brief template, a broken tool to the tool. A line that stopped being true is deleted in the change that falsifies it.
- **Fold in the wishlist:** before each brief, read the open items in the log and fold the matching ones into its fields.
- **Change the rule or the tool, not only the brief,** when a score is 3 or less or the same trouble comes back.
- **Wrap up:** the wrap-up names the entry numbers and ends with **Lessons:** the file each lesson went into ("none" is fine).

An agent proposes and the main session applies. No agent edits this file or the log itself.
