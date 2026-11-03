# ============================================================================
# 🏁 DOTFILES TEST SUITE (zsh-only)
# ============================================================================

SCRIPT_DIR="$( cd "$( dirname "${(%):-%x}" )" && pwd )"
DOT_DIR="$(dirname "$SCRIPT_DIR")"

# Everything this run prints also goes to a log (tee reads a FIFO). The last check
# reads the log: a helper called before it is defined prints "command not found"
# and its assertions are never counted, so that text fails the run.
SUITE_LOG="/tmp/test_suite_output.$$"
SUITE_FIFO="$SUITE_LOG.fifo"
command rm -f -- "$SUITE_LOG" "$SUITE_FIFO"
mkfifo "$SUITE_FIFO"
command tee "$SUITE_LOG" < "$SUITE_FIFO" &
SUITE_TEE_PID=$!
exec 3>&1 4>&2
exec >"$SUITE_FIFO" 2>&1

echo -e "🚀 Starting Dotfiles Test Suite (zsh-only)..."

# 1. Environment Simulation
export HOME="/tmp/dotfiles_test_home"
mkdir -p "$HOME/.cache"

# Load mocks BEFORE init so tool cache detects them
source "$SCRIPT_DIR/mock_tools.zsh"
export PATH="/tmp/dotfiles_mock_bin:$PATH"
rm -f "$HOME/.cache/dotfiles_tools"

# 2. Source the Loader
echo "📥 Sourcing core/init.zsh..."
source "$DOT_DIR/core/init.zsh"

# Re-ensure mocks take precedence
export PATH="/tmp/dotfiles_mock_bin:$PATH"

# 3. Validation Tests
test_passed=0
test_failed=0

function assert_defined() {
    if command -v "$1" >/dev/null 2>&1 || (( ${+functions[$1]} )) || alias "$1" >/dev/null 2>&1; then
        echo -e "  ✅ [PASSED] Defined: $1"
        ((test_passed++))
    else
        echo -e "  ❌ [FAILED] Missing: $1"
        ((test_failed++))
    fi
}

function assert_var() {
    local val="${(P)1}"
    if [[ -n "$val" ]]; then
        echo -e "  ✅ [PASSED] Variable: $1=$val"
        ((test_passed++))
    else
        echo -e "  ❌ [FAILED] Variable not set: $1"
        ((test_failed++))
    fi
}

echo -e "\n🔍 Checking Platform Detection..."
assert_var DOTFILES_PLATFORM
assert_var IS_MAC
assert_var IS_LINUX
assert_var IS_WSL

echo -e "\n🔍 Checking Feature Flags..."
assert_var HAS_ZOXIDE
assert_var HAS_EZA
assert_var HAS_BAT
assert_var HAS_GH
assert_var HAS_UV
assert_var HAS_BUN
assert_var HAS_ATUIN
assert_var HAS_FZF
assert_var HAS_TRASH_PUT
assert_var HAS_TRASH
assert_var HAS_DELTA
assert_var HAS_STARSHIP
assert_var HAS_BATCAT
assert_var HAS_TERRAFORM

echo -e "\n🔍 Checking File & Navigation..."
assert_defined ls
assert_defined ll
assert_defined lt
assert_defined lsh
assert_defined llh
assert_defined lth
assert_defined cat
assert_defined cd
assert_defined extract
assert_defined compress
assert_defined ..

echo -e "\n🔍 Checking GitHub alias..."
assert_defined ghv

echo -e "\n🔍 Checking Network & System..."
assert_defined myip
assert_defined localip
assert_defined sudok
assert_defined help
assert_defined reload
assert_defined x
assert_defined path

echo -e "\n🔍 Checking Autoloaded Functions..."
assert_defined git-setup
assert_defined ssh-setup
assert_defined c
assert_defined del
assert_defined rl
assert_defined rt
assert_defined empty-trash

echo -e "\n🧪 Functional: compress & extract"
touch "/tmp/data"
for ext in zip tar tar.gz tgz tar.bz2 tbz2 tar.xz txz tar.zst 7z gz bz2 xz zst Z; do
    archive="/tmp/test_arc.$ext"
    compress "$archive" "/tmp/data" >/dev/null 2>&1
    if [[ -f "$archive" ]]; then
        echo -e "  ✅ [PASSED] compress .$ext"
        ((test_passed++))
        rm -f "$archive"
    else
        echo -e "  ❌ [FAILED] compress .$ext"
        ((test_failed++))
    fi
done
rm -f "/tmp/data"

# Real tools (the mocks above only touch files): run in a subshell without the mock directory.
echo -e "\n🧪 Functional: compress & extract roundtrips (real tools)"
_arc_out=$(
    path=(${path:#/tmp/dotfiles_mock_bin}); hash -r
    T=/tmp/test_arcfix; command rm -rf "$T"; mkdir -p "$T/src/sub" "$T/v1.0"; cd "$T/src" || exit 1
    print -r -- one > a.txt; print -r -- two > sub/b.txt; print -r -- dash > ./-z.txt
    ok() { [[ "$2" == "0" ]] && print -r -- "OK|$1" || print -r -- "NO|$1"; }

    compress "$T/v1.0/x" a.txt sub >/dev/null 2>&1
    ok "compress dotted dir keeps default .tar.gz" "$([[ -f $T/v1.0/x.tar.gz ]]; print $?)"

    compress "$T/UP.TAR.GZ" a.txt sub >/dev/null 2>&1
    ok "compress uppercase .TAR.GZ is a real gzip tar" "$(command tar -tzf $T/UP.TAR.GZ >/dev/null 2>&1; print $?)"
    extract "$T/UP.TAR.GZ" "$T/o_up" >/dev/null 2>&1
    ok "extract .TAR.GZ roundtrip" "$(command diff -r sub $T/o_up/sub >/dev/null 2>&1; print $?)"

    compress "$T/dash.tar.gz" -z.txt a.txt >/dev/null 2>&1
    extract "$T/dash.tar.gz" "$T/o_dash" >/dev/null 2>&1
    ok "leading-dash input roundtrip (tar.gz)" "$(command diff ./-z.txt $T/o_dash/-z.txt >/dev/null 2>&1; print $?)"

    if (( $+commands[zip] && $+commands[unzip] )); then
        compress "$T/d.zip" -z.txt a.txt >/dev/null 2>&1
        extract "$T/d.zip" "$T/o_dz" >/dev/null 2>&1
        ok "leading-dash input roundtrip (zip)" "$(command diff ./-z.txt $T/o_dz/-z.txt >/dev/null 2>&1; print $?)"

        compress "$T/e.zip" a.txt >/dev/null 2>&1
        compress "$T/e.zip" sub >/dev/null 2>&1; rc=$?
        ok "existing zip refused with status 1" "$((rc == 1 ? 0 : 1))"
        ok "existing zip not appended to" "$(command unzip -l $T/e.zip | command grep -q b.txt; print $((1 - $?)))"

        cp "$T/e.zip" "$T/x.jar"; extract "$T/x.jar" "$T/o_jar" >/dev/null 2>&1
        ok "extract .jar" "$(command diff a.txt $T/o_jar/a.txt >/dev/null 2>&1; print $?)"

        cp "$T/d.zip" "$T/-z.zip"; (cd "$T" && extract -z.zip o_dz2 >/dev/null 2>&1)
        ok "extract leading-dash zip name" "$(command diff ./-z.txt $T/o_dz2/-z.txt >/dev/null 2>&1; print $?)"
    fi

    compress "$T/nx.tar.gz" nofile_here >/dev/null 2>&1; rc=$?
    ok "nonexistent input: status 1" "$((rc == 1 ? 0 : 1))"
    ok "nonexistent input leaves no archive or temp" "$(command find $T -maxdepth 1 \( -name 'nx*' -o -name '.tmp.*' \) | command grep -q . ; print $((1 - $?)))"

    compress "$T/m.gz" a.txt sub/b.txt >/dev/null 2>&1; rc=$?
    ok "several inputs into .gz refused, no file" "$([[ $rc -eq 1 && ! -e $T/m.gz ]]; print $?)"
    compress "$T/dir.gz" sub >/dev/null 2>&1; rc=$?
    ok "directory into .gz refused, no file" "$([[ $rc -eq 1 && ! -e $T/dir.gz ]]; print $?)"

    cp "$T/UP.TAR.GZ" "$T/noext"; extract "$T/noext" "$T/o_ne" >/dev/null 2>&1
    ok "extract extension-less tar.gz by sniffing" "$(command diff -r sub $T/o_ne/sub >/dev/null 2>&1; print $?)"

    if (( $+commands[zstd] )); then
        compress "$T/z.tar.zst" a.txt sub >/dev/null 2>&1
        extract "$T/z.tar.zst" "$T/o_zst" >/dev/null 2>&1
        ok "extract .tar.zst roundtrip" "$(command diff -r sub $T/o_zst/sub >/dev/null 2>&1; print $?)"
    fi
    if (( $+commands[7zz] || $+commands[7z] || $+commands[7za] )); then
        compress "$T/s.7z" -z.txt sub >/dev/null 2>&1
        extract "$T/s.7z" "$T/o_7z" >/dev/null 2>&1
        ok "7z roundtrip with leading-dash input" "$(command diff -r sub $T/o_7z/sub >/dev/null 2>&1 && command diff ./-z.txt $T/o_7z/-z.txt >/dev/null 2>&1; print $?)"
    fi

    print -r -- "$(extract $T/src 2>&1)" | command grep -q 'is a directory'
    ok "extract on a directory says 'is a directory'" "$?"
    command rm -rf "$T"
)
for _arc_line in ${(f)_arc_out}; do
    if [[ "$_arc_line" == OK\|* ]]; then
        echo -e "  ✅ [PASSED] ${_arc_line#OK|}"; ((test_passed++))
    else
        echo -e "  ❌ [FAILED] ${_arc_line#NO|}"; ((test_failed++))
    fi
done
unset _arc_out _arc_line

echo -e "\n🧪 Functional: Network"
myip >/dev/null 2>&1 && { echo -e "  ✅ [PASSED] myip"; ((test_passed++)); } || { echo -e "  ❌ [FAILED] myip"; ((test_failed++)); }
localip >/dev/null 2>&1 && { echo -e "  ✅ [PASSED] localip"; ((test_passed++)); } || { echo -e "  ❌ [FAILED] localip"; ((test_failed++)); }


function assert_eq() {
    if [[ "$2" == "$3" ]]; then
        echo -e "  ✅ [PASSED] $1"
        ((test_passed++))
    else
        echo -e "  ❌ [FAILED] $1 (expected '$3', got '$2')"
        ((test_failed++))
    fi
}

echo -e "\n🔍 Checking removed names are gone..."
for _gone in http json port kill-port gstat server pr prs gs gl; do
    # pr and gs may be real programs (coreutils, ghostscript): only an alias or function means the old code is back.
    _gone_kind=$(whence -w $_gone 2>/dev/null); _gone_kind=${_gone_kind##*: }
    assert_eq "removed: $_gone is no alias or function" "$([[ "$_gone_kind" == (alias|function) ]] && echo "$_gone_kind" || echo gone)" "gone"
done
unset _gone _gone_kind

echo -e "\n🔍 Checking every name in 'help' is defined..."
# Rows of functions/help: print_cmd "a, b" "text". A row gated on HAS_X (same line or an if block) counts only when HAS_X is true.
_help_gate="" _help_names=()
while IFS= read -r _help_line; do
    if [[ "$_help_line" =~ '^if \[\[ "\$(HAS_[A-Z_]+)"' ]]; then _help_gate=$match[1]; continue; fi
    [[ "$_help_line" == "fi" ]] && { _help_gate=""; continue; }
    [[ "$_help_line" =~ 'print_cmd "([^"]+)"' ]] || continue
    _help_row=$match[1] _help_row_gate=$_help_gate
    [[ "$_help_line" =~ '^\[\[ "\$(HAS_[A-Z_]+)"' ]] && _help_row_gate=$match[1]
    [[ -n "$_help_row_gate" && "${(P)_help_row_gate}" != "true" ]] && continue
    for _help_name in ${(s:, :)_help_row}; do
        [[ "$_help_name" == *" "* || "$_help_name" == "Ctrl+R"* ]] && continue
        _help_names+=("$_help_name")
    done
done < "$DOT_DIR/functions/help"
for _help_name in $_help_names; do assert_defined "$_help_name"; done
assert_eq "help: the row scan found the cheatsheet commands" "$(( ${#_help_names} > 15 ))" "1"
unset _help_gate _help_names _help_line _help_row _help_row_gate _help_name

echo -e "\n🧪 Functional: Agent mode (this suite runs non-interactively)"
assert_eq "IS_AGENT=true in non-interactive shell" "$IS_AGENT" "true"
assert_eq "ls is not aliased for agents" "$(alias ls >/dev/null 2>&1 && echo aliased || echo plain)" "plain"
assert_eq "cd is the builtin for agents" "$(whence -w cd)" "cd: builtin"
assert_eq "ll uses --color=auto" "$(alias ll | grep -c -- '--color=auto')" "1"
assert_eq "rm is the trash wrapper for agents" "$(whence -w rm)" "rm: function"

# Interactive human shell: plain ls (no alias), ll still eza, IS_AGENT=false
human=$(env -u CLAUDECODE -u DOTFILES_AGENT TERM=xterm-256color HOME="$HOME" PATH="$PATH" \
    zsh -f -i -c "source '$DOT_DIR/core/init.zsh' >/dev/null 2>&1; print -r -- \"\$IS_AGENT|\$(alias ls)|\$(alias ll)\"" </dev/null 2>/dev/null | tail -1)
assert_eq "IS_AGENT=false in interactive shell" "${human%%|*}" "false"
human_ls="${human#*|}"; human_ls="${human_ls%%|*}"
human_ll="${human##*|}"
assert_eq "interactive ls has no alias (plain ls)" "$human_ls" ""
assert_eq "interactive ll is still eza" "$([[ "$human_ll" == *eza* ]] && echo yes || echo no)" "yes"
agent=$(env CLAUDECODE=1 TERM=xterm-256color HOME="$HOME" PATH="$PATH" \
    zsh -f -i -c "source '$DOT_DIR/core/init.zsh' >/dev/null 2>&1; print -r -- \"\$IS_AGENT\"" </dev/null 2>/dev/null | tail -1)
assert_eq "CLAUDECODE=1 forces IS_AGENT=true" "$agent" "true"
# whence -w tells an alias from a function or a command, so ls is checked for each kind.
human_kinds=$(env -u CLAUDECODE -u DOTFILES_AGENT TERM=xterm-256color HOME="$HOME" PATH="$PATH" \
    zsh -f -i -c "source '$DOT_DIR/core/init.zsh' >/dev/null 2>&1; print -r -- \"\$(whence -w ls)|\$(whence -w ll)\"" </dev/null 2>/dev/null | tail -1)
assert_eq "human shell: ls is the plain command (not an alias or function)" "${human_kinds%%|*}" "ls: command"
assert_eq "human shell: ll is an alias" "${human_kinds##*|}" "ll: alias"

echo -e "\n🧪 Functional: History options"
assert_eq "INC_APPEND_HISTORY off (SHARE_HISTORY covers it)" "$([[ -o INC_APPEND_HISTORY ]] && echo on || echo off)" "off"

echo -e "\n🧪 Functional: rm → trash"
TRASH_ROOT="/tmp/test_trash_wrapper"
command rm -rf "$TRASH_ROOT"; mkdir -p "$TRASH_ROOT" && cd "$TRASH_ROOT"
touch plain -- -dashed
rm plain
assert_eq "rm trashes a file" "$([[ -e plain ]] && echo kept || echo gone)" "gone"
rm -- -dashed
assert_eq "rm -- handles names starting with '-'" "$([[ -e ./-dashed ]] && echo kept || echo gone)" "gone"
rm --force missing-file >/dev/null 2>&1
assert_eq "rm --force on a missing file succeeds" "$?" "0"
rm -fR missing-dir >/dev/null 2>&1
assert_eq "rm -fR (combined flags) on a missing path succeeds" "$?" "0"
cd "$DOT_DIR"; command rm -rf "$TRASH_ROOT"

echo -e "\n🧪 Functional: rm alone (a shell that has only rm defined)"
RM_ONLY_ROOT="/tmp/test_rm_only"
RM_ONLY_LOG="$RM_ONLY_ROOT/trash-put.log"
RM_ONLY_FN=$(typeset -f rm)
command rm -rf "$RM_ONLY_ROOT"; mkdir -p "$RM_ONLY_ROOT/bin" "$RM_ONLY_ROOT/work"
command cat > "$RM_ONLY_ROOT/bin/trash-put" <<FAKE
#!/bin/sh
printf '%s\n' "\$*" >> '$RM_ONLY_LOG'
FAKE
chmod +x "$RM_ONLY_ROOT/bin/trash-put"
: > "$RM_ONLY_ROOT/work/victim"

rm_only_err=$(env -i PATH="$RM_ONLY_ROOT/bin:/usr/bin:/bin" HAS_TRASH=true HAS_TRASH_PUT=true \
    zsh -f -c "$RM_ONLY_FN"$'\n'"rm '$RM_ONLY_ROOT/work/victim'" 2>&1 >/dev/null)
rm_only_rc=$?
assert_eq "rm alone on an existing file exits 0" "$rm_only_rc" "0"
assert_eq "rm alone hands the file to trash-put" "$(command cat -- "$RM_ONLY_LOG" 2>/dev/null)" "-- $RM_ONLY_ROOT/work/victim"
assert_eq "rm alone prints no missing-command error" "$([[ "$rm_only_err" == *"command not found"* ]] && echo yes || echo no)" "no"

command rm -f -- "$RM_ONLY_LOG"
rm_f_out=$(env -i PATH="$RM_ONLY_ROOT/bin:/usr/bin:/bin" HAS_TRASH=true HAS_TRASH_PUT=true \
    zsh -f -c "$RM_ONLY_FN"$'\n'"rm -f '$RM_ONLY_ROOT/work/missing'" 2>&1)
rm_f_rc=$?
assert_eq "rm -f alone on a missing path exits 0" "$rm_f_rc" "0"
assert_eq "rm -f alone on a missing path calls no trash-put" "$([[ -e "$RM_ONLY_LOG" ]] && echo yes || echo no)" "no"
assert_eq "rm -f alone on a missing path is silent" "$rm_f_out" ""

command rm -f -- "$RM_ONLY_LOG"
: > "$RM_ONLY_ROOT/work/victim"
env -i PATH="$RM_ONLY_ROOT/bin:/usr/bin:/bin" HAS_TRASH=true HAS_TRASH_PUT=true \
    zsh -f -c "$RM_ONLY_FN"$'\n'"rm -f '$RM_ONLY_ROOT/work/victim'" >/dev/null 2>&1
rm_fv_rc=$?
assert_eq "rm -f alone on an existing file exits 0" "$rm_fv_rc" "0"
assert_eq "rm -f alone hands the existing file to trash-put" "$(command cat -- "$RM_ONLY_LOG" 2>/dev/null)" "-- $RM_ONLY_ROOT/work/victim"
command rm -rf "$RM_ONLY_ROOT"

function assert_contains() {
    if [[ "$2" == *"$3"* ]]; then
        echo -e "  ✅ [PASSED] $1"
        ((test_passed++))
    else
        echo -e "  ❌ [FAILED] $1 (no '$3' in output)"
        ((test_failed++))
    fi
}

echo -e "\n🧪 Functional: dotdoctor"
assert_defined dotdoctor
assert_defined dotdoctor-check
assert_defined dotdoctor-scan
assert_defined dotdoctor-lib
assert_eq "dotdoctor rejects unknown subcommands" "$(dotdoctor nope >/dev/null 2>&1; echo $?)" "1"
# dotdoctor help prints the usage table (help, -h and --help), exit 0.
dd_help=$(dotdoctor help 2>&1); dd_help_rc=$?
assert_eq "dotdoctor help exits 0" "$dd_help_rc" "0"
assert_contains "dotdoctor help lists update --apply" "$dd_help" "update --apply"
assert_contains "dotdoctor help lists dotdoctor scan" "$dd_help" "dotdoctor scan"
assert_contains "dotdoctor help says install.sh is for a first install" "$dd_help" "install.sh is only for a first install"
assert_eq "dotdoctor -h prints the same table" "$(dotdoctor -h 2>&1)" "$dd_help"

# Quarantine dates: bun 1.4.4 was released 2026-10-22, so it leaves quarantine on 2026-11-05.
DD_TEST_BIN="/tmp/test_dotdoctor_bin"
command rm -rf "$DD_TEST_BIN"; mkdir -p "$DD_TEST_BIN"
printf '#!/bin/sh\necho "bun 1.4.2"\n' > "$DD_TEST_BIN/bun"; chmod +x "$DD_TEST_BIN/bun"
dd_early=$(date -d 2026-10-28 +%s 2>/dev/null || date -j -f %Y-%m-%d 2026-10-28 +%s)
dd_late=$(date -d 2026-11-10 +%s 2>/dev/null || date -j -f %Y-%m-%d 2026-11-10 +%s)
DD_FRESH14="/tmp/test_dd_fresh14"; command rm -rf "$DD_FRESH14"; mkdir -p "$DD_FRESH14"
command cp "$DOT_DIR/versions.toml" "$DD_FRESH14/"; print 14 > "$DD_FRESH14/.freshness"
dd_out=$(DOTFILES_DIR="$DD_FRESH14" PATH="$DD_TEST_BIN:$PATH" DOTDOCTOR_NOW="$dd_early" dotdoctor check 2>&1)
assert_contains "dotdoctor check: affected bun shows when the fix leaves quarantine" "$dd_out" "quarantined until 2026-11-05"
dd_out=$(DOTFILES_DIR="$DD_FRESH14" PATH="$DD_TEST_BIN:$PATH" DOTDOCTOR_NOW="$dd_late" dotdoctor check 2>&1)
assert_contains "dotdoctor check: past quarantine, the upgrade is offered" "$dd_out" "upgrade to 1.4.4"
command rm -rf "$DD_TEST_BIN" "$DD_FRESH14"

# Reproducible scan: same facts on every run, and a saved baseline matches a fresh run.
dd_state="/tmp/test_dotdoctor_state"
command rm -rf "$dd_state"
dd_f1=$(DOTDOCTOR_STATE="$dd_state" dotdoctor scan --facts 2>/dev/null)
dd_f2=$(DOTDOCTOR_STATE="$dd_state" dotdoctor scan --facts 2>/dev/null)
assert_contains "dotdoctor scan --facts starts with the format header" "$dd_f1" "# dotdoctor-facts v1"
assert_eq "dotdoctor scan --facts is reproducible" "$dd_f1" "$dd_f2"
DOTDOCTOR_STATE="$dd_state" dotdoctor scan --save >/dev/null 2>&1
dd_diff=$(DOTDOCTOR_STATE="$dd_state" dotdoctor scan --diff 2>&1)
assert_contains "dotdoctor scan --diff matches the baseline it just saved" "$dd_diff" "identical to the baseline"
command rm -rf "$dd_state"

# dotdoctor clean reports by default and refuses to apply without a terminal.
assert_defined dotdoctor-clean
dd_clean=$(dotdoctor clean </dev/null 2>&1)
assert_contains "dotdoctor clean reports the three checks" "$dd_clean" "Brotli in Python venvs"
dd_clean_apply=$(dotdoctor clean --apply </dev/null 2>&1); dd_clean_rc=$?
assert_eq "dotdoctor clean --apply never runs without a terminal (exit 0 when nothing to clean)" "$dd_clean_rc" "0"

# dotdoctor update is inventory-only by default and never asks for a password.
assert_defined dotdoctor-update
dd_apt_bin="/tmp/test_dd_apt_bin"
command rm -rf "$dd_apt_bin"; mkdir -p "$dd_apt_bin"
print -rl -- '#!/bin/sh' 'exit 0' > "$dd_apt_bin/apt-get"; chmod +x "$dd_apt_bin/apt-get"
dd_upd=$(PATH="$dd_apt_bin:$PATH" DOTDOCTOR_OFFLINE=1 dotdoctor update </dev/null 2>&1)
command rm -rf "$dd_apt_bin"
assert_contains "dotdoctor update lists the system packages" "$dd_upd" "System packages (apt)"
assert_contains "dotdoctor update prints a Commands section" "$dd_upd" "Commands to run"
assert_contains "dotdoctor update banner: inventory only by default" "$dd_upd" "DOTDOCTOR UPDATE   inventory only"
dd_upd_apply=$(DOTDOCTOR_OFFLINE=1 dotdoctor update --apply </dev/null 2>&1)
assert_contains "dotdoctor update --apply still prints the plan first" "$dd_upd_apply" "Commands to run"
assert_contains "dotdoctor update --apply banner: asks before the no-root steps" "$dd_upd_apply" "DOTDOCTOR UPDATE   asks y/n/a/q before each step"
dd_upd_bogus=$(DOTDOCTOR_OFFLINE=1 dotdoctor update --bogus 2>&1)
dd_upd_bogus_rc=$?
assert_eq "dotdoctor update --bogus exits 1" "$dd_upd_bogus_rc" "1"
assert_contains "dotdoctor update --bogus names the unknown option" "$dd_upd_bogus" "Unknown option: --bogus"
assert_contains "dotdoctor update --bogus prints the usage line" "$dd_upd_bogus" "Usage: dotdoctor update [--apply]"

# Portable facts: the home folder is written as ~ (any account, any machine).
dd_fact_home=$( ( dotdoctor-lib; _dd_fact test path "$HOME/x"; print -r -- "${DD_FACTS[-1]}" ) )
assert_contains "dotdoctor facts write the home folder as ~" "$dd_fact_home" "~/x"
# No account names, vendor names or machine paths in the dotdoctor code.
dd_hardcoded=$(grep -nE '/home/|/Users/' "$DOT_DIR"/functions/dotdoctor* 2>/dev/null)
assert_eq "dotdoctor code holds no account names or machine paths" "$dd_hardcoded" ""
# No personal strings in the tracked tree (AGENTS.md section 9). The words are joined
# at run time, so no forbidden word is written whole in this file.
pii_pattern="tfern""d|tfern""andes|t""hales|disn""ey|dam""at"
if [[ -e "$DOT_DIR/.git" ]]; then
    # --untracked skips files that .gitignore covers (for example .claude/settings.local.json).
    pii_hits=$(command git -C "$DOT_DIR" grep -iIl --untracked -E "$pii_pattern" 2>/dev/null)
    pii_rc=$?
    # git grep exits 1 for "no match"; a higher status is a git failure, which must not pass.
    (( pii_rc > 1 )) && pii_hits="git grep failed (exit $pii_rc)"
    assert_eq "no tracked file holds the owner's handle, name or employer" "$pii_hits" ""
else
    echo -e "  ⏭️  [SKIPPED] No .git here (tarball): personal-string scan not run"
fi

# Advisory logic: the release line decides whether a fix counts (dotdoctor-lib).
dd_adv_node_old=$( ( dotdoctor-lib; _dd_advisory node node-brotli 22.12.0 ) 2>&1 )
assert_contains "advisory: node 22.12.0 is affected (no fix on its line)" "$dd_adv_node_old" "affected"
dd_adv_node_new=$( ( dotdoctor-lib; _dd_advisory node node-brotli 22.23.4 ) 2>&1 )
assert_contains "advisory: node 22.23.4 is fixed" "$dd_adv_node_new" "fixed"
dd_adv_bun=$( ( dotdoctor-lib; _dd_advisory bun bun-brotli 1.5.0 ) 2>&1 )
assert_contains "advisory: bun 1.5.0 has no fix listed" "$dd_adv_bun" "no fix listed"
dd_adv_py_old=$( ( dotdoctor-lib; _dd_advisory python-brotli python-brotli 1.1.0 ) 2>&1 )
assert_contains "advisory: python-brotli 1.1.0 is affected" "$dd_adv_py_old" "affected"
dd_adv_py_new=$( ( dotdoctor-lib; _dd_advisory python-brotli python-brotli 1.2.1.0 ) 2>&1 )
assert_contains "advisory: python-brotli 1.2.1.0 is fixed" "$dd_adv_py_new" "fixed"

# Unknown check option is an error (exit 1).
dd_bogus_rc=$(dotdoctor check --bogus >/dev/null 2>&1; echo $?)
assert_eq "dotdoctor check --bogus exits 1" "$dd_bogus_rc" "1"

# An installed version above the pin is reported as newer than the pin (bun 1.4.5 against the 1.4.2 pin).
dd_nb="/tmp/test_dd_newer_bin"
command rm -rf "$dd_nb"; mkdir -p "$dd_nb"
printf '#!/bin/sh\necho "bun 1.4.5"\n' > "$dd_nb/bun"; chmod +x "$dd_nb/bun"
dd_nb_out=$(PATH="$dd_nb:$PATH" dotdoctor check 2>&1)
assert_contains "dotdoctor check: an installed version above the pin is newer than the pin" "$dd_nb_out" "newer than the pin"
command rm -rf "$dd_nb"

# A pin inside an advisory's affected range fails check (exit 1), using a fixture versions.toml.
dd_pv="/tmp/test_dd_pin_versions"; dd_pb="/tmp/test_dd_pin_bin"
command rm -rf "$dd_pv" "$dd_pb"; mkdir -p "$dd_pv" "$dd_pb"
printf '[tools]\nfaketool = { version = "1.0.0", released = "2026-01-01" }\n\n[fixes]\nfaketool-brotli = { fixed = "1.0.5", released = "2026-01-10", cve = "CVE-2026-0001", affected = "0 1.0.3" }\n' > "$dd_pv/versions.toml"
print 14 > "$dd_pv/.freshness"
printf '#!/bin/sh\necho "faketool 1.0.0"\n' > "$dd_pb/faketool"; chmod +x "$dd_pb/faketool"
dd_pin_now=$(date -d 2026-10-28 +%s 2>/dev/null || date -j -f %Y-%m-%d 2026-10-28 +%s)
dd_pin_out=$(DOTFILES_DIR="$dd_pv" DOTDOCTOR_NOW="$dd_pin_now" PATH="$dd_pb:$PATH" dotdoctor check 2>&1); dd_pin_rc=$?
assert_contains "dotdoctor check: a pin inside the affected range is named as affected" "$dd_pin_out" \
    "the pin 1.0.0 is affected by CVE-2026-0001: bump it to 1.0.5 now"
assert_eq "dotdoctor check: an affected pin exits 1" "$dd_pin_rc" "1"
command rm -rf "$dd_pv" "$dd_pb"

# Snap and Flatpak runtimes ship their own libbrotli: affected is a warning (exit 0, no 'update with', no Next line).
dd_sf="/tmp/test_dd_snapflat"; dd_sfb="/tmp/test_dd_snapflat_bin"
command rm -rf "$dd_sf" "$dd_sfb"; mkdir -p "$dd_sf/home/.local/share/flatpak/runtime/org.fake.Platform/x86_64/23.08/active/files/lib/x86_64-linux-gnu" \
    "$dd_sf/snap/fakesnap/current/usr/lib/x86_64-linux-gnu" "$dd_sfb"
: > "$dd_sf/home/.local/share/flatpak/runtime/org.fake.Platform/x86_64/23.08/active/files/lib/x86_64-linux-gnu/libbrotlidec.so.1.2.0"
: > "$dd_sf/snap/fakesnap/current/usr/lib/x86_64-linux-gnu/libbrotlidec.so.1.1.0"
printf '[tools]\n\n[fixes]\nlibbrotli = { fixed = "1.0.10 1.1.1 1.2.1", released = "2026-01-01 2026-01-01 2026-01-01", cve = "CVE-2026-111497", affected = "1.0.3 1.2.0" }\n' > "$dd_sf/versions.toml"
print 14 > "$dd_sf/.freshness"
printf '#!/bin/sh\nexit 1\n' > "$dd_sfb/dpkg-query"; chmod +x "$dd_sfb/dpkg-query"
dd_sf_out=$(DOTFILES_DIR="$dd_sf" HOME="$dd_sf/home" DOTDOCTOR_SNAP_ROOT="$dd_sf/snap" DOTDOCTOR_PY_ROOTS="$dd_sf/none" DOTDOCTOR_OFFLINE=1 DOTDOCTOR_NOW="$dd_pin_now" PATH="$dd_sfb:$PATH" dotdoctor check 2>&1); dd_sf_rc=$?
dd_sf_snap=$(print -r -- "$dd_sf_out" | command grep 'snap fakesnap')
dd_sf_fp=$(print -r -- "$dd_sf_out" | command grep 'flatpak org.fake.Platform')
assert_contains "dotdoctor check: an affected snap runtime is a warning (old: failure mark)" "$dd_sf_snap" "is affected by CVE-2026-111497: the fix (1.1.1) is the publisher's"
assert_contains "dotdoctor check: an affected flatpak runtime is a warning (old: failure mark)" "$dd_sf_fp" "is affected by CVE-2026-111497: the fix (1.2.1) is the publisher's"
assert_eq "dotdoctor check: snap and flatpak lines carry no 'update with' (old: they did)" "$([[ "$dd_sf_snap$dd_sf_fp" == *"update with"* ]] && echo yes || echo no)" "no"
assert_eq "dotdoctor check: only snap/flatpak findings exit 0 (old: 1)" "$dd_sf_rc" "0"
assert_eq "dotdoctor check: only snap/flatpak findings print no Next line (old: printed)" "$([[ "$dd_sf_out" == *"Next: dotdoctor update"* ]] && echo yes || echo no)" "no"
command rm -rf "$dd_sf" "$dd_sfb"

# Guard: a Node copy inside the affected range still fails the check.
dd_nf="/tmp/test_dd_nodefail"
command rm -rf "$dd_nf"; mkdir -p "$dd_nf/bin"
printf '[tools]\n\n[fixes]\nnode-brotli = { fixed = "22.12.1", released = "2026-01-01", cve = "CVE-2026-0002", affected = "22.0.0 22.12.0" }\n' > "$dd_nf/versions.toml"
print 14 > "$dd_nf/.freshness"
printf '#!/bin/sh\necho v22.12.0\n' > "$dd_nf/bin/node"; chmod +x "$dd_nf/bin/node"
dd_nf_out=$(DOTFILES_DIR="$dd_nf" HOME="$dd_nf" DOTDOCTOR_PY_ROOTS="$dd_nf/none" DOTDOCTOR_OFFLINE=1 DOTDOCTOR_NOW="$dd_pin_now" PATH="$dd_nf/bin:$PATH" dotdoctor check 2>&1); dd_nf_rc=$?
assert_eq "dotdoctor check: an affected Node still exits 1 (guard)" "$dd_nf_rc" "1"
command rm -rf "$dd_nf"

# An unknown option that is a subcommand name gets a hint; a plain typo does not.
dd_hint=$(dotdoctor update clean 2>&1); dd_hint_rc=$?
assert_contains "dotdoctor update clean: Did you mean hint (old: no hint)" "$dd_hint" "Did you mean: dotdoctor clean ?"
assert_eq "dotdoctor update clean exits 1" "$dd_hint_rc" "1"
assert_contains "dotdoctor check scan: Did you mean hint (old: no hint)" "$(dotdoctor check scan 2>&1)" "Did you mean: dotdoctor scan ?"
assert_contains "dotdoctor clean update: Did you mean hint (old: no hint)" "$(dotdoctor clean update 2>&1)" "Did you mean: dotdoctor update ?"
assert_contains "dotdoctor scan check: Did you mean hint (old: no hint)" "$(dotdoctor scan check 2>&1)" "Did you mean: dotdoctor check ?"
assert_eq "dotdoctor update --bogus: no hint (guard)" "$([[ "$(dotdoctor update --bogus 2>&1)" == *"Did you mean"* ]] && echo yes || echo no)" "no"
dd_help=$(dotdoctor help 2>&1)
assert_contains "dotdoctor help lists scan --deep (old: only in the file header)" "$dd_help" "dotdoctor scan --deep"
assert_contains "dotdoctor help lists --help (old: absent)" "$dd_help" "--help"
assert_contains "dotdoctor help lists plain update (old: only update --apply)" "$dd_help" "dotdoctor update                what can be updated"

# A tool behind its pin (installed 0.9.0, pin 1.0.0) ends check with one Next line for the update.
dd_nx="/tmp/test_dd_next"; dd_nxb="/tmp/test_dd_next_bin"
command rm -rf "$dd_nx" "$dd_nxb"; mkdir -p "$dd_nx" "$dd_nxb"
printf '[tools]\nfaketool = { version = "1.0.0", released = "2026-01-01" }\n' > "$dd_nx/versions.toml"
print 14 > "$dd_nx/.freshness"
printf '#!/bin/sh\necho "faketool 0.9.0"\n' > "$dd_nxb/faketool"; chmod +x "$dd_nxb/faketool"
dd_nx_out=$(DOTFILES_DIR="$dd_nx" DOTDOCTOR_OFFLINE=1 DOTDOCTOR_NOW="$dd_pin_now" PATH="$dd_nxb:$PATH" dotdoctor check 2>&1)
assert_contains "dotdoctor check: a tool behind its pin ends with a Next line" "$dd_nx_out" "Next: dotdoctor update --apply"
command rm -rf "$dd_nx" "$dd_nxb"

# A Node copy that is not safe to run (group-writable, mode 775) is never run: its version comes from the
# nodejs_wheel_binaries-<ver>.dist-info beside it, and it is still reported as affected.
dd_nh="/tmp/test_dd_node_home"; dd_nm="$dd_nh/.local/share/uv/tools/fake/lib/python3.12/site-packages"
command rm -rf "$dd_nh"; mkdir -p "$dd_nm/nodejs_wheel/bin" "$dd_nm/nodejs_wheel_binaries-22.12.0.dist-info"
print -rl -- '#!/bin/sh' "touch $dd_nh/ran-marker" 'echo v22.12.0' > "$dd_nm/nodejs_wheel/bin/node"
chmod 775 "$dd_nm/nodejs_wheel/bin/node"
dd_node_out=$(HOME="$dd_nh" dotdoctor check 2>&1)
assert_contains "dotdoctor check: the unsafe Node copy gets its version from the package metadata" "$dd_node_out" \
    "version from package metadata, copy not run"
assert_contains "dotdoctor check: the unsafe Node copy 22.12.0 is reported as affected" "$dd_node_out" \
    "22.12.0  affected; no fix on the 22.12 line"
assert_eq "dotdoctor check: the unsafe Node copy is never run" \
    "$([[ -e "$dd_nh/ran-marker" ]] && echo ran || echo not-run)" "not-run"
command rm -rf "$dd_nh"

# DST-safe age: 2026-02-28 to 2026-03-14 across the US spring change is 14 whole days, not 13.
dd_dst="/tmp/test_dd_dst"
dd_dst_bin="/tmp/test_dd_dst_bin"
command rm -rf "$dd_dst" "$dd_dst_bin"
mkdir -p "$dd_dst" "$dd_dst_bin"
printf '[tools]\nfaketool = { version = "1.0.0", released = "2026-02-28" }\n\n[fixes]\n' > "$dd_dst/versions.toml"
print 14 > "$dd_dst/.freshness"
printf '#!/bin/sh\necho "faketool 1.0.0"\n' > "$dd_dst_bin/faketool"; chmod +x "$dd_dst_bin/faketool"
dd_dst_now=$(TZ=America/New_York date -d '2026-03-14 00:00' +%s 2>/dev/null || TZ=America/New_York date -j -f '%Y-%m-%d %H:%M' '2026-03-14 00:00' +%s)
dd_dst_out=$(DOTFILES_DIR="$dd_dst" TZ=America/New_York DOTDOCTOR_NOW="$dd_dst_now" PATH="$dd_dst_bin:$PATH" dotdoctor check 2>&1)
assert_contains "DST-safe age: faketool is released 14d ago" "$dd_dst_out" "released 14d ago"
dd_dst_q=no; [[ "$dd_dst_out" == *"inside the quarantine"* ]] && dd_dst_q=yes
assert_eq "DST-safe age: a 14-day-old pin is out of quarantine" "$dd_dst_q" "no"
command rm -rf "$dd_dst" "$dd_dst_bin"

# Device check: a process named evtest holds the input-capture name; scan must report it.
dd_cap="/tmp/test_dd_cap"
command rm -rf "$dd_cap"; mkdir -p "$dd_cap"
cp /bin/sleep "$dd_cap/evtest"
"$dd_cap/evtest" 30 &
dd_evtest_pid=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do
    [[ "$(<"/proc/$dd_evtest_pid/comm" 2>/dev/null)" == evtest ]] && break
    sleep 0.2
done
dd_scan=$(dotdoctor scan 2>&1)
kill "$dd_evtest_pid" 2>/dev/null; wait "$dd_evtest_pid" 2>/dev/null
assert_contains "dotdoctor scan reports the running evtest process" "$dd_scan" "evtest"
assert_contains "dotdoctor scan has the Input and capture devices section" "$dd_scan" "Input and capture devices"
command rm -rf "$dd_cap"

# Shell start-up files: each download-and-run form is one rc-hook fact; the facts are 3-field TSV with ~ for $HOME.
dd_rc="/tmp/test_dd_rc_home"
command rm -rf "$dd_rc"; mkdir -p "$dd_rc"
print -rl -- \
    'eval "$(curl -fsSL https://a.example/x)"' \
    'source <(curl -fsSL https://b.example/x)' \
    'bash <(curl -fsSL https://c.example/x)' \
    'sh <(wget -qO- https://d.example/x)' \
    'bash -c "$(curl -fsSL https://e.example/x)"' \
    'curl -fsSL https://f.example/x | sh' \
    'wget -qO- https://g.example/x | bash' \
    $'tab\tcurl -fsSL https://h.example/x | sh' \
    'echo "plain line, no download"' > "$dd_rc/.zshrc"
dd_rc_facts=$(HOME="$dd_rc" dotdoctor scan --facts 2>/dev/null)
dd_rc_forms=(eval-curl source-curl bash-process-curl sh-process-wget bash-c-curl curl-pipe-sh wget-pipe-bash tab-curl-pipe-sh)
for dd_rc_n in 1 2 3 4 5 6 7 8; do
    assert_contains "scan --facts flags rc line $dd_rc_n (${dd_rc_forms[dd_rc_n]})" "$dd_rc_facts" "rc-hook"$'\t'"~/.zshrc"$'\t'"$dd_rc_n:"
done
assert_eq "scan --facts does not flag a plain line" \
    "$(print -r -- "$dd_rc_facts" | command grep -c 'plain line')" "0"
assert_eq "scan --facts: a tab in a flagged line is written as a space (every fact has 3 fields)" \
    "$(print -r -- "$dd_rc_facts" | awk -F'\t' 'NR>1 && NF!=3 {n++} END {print n+0}')" "0"
assert_eq "scan --facts writes the home folder as ~ in rc-hook keys" \
    "$(print -r -- "$dd_rc_facts" | command grep -c '/tmp/test_dd_rc')" "0"
command rm -rf "$dd_rc"

# The 3-field rule covers every fact, not only rc hooks: a tab in a start-up file name must not add a field.
dd_tab="/tmp/test_dd_tab_home"
command rm -rf "$dd_tab"; mkdir -p "$dd_tab/.config/autostart"
: > "$dd_tab/.config/autostart/"$'a\tb.desktop'
dd_tab_facts=$(HOME="$dd_tab" dotdoctor scan --facts 2>/dev/null)
assert_eq "scan --facts: a tab in an autostart file name keeps every fact at 3 fields" \
    "$(print -r -- "$dd_tab_facts" | awk -F'\t' 'NR>1 && NF!=3 {n++} END {print n+0}')" "0"
command rm -rf "$dd_tab"

# --save keeps the previous baseline as .prev; a failed save says so, returns 1 and keeps the old baseline.
dd_sv="/tmp/test_dd_save_state"
dd_sv_file="/tmp/test_dd_save_file"
command rm -rf "$dd_sv" "$dd_sv_file"; mkdir -p "$dd_sv"
dd_sv_1=$(DOTDOCTOR_STATE="$dd_sv" dotdoctor scan --save 2>&1)
assert_contains "scan --save writes the baseline" "$dd_sv_1" "baseline saved"
assert_eq "scan --save: a first save keeps no .prev" "$([[ -e "$dd_sv/baseline.tsv.prev" ]] && echo yes || echo no)" "no"
dd_sv_first=$(command cat -- "$dd_sv/baseline.tsv")
DOTDOCTOR_STATE="$dd_sv" dotdoctor scan --save >/dev/null 2>&1
assert_eq "scan --save keeps the old baseline as baseline.tsv.prev" "$(command cat -- "$dd_sv/baseline.tsv.prev")" "$dd_sv_first"
assert_eq "scan --save leaves no baseline.tsv.tmp behind" "$([[ -e "$dd_sv/baseline.tsv.tmp" ]] && echo yes || echo no)" "no"
dd_sv_before=$(command cat -- "$dd_sv/baseline.tsv")
mkdir "$dd_sv/baseline.tsv.tmp"
dd_sv_keep=$(DOTDOCTOR_STATE="$dd_sv" dotdoctor scan --save 2>&1); dd_sv_keep_rc=$?
assert_contains "scan --save: a write that fails prints the not-saved error" "$dd_sv_keep" "baseline not saved"
assert_eq "scan --save: a failed write exits 1" "$dd_sv_keep_rc" "1"
assert_eq "scan --save: a failed write keeps the old baseline" "$(command cat -- "$dd_sv/baseline.tsv")" "$dd_sv_before"
command rm -rf "$dd_sv/baseline.tsv.tmp"
printf 'not a folder\n' > "$dd_sv_file"
dd_sv_bad=$(DOTDOCTOR_STATE="$dd_sv_file/state" dotdoctor scan --save 2>&1); dd_sv_bad_rc=$?
assert_contains "scan --save: a state folder that cannot be made prints the not-saved error" "$dd_sv_bad" "baseline not saved"
assert_eq "scan --save: a state folder that cannot be made exits 1" "$dd_sv_bad_rc" "1"
command rm -rf "$dd_sv" "$dd_sv_file"

# Alias leak: dotdoctor update and clean run in a human shell (aliases on) without alias errors.
dd_leak_upd=$(env -u CLAUDECODE -u DOTFILES_AGENT TERM=xterm-256color HOME="$HOME" PATH="$PATH" \
    zsh -f -i -c "source '$DOT_DIR/core/init.zsh' >/dev/null 2>&1; DOTDOCTOR_OFFLINE=1 dotdoctor update" </dev/null 2>&1)
dd_leak_a=no; [[ "$dd_leak_upd" == *"invalid value"* ]] && dd_leak_a=yes
assert_eq "dotdoctor update (human shell): no 'invalid value' from an alias" "$dd_leak_a" "no"
dd_leak_b=no; [[ "$dd_leak_upd" == *"eza:"* ]] && dd_leak_b=yes
assert_eq "dotdoctor update (human shell): no 'eza:' error" "$dd_leak_b" "no"
dd_leak_clean=$(env -u CLAUDECODE -u DOTFILES_AGENT TERM=xterm-256color HOME="$HOME" PATH="$PATH" \
    zsh -f -i -c "source '$DOT_DIR/core/init.zsh' >/dev/null 2>&1; dotdoctor clean" </dev/null 2>&1)
dd_leak_a=no; [[ "$dd_leak_clean" == *"invalid value"* ]] && dd_leak_a=yes
assert_eq "dotdoctor clean (human shell): no 'invalid value' from an alias" "$dd_leak_a" "no"
dd_leak_b=no; [[ "$dd_leak_clean" == *"eza:"* ]] && dd_leak_b=yes
assert_eq "dotdoctor clean (human shell): no 'eza:' error" "$dd_leak_b" "no"

# Kernel purge list: the running (2.0.0-1) and newest (3.0.0-1) kernels are never purged.
dd_kbin="/tmp/test_dd_kernel_bin"
command rm -rf "$dd_kbin"; mkdir -p "$dd_kbin"
printf '#!/bin/sh\necho "ii  linux-image-1.0.0-1-generic"\necho "ii  linux-image-2.0.0-1-generic"\necho "ii  linux-image-3.0.0-1-generic"\n' > "$dd_kbin/dpkg"
printf '#!/bin/sh\necho "linux-image-1.0.0-1-generic"\necho "linux-image-2.0.0-1-generic"\necho "linux-image-3.0.0-1-generic"\n' > "$dd_kbin/dpkg-query"
printf '#!/bin/sh\necho 2.0.0-1-generic\n' > "$dd_kbin/uname"
chmod +x "$dd_kbin/dpkg" "$dd_kbin/dpkg-query" "$dd_kbin/uname"
dd_kern=$(PATH="$dd_kbin:$PATH" DOTDOCTOR_OFFLINE=1 dotdoctor update </dev/null 2>&1)
dd_purge=$(print -r -- "$dd_kern" | command grep 'apt purge')
assert_contains "kernel purge list names the old 1.0.0-1 image" "$dd_purge" "1.0.0-1"
dd_kbad=no; [[ "$dd_purge" == *"2.0.0-1"* || "$dd_purge" == *"3.0.0-1"* ]] && dd_kbad=yes
assert_eq "kernel purge list keeps the running 2.0.0-1 and newest 3.0.0-1" "$dd_kbad" "no"
command rm -rf "$dd_kbin"

# Kernel ABI: the newest is picked by ABI (6.8.0-40), so both of its flavours stay; the running 6.8.0-31 stays too.
dd_kabi="/tmp/test_dd_kernel_abi_bin"
command rm -rf "$dd_kabi"; mkdir -p "$dd_kabi"
print -rl -- '#!/bin/sh' 'echo "ii  linux-image-6.5.0-10-generic"' 'echo "ii  linux-image-6.8.0-31-generic"' \
    'echo "ii  linux-image-6.8.0-40-generic"' 'echo "ii  linux-image-6.8.0-40-lowlatency"' > "$dd_kabi/dpkg"
print -rl -- '#!/bin/sh' 'echo linux-image-6.5.0-10-generic' 'echo linux-headers-6.5.0-10-generic' \
    'echo linux-modules-6.5.0-10-generic' 'echo linux-image-6.8.0-31-generic' 'echo linux-headers-6.8.0-31-generic' \
    'echo linux-image-6.8.0-40-generic' 'echo linux-headers-6.8.0-40-generic' \
    'echo linux-image-6.8.0-40-lowlatency' 'echo linux-headers-6.8.0-40-lowlatency' > "$dd_kabi/dpkg-query"
print -rl -- '#!/bin/sh' 'echo 6.8.0-31-generic' > "$dd_kabi/uname"
chmod +x "$dd_kabi/dpkg" "$dd_kabi/dpkg-query" "$dd_kabi/uname"
dd_kabi_out=$(PATH="$dd_kabi:$PATH" DOTDOCTOR_OFFLINE=1 dotdoctor update </dev/null 2>&1)
dd_kabi_purge=$(print -r -- "$dd_kabi_out" | command grep 'apt purge')
assert_contains "kernel ABI: the old 6.5.0-10 image and its headers and modules are purged" "$dd_kabi_purge" \
    "sudo apt purge linux-image-6.5.0-10-generic linux-headers-6.5.0-10-generic linux-modules-6.5.0-10-generic"
assert_eq "kernel ABI: no 6.8.0 kernel (running 6.8.0-31, newest ABI 6.8.0-40 and its lowlatency flavour) is purged" \
    "$(print -r -- "$dd_kabi_purge" | command grep -c '6\.8\.0')" "0"
command rm -rf "$dd_kabi"

# dotdoctor update --apply runs only the no-root steps. flatpak uninstall --unused is printed under
# "Deletes files" and never run. Fake flatpak, npm, snap and systemctl keep the network and root out.
dd_fp_bin="/tmp/test_dd_flatpak_bin"
dd_fp_calls="$dd_fp_bin/calls.log"
command rm -rf "$dd_fp_bin"; mkdir -p "$dd_fp_bin"
print -rl -- '#!/bin/sh' "echo \"\$*\" >> $dd_fp_calls" 'case "$*" in' \
    '    "remote-ls --updates --user"|"remote-ls --updates --system") echo org.example.App ;;' 'esac' 'exit 0' > "$dd_fp_bin/flatpak"
print -rl -- '#!/bin/sh' 'exit 0' > "$dd_fp_bin/npm"
print -rl -- '#!/bin/sh' 'echo "All snaps up to date."' > "$dd_fp_bin/snap"
print -rl -- '#!/bin/sh' 'exit 0' > "$dd_fp_bin/systemctl"
chmod +x "$dd_fp_bin/flatpak" "$dd_fp_bin/npm" "$dd_fp_bin/snap" "$dd_fp_bin/systemctl"
: > "$dd_fp_calls"
dd_fp_out=$(PATH="$dd_fp_bin:$PATH" dotdoctor update </dev/null 2>&1)
assert_contains "dotdoctor update lists flatpak uninstall under 'Deletes files'" "$dd_fp_out" \
    "Deletes files (--apply asks for each one, even after a):"
assert_contains "dotdoctor update lists the user-scope flatpak uninstall" "$dd_fp_out" "flatpak uninstall --unused --user"
assert_eq "dotdoctor update (no --apply) runs no flatpak uninstall" "$(command grep -c uninstall "$dd_fp_calls")" "0"
dd_fp_runner="$dd_fp_bin/apply.zsh"
print -rl -- "fpath=('$DOT_DIR/functions' \$fpath)" "autoload -Uz dotdoctor dotdoctor-lib dotdoctor-update" \
    "DOTFILES_DIR='$DOT_DIR'" "dotdoctor update --apply" > "$dd_fp_runner"
dd_fp_apply=$(printf 'y\nn\nq\n' | PATH="$dd_fp_bin:$PATH" script -qfec "zsh -f '$dd_fp_runner'" /dev/null 2>&1)
assert_contains "dotdoctor update --apply runs the no-root flatpak update" "$(command cat -- "$dd_fp_calls")" "update --user -y"
assert_eq "dotdoctor update --apply never runs flatpak uninstall" "$(command grep -c uninstall "$dd_fp_calls")" "0"
command rm -rf "$dd_fp_bin"

# Header gates: Snaps and Flatpak show only when their tool is on PATH (and DOTDOCTOR_OFFLINE is not 1).
# The bare PATH holds just the coreutils the update reads, so no real snap, flatpak or apt-get runs.
dd_hd="/tmp/test_dd_header"
dd_hd_zsh="$(whence -p zsh)"
dd_hd_run="fpath=('$DOT_DIR/functions' \$fpath); autoload -Uz dotdoctor dotdoctor-lib dotdoctor-update; DOTFILES_DIR='$DOT_DIR'; dotdoctor update"
command rm -rf "$dd_hd"; mkdir -p "$dd_hd/min" "$dd_hd/snapbin" "$dd_hd/fpbin" "$dd_hd/home"
for dd_hd_c in date sort sed wc tr; do command ln -s "$(whence -p "$dd_hd_c")" "$dd_hd/min/$dd_hd_c"; done
print -rl -- '#!/bin/sh' 'echo "All snaps up to date."' > "$dd_hd/snapbin/snap"
print -rl -- '#!/bin/sh' 'exit 0' > "$dd_hd/fpbin/flatpak"
chmod +x "$dd_hd/snapbin/snap" "$dd_hd/fpbin/flatpak"
dd_hd_absent=$(env -i PATH="$dd_hd/min" HOME="$dd_hd/home" XDG_CONFIG_HOME="$dd_hd/home/.config" "$dd_hd_zsh" -f -c "$dd_hd_run" </dev/null 2>&1)
dd_hd_snap=$(env -i PATH="$dd_hd/snapbin:$dd_hd/min" HOME="$dd_hd/home" XDG_CONFIG_HOME="$dd_hd/home/.config" "$dd_hd_zsh" -f -c "$dd_hd_run" </dev/null 2>&1)
dd_hd_fp=$(env -i PATH="$dd_hd/fpbin:$dd_hd/min" HOME="$dd_hd/home" XDG_CONFIG_HOME="$dd_hd/home/.config" "$dd_hd_zsh" -f -c "$dd_hd_run" </dev/null 2>&1)
assert_eq "dotdoctor update without apt-get on PATH: no System packages header" "$([[ "$dd_hd_absent" == *"System packages (apt)"* ]] && echo yes || echo no)" "no"
assert_eq "dotdoctor update without snap on PATH: no Snaps header" "$([[ "$dd_hd_absent" == *"Snaps"* ]] && echo yes || echo no)" "no"
assert_eq "dotdoctor update without flatpak on PATH: no Flatpak header" "$([[ "$dd_hd_absent" == *"Flatpak"* ]] && echo yes || echo no)" "no"
assert_contains "dotdoctor update with snap on PATH: Snaps header appears" "$dd_hd_snap" "Snaps"
assert_contains "dotdoctor update with flatpak on PATH: Flatpak header appears" "$dd_hd_fp" "Flatpak"
command rm -rf "$dd_hd"

# Clean detection: a user unit whose program is gone, and a git rule with a space in its base.
dd_ch="/tmp/test_dd_clean_home"
command rm -rf "$dd_ch"; mkdir -p "$dd_ch/.config/systemd/user"
printf '[Unit]\nDescription=ghost\n\n[Service]\nExecStart=/nonexistent/bin/ghost\n' > "$dd_ch/.config/systemd/user/ghost.service"
printf '[url "ssh://bad host/"]\n\tinsteadOf = https://example.com/\n' > "$dd_ch/.gitconfig"
dd_clean_fake=$(HOME="$dd_ch" dotdoctor clean </dev/null 2>&1)
assert_contains "dotdoctor clean names the dangling ghost.service unit" "$dd_clean_fake" "ghost.service"
assert_contains "dotdoctor clean names the bad insteadOf rewrite rule" "$dd_clean_fake" "ssh://bad host/"
assert_contains "dotdoctor clean: a bad insteadOf rule prints the Git rewrite rules header" "$dd_clean_fake" "Git rewrite rules"
command rm -rf "$dd_ch"
dd_gn="/tmp/test_dd_clean_empty_gitconfig"
command rm -rf "$dd_gn"; mkdir -p "$dd_gn"; : > "$dd_gn/.gitconfig"
dd_gn_out=$(HOME="$dd_gn" XDG_CONFIG_HOME="$dd_gn/.config" dotdoctor clean </dev/null 2>&1)
assert_eq "dotdoctor clean: an empty .gitconfig prints no Git rewrite rules header" "$([[ "$dd_gn_out" == *"Git rewrite rules"* ]] && echo yes || echo no)" "no"
command rm -rf "$dd_gn"

# --apply removes only the flagged insteadOf value: the valid gh: value stays in the same section, and the old .gitconfig
# is copied to removed/<stamp>/ first. XDG_CONFIG_HOME is pointed at the fixture so a real git config is never read.
dd_ca="/tmp/test_dd_clean_apply"
dd_ca_home="$dd_ca/home"; dd_ca_state="$dd_ca/state"; dd_ca_bin="$dd_ca/bin"
command rm -rf "$dd_ca"; mkdir -p "$dd_ca_home" "$dd_ca_bin"
printf '[url "https://github.com/"]\n\tinsteadOf = gh:\n\tinsteadOf = ssh://bad host/\n' > "$dd_ca_home/.gitconfig"
print -rl -- '#!/bin/sh' 'exit 0' > "$dd_ca_bin/systemctl"
chmod +x "$dd_ca_bin/systemctl"
dd_ca_runner="$dd_ca_bin/apply.zsh"
print -rl -- "fpath=('$DOT_DIR/functions' \$fpath)" "autoload -Uz dotdoctor dotdoctor-lib dotdoctor-clean" \
    "DOTFILES_DIR='$DOT_DIR'" "dotdoctor clean --apply" > "$dd_ca_runner"
dd_ca_out=$(printf 'y\n' | HOME="$dd_ca_home" XDG_CONFIG_HOME="$dd_ca_home/.config" DOTDOCTOR_STATE="$dd_ca_state" \
    PATH="$dd_ca_bin:$PATH" script -qfec "zsh -f '$dd_ca_runner'" /dev/null 2>&1)
assert_contains "clean --apply reports the insteadOf value it removed" "$dd_ca_out" \
    "removed insteadOf ssh://bad host/ from url.https://github.com/"
assert_eq "clean --apply keeps the valid gh: value in the same section" \
    "$(HOME="$dd_ca_home" XDG_CONFIG_HOME="$dd_ca_home/.config" git config --global --get-all 'url.https://github.com/.insteadof')" "gh:"
dd_ca_backup=("$dd_ca_state"/removed/*/.gitconfig(N))
assert_eq "clean --apply copies the old .gitconfig into removed/<stamp>/" "$#dd_ca_backup" "1"
assert_contains "clean --apply: the backup still holds the removed value" "$(command cat -- "${dd_ca_backup[1]}")" "ssh://bad host/"
command rm -rf "$dd_ca"

# python-brotli: the fixed version is read from the [fixes] of the versions.toml in DOTFILES_DIR (3.0.0 here, not 1.2.1).
dd_bv="/tmp/test_dd_brotli_versions"; dd_bh="/tmp/test_dd_brotli_home"
command rm -rf "$dd_bv" "$dd_bh"; mkdir -p "$dd_bv"
mkdir -p "$dd_bh/.local/share/uv/tools/fake/lib/python3.12/site-packages/brotli-2.5.0.dist-info"
printf '[fixes]\npython-brotli = { fixed = "3.0.0", released = "2026-01-01", cve = "CVE-2026-0002", affected = "0 2.9.9" }\n' > "$dd_bv/versions.toml"
dd_bv_out=$(HOME="$dd_bh" DOTFILES_DIR="$dd_bv" dotdoctor clean </dev/null 2>&1)
assert_contains "clean: python brotli 2.5.0 is below the fixed 3.0.0 from versions.toml" "$dd_bv_out" "python brotli 2.5.0 is below 3.0.0"
command rm -rf "$dd_bv" "$dd_bh"

# --advisories: a canned OSV.dev answer (fake curl, real jq) names a HIGH advisory for the installed tool.
dd_osv="/tmp/test_dd_osv"
command rm -rf "$dd_osv"; mkdir -p "$dd_osv/fakes" "$dd_osv/home"
printf '[tools]\nfaketool = { version = "1.0.0", released = "2026-01-01" }\n\n[osv]\nfaketool = "npm:faketool"\n' > "$dd_osv/versions.toml"
print 14 > "$dd_osv/.freshness"
printf '#!/bin/sh\necho "faketool 1.0.0"\n' > "$dd_osv/fakes/faketool"; chmod +x "$dd_osv/fakes/faketool"
print -r -- '{"vulns":[{"id":"GHSA-test-0001","aliases":["PYSEC-test-0001"],"summary":"out-of-bounds write","database_specific":{"severity":"HIGH"},"affected":[{"package":{"name":"faketool","ecosystem":"npm"},"ranges":[{"type":"SEMVER","events":[{"introduced":"0"},{"fixed":"1.0.5"}]}]},{"package":{"name":"othertool","ecosystem":"npm"},"ranges":[{"type":"SEMVER","events":[{"introduced":"0"},{"fixed":"9.9.9"}]}]}]},{"id":"PYSEC-test-0001","aliases":["GHSA-test-0001"],"summary":"out-of-bounds write","affected":[]}]}' > "$dd_osv/canned.json"
print -rl -- '#!/bin/sh' "cat '$dd_osv/canned.json'" 'exit 0' > "$dd_osv/fakes/curl"; chmod +x "$dd_osv/fakes/curl"
dd_osv_out=$(DOTFILES_DIR="$dd_osv" HOME="$dd_osv/home" PATH="$dd_osv/fakes:/usr/bin:/bin" dotdoctor check --advisories 2>&1); dd_osv_rc=$?
assert_contains "check --advisories names the OSV advisory with its severity" "$dd_osv_out" "faketool 1.0.0: GHSA-test-0001 (HIGH)"
assert_contains "check --advisories names the fixed version" "$dd_osv_out" "fixed in 1.0.5"
assert_eq "check --advisories exits 1 on a HIGH advisory" "$dd_osv_rc" "1"
assert_eq "check --advisories prints an advisory and its alias once" "$(print -r -- "$dd_osv_out" | command grep -c 'test-0001')" "1"
assert_eq "check --advisories ignores fixed versions of other packages" "$([[ "$dd_osv_out" == *"9.9.9"* ]] && echo yes || echo no)" "no"
dd_osv_plain=$(DOTFILES_DIR="$dd_osv" HOME="$dd_osv/home" PATH="$dd_osv/fakes:/usr/bin:/bin" dotdoctor check 2>&1)
assert_eq "plain check does not ask OSV.dev" "$([[ "$dd_osv_plain" == *"GHSA-test"* ]] && echo yes || echo no)" "no"
command rm -rf "$dd_osv"

# install.sh reads a pin only from [tools] and [fonts]: the [osv] row "uv = ..." must not replace the uv pin.
dd_pinfx="/tmp/test_pin_sections"
command rm -rf "$dd_pinfx"; mkdir -p "$dd_pinfx"
printf '[tools]\nuv = { version = "0.12.23", released = "2026-10-03" }\n\n[osv]\nuv = "crates.io:uv"\n' > "$dd_pinfx/versions.toml"
command grep -E '^    _(ver|released)\(\)' "$DOT_DIR/install.sh" > "$dd_pinfx/fns.sh"
assert_eq "install.sh reads the uv version from [tools], not the [osv] row" \
    "$(DOTFILES_DIR="$dd_pinfx" bash -c "source '$dd_pinfx/fns.sh'; _ver uv")" "0.12.23"
assert_eq "install.sh _ver on a tool with no row: empty, status 0 under set -euo pipefail" \
    "$(DOTFILES_DIR="$dd_pinfx" bash -c "set -euo pipefail; source '$dd_pinfx/fns.sh'; v=\$(_ver nosuchtool); r=\$(_released nosuchtool); echo \"reached[\$v][\$r]\"" 2>&1; echo "rc=$?")" \
    $'reached[][]\nrc=0'
assert_eq "install.sh reads the uv release date from [tools], not the [osv] row" \
    "$(DOTFILES_DIR="$dd_pinfx" bash -c "source '$dd_pinfx/fns.sh'; _released uv")" "2026-10-03"
command grep -E '^    curr_(ver|date)=' "$DOT_DIR/update-versions.sh" > "$dd_pinfx/uv.sh"
assert_eq "update-versions.sh reads the uv version and date from [tools], not the [osv] row" \
    "$(VERSIONS_FILE="$dd_pinfx/versions.toml" tool=uv bash -c "source '$dd_pinfx/uv.sh'; echo \"\$curr_ver \$curr_date\"" 2>&1)" "0.12.23 2026-10-03"
command rm -rf "$dd_pinfx"

# l is the colourful listing (eza when installed); ls stays plain.
assert_contains "l is the colourful eza listing" "$(alias l)" "eza --icons=auto --group-directories-first --color=auto"

# The quarantine window comes from <repo>/.freshness (one number of days), in every reader.
dd_fr="/tmp/test_dd_freshness"
command rm -rf "$dd_fr"; mkdir -p "$dd_fr"
printf '[tools]\n' > "$dd_fr/versions.toml"; print 3 > "$dd_fr/.freshness"
assert_contains "dotdoctor check reads the window from .freshness" "$(DOTFILES_DIR="$dd_fr" DOTDOCTOR_OFFLINE=1 dotdoctor check 2>&1)" "quarantine: 3 days"
assert_eq "update-versions.sh reads the window from .freshness" \
    "$(SCRIPT_DIR="$dd_fr" bash -c "$(command grep -E '^MIN_AGE_DAYS=' "$DOT_DIR/update-versions.sh"); echo \$MIN_AGE_DAYS")" "3"
assert_eq "install.sh reads the window from .freshness" \
    "$(DOTFILES_DIR="$dd_fr" bash -c "$(command grep -E '^FRESH_DAYS=' "$DOT_DIR/install.sh"); echo \$FRESH_DAYS")" "3"
command rm -f -- "$dd_fr/.freshness"
dd_fr_out=$(DOTFILES_DIR="$dd_fr" dotdoctor check 2>&1); dd_fr_rc=$?
assert_contains "dotdoctor check without .freshness names the missing file" "$dd_fr_out" ".freshness is missing"
assert_eq "dotdoctor check without .freshness exits 1" "$dd_fr_rc" "1"
command rm -rf "$dd_fr"

# update: a tool behind its pin gets the install.sh step.
dd_dr="/tmp/test_dd_drift"
command rm -rf "$dd_dr"; mkdir -p "$dd_dr/bin"
printf '[tools]\nfaketool = { version = "2.0.0", released = "2026-01-01" }\n' > "$dd_dr/versions.toml"; print 7 > "$dd_dr/.freshness"
printf '#!/bin/sh\necho "faketool 1.0.0"\n' > "$dd_dr/bin/faketool"; chmod +x "$dd_dr/bin/faketool"
dd_dr_out=$(DOTFILES_DIR="$dd_dr" DOTDOCTOR_OFFLINE=1 PATH="$dd_dr/bin:$PATH" dotdoctor update </dev/null 2>&1)
assert_contains "update names a tool behind its pin" "$dd_dr_out" "behind their pin or not installed: faketool"
assert_contains "update offers install.sh --tools-only for it" "$dd_dr_out" "install.sh --tools-only"
command rm -rf "$dd_dr"

# _dd_ask: a = yes to the rest, except questions marked always; q stops.
dd_ak="/tmp/test_dd_ask"
command rm -rf "$dd_ak"; mkdir -p "$dd_ak"
print -rl -- "fpath=('$DOT_DIR/functions' \$fpath)" "autoload -Uz dotdoctor-lib" "DOTFILES_DIR='$DOT_DIR'" "dotdoctor-lib" \
    '_dd_ask one; print "r1=$REPLY"' '_dd_ask two; print "r2=$REPLY"' '_dd_ask three always; print "r3=$?/$REPLY"' '_dd_ask four always; print "r4=$?"' > "$dd_ak/runner.zsh"
dd_ak_out=$(printf 'a\nn\nq\n' | script -qfec "zsh -f '$dd_ak/runner.zsh'" /dev/null 2>&1)
assert_contains "_dd_ask: a answers yes" "$dd_ak_out" "r1=y"
assert_contains "_dd_ask: after a, the next question is yes without asking" "$dd_ak_out" "r2=y"
assert_contains "_dd_ask: an always question still asks after a" "$dd_ak_out" "r3=0/n"
assert_contains "_dd_ask: q stops (status 1)" "$dd_ak_out" "r4=1"
command rm -rf "$dd_ak"

# _dd_ask reads the whole line: the Enter typed after y must not reach the next program's prompt.
command rm -rf "$dd_ak"; mkdir -p "$dd_ak"
print -rl -- "fpath=('$DOT_DIR/functions' \$fpath)" "autoload -Uz dotdoctor-lib" "DOTFILES_DIR='$DOT_DIR'" "dotdoctor-lib" \
    '_dd_ask one; print "r1=$REPLY"' 'read -t 1 -r rest; print "rest=$?"' > "$dd_ak/runner.zsh"
dd_ak_out=$(printf 'y\n' | script -qfec "zsh -f '$dd_ak/runner.zsh'" /dev/null 2>&1)
assert_contains "_dd_ask: y then Enter answers yes" "$dd_ak_out" "r1=y"
assert_contains "_dd_ask: the Enter after y is not left for the next reader" "$dd_ak_out" "rest=1"
command rm -rf "$dd_ak"

# dotdoctor check: y at "Update now?" runs the update, then checks again once, without asking again.
dd_rc="/tmp/test_dd_recheck"
command rm -rf "$dd_rc"; mkdir -p "$dd_rc"
printf '[tools]\nfaketool = { version = "1.0.0", released = "2026-01-01" }\n' > "$dd_rc/versions.toml"
print 7 > "$dd_rc/.freshness"
print -rl -- "fpath=('$DOT_DIR/functions' \$fpath)" "autoload -Uz dotdoctor dotdoctor-lib dotdoctor-check" \
    "DOTFILES_DIR='$dd_rc'" "IS_AGENT=false" 'dotdoctor-update() { print UPDATE-RAN; }' 'dotdoctor check; print "rc=$?"' > "$dd_rc/runner.zsh"
dd_rc_out=$(printf 'y\n' | script -qfec "zsh -f '$dd_rc/runner.zsh'" /dev/null 2>&1)
assert_contains "check: y at Update now? runs the update" "$dd_rc_out" "UPDATE-RAN"
assert_contains "check: then it checks again" "$dd_rc_out" "Checking again after the update"
assert_eq "check: Update now? is asked once" "$(print -r -- "$dd_rc_out" | command grep -c 'Update now?')" "1"
assert_contains "check: returns the second check's status" "$dd_rc_out" "rc=1"
assert_eq "check: the second check prints no banner" "$(print -r -- "$dd_rc_out" | command grep -c 'DOTDOCTOR CHECK')" "1"
assert_eq "check: the re-check prints no stray variable assignment" "$([[ "$dd_rc_out" == *"line="* ]] && echo stray || echo clean)" "clean"
print -rl -- "fpath=('$DOT_DIR/functions' \$fpath)" "autoload -Uz dotdoctor dotdoctor-lib dotdoctor-check" \
    "DOTFILES_DIR='$dd_rc'" "IS_AGENT=false" 'dotdoctor-update() { print "ALL=${DD_APPLY_ALL:-unset}"; }' 'dotdoctor check' > "$dd_rc/runner.zsh"
assert_contains "check: a at Update now? runs every step" "$(printf 'a\n' | script -qfec "zsh -f '$dd_rc/runner.zsh'" /dev/null 2>&1)" "ALL=1"
command rm -rf "$dd_rc"

# Kernel purge by ABI: Pop!_OS's flavourless linux-headers-<abi> goes with its kernel, and headers an
# earlier purge left behind (no image) go too. The purge is listed under "Deletes files".
dd_kpop="/tmp/test_dd_kernel_pop_bin"
command rm -rf "$dd_kpop"; mkdir -p "$dd_kpop"
print -rl -- '#!/bin/sh' 'echo "ii  linux-image-7.0.11-76070011-generic"' 'echo "ii  linux-image-7.1.1-76070101-generic"' > "$dd_kpop/dpkg"
print -rl -- '#!/bin/sh' 'echo linux-headers-6.17.9-76061709' 'echo linux-headers-7.0.11-76070011' \
    'echo linux-headers-7.0.11-76070011-generic' 'echo linux-image-7.0.11-76070011-generic' \
    'echo linux-headers-7.1.1-76070101' 'echo linux-image-7.1.1-76070101-generic' 'echo linux-libc-dev' > "$dd_kpop/dpkg-query"
print -rl -- '#!/bin/sh' 'echo 7.1.1-76070101-generic' > "$dd_kpop/uname"
chmod +x "$dd_kpop/dpkg" "$dd_kpop/dpkg-query" "$dd_kpop/uname"
dd_kpop_out=$(PATH="$dd_kpop:$PATH" DOTDOCTOR_OFFLINE=1 dotdoctor update </dev/null 2>&1)
dd_kpop_purge=$(print -r -- "$dd_kpop_out" | command grep 'apt purge')
assert_contains "kernel purge takes the flavourless and the leftover headers" "$dd_kpop_purge" \
    "sudo apt purge linux-headers-6.17.9-76061709 linux-headers-7.0.11-76070011 linux-headers-7.0.11-76070011-generic linux-image-7.0.11-76070011-generic"
assert_eq "kernel purge keeps the running 7.1.1 kernel" "$(print -r -- "$dd_kpop_purge" | command grep -c '7\.1\.1')" "0"
assert_contains "kernel purge is listed under Deletes files" "$(print -r -- "$dd_kpop_out" | sed -n '/Deletes files/,$p')" "apt purge"
command rm -rf "$dd_kpop"

# npm that came with Node in a root-owned folder (NodeSource: /usr/lib/node_modules) gets no
# self-update step; npm in a folder you own gets one, without sudo.
dd_np="/tmp/test_dd_npm"
command rm -rf "$dd_np"; mkdir -p "$dd_np/min" "$dd_np/bin" "$dd_np/home" "$dd_np/own"
for dd_np_c in date sort sed wc tr awk tail head grep cut uname stat; do command ln -s "$(whence -p "$dd_np_c")" "$dd_np/min/$dd_np_c"; done
print -rl -- '#!/bin/sh' 'case "$1" in' \
    '    outdated) printf "Package  Current  Wanted  Latest  Location\nnpm  10.9.9  10.9.9  12.2.1  global\n" ;;' \
    '    root) echo "$DD_NPM_ROOT" ;;' 'esac' > "$dd_np/bin/npm"
chmod +x "$dd_np/bin/npm"
dd_np_run="fpath=('$DOT_DIR/functions' \$fpath); autoload -Uz dotdoctor dotdoctor-lib dotdoctor-update; DOTFILES_DIR='$DOT_DIR'; dotdoctor update"
dd_np_sys=$(env -i PATH="$dd_np/bin:$dd_np/min" HOME="$dd_np/home" DD_NPM_ROOT=/ "$(whence -p zsh)" -f -c "$dd_np_run" </dev/null 2>&1)
dd_np_own=$(env -i PATH="$dd_np/bin:$dd_np/min" HOME="$dd_np/home" DD_NPM_ROOT="$dd_np/own" "$(whence -p zsh)" -f -c "$dd_np_run" </dev/null 2>&1)
assert_eq "npm in a root-owned folder: no npm self-update step" \
    "$([[ "$dd_np_sys" == *"npm install -g npm@latest"* ]] && echo yes || echo no)" "no"
assert_contains "npm in a root-owned folder: it updates with Node" "$dd_np_sys" "it updates with Node"
assert_contains "npm in a folder you own: the self-update is a no-root step" \
    "$(print -r -- "$dd_np_own" | awk '/No root needed/{f=1;next} /^  [A-Z]/{f=0} f')" "npm install -g npm@latest"
command rm -rf "$dd_np"

# install.sh finds universe in deb822 .sources files (Pop!_OS, Ubuntu 24.04+), not only on deb lines.
dd_un="/tmp/test_universe"
command rm -rf "$dd_un"; mkdir -p "$dd_un/deb822" "$dd_un/list" "$dd_un/none"
print -rl -- 'Types: deb' 'URIs: http://apt.example/ubuntu' 'Suites: jammy' 'Components: main restricted universe multiverse' > "$dd_un/deb822/system.sources"
print -r -- 'deb http://apt.example/ubuntu jammy main universe' > "$dd_un/list/sources.list"
print -rl -- 'Types: deb' 'Components: main restricted' '# deb http://apt.example/ubuntu jammy universe' > "$dd_un/none/system.sources"
command grep -E '^ *_has_universe\(\)' "$DOT_DIR/install.sh" > "$dd_un/fns.sh"
dd_un_res=$(for dd_un_d in deb822 list none; do bash -c "source '$dd_un/fns.sh'; _has_universe '$dd_un/$dd_un_d' && echo $dd_un_d=yes || echo $dd_un_d=no"; done)
assert_eq "install.sh: universe found in deb822 and on deb lines, not in comments" "${(j: :)${(f)dd_un_res}}" "deb822=yes list=yes none=no"
command rm -rf "$dd_un"

# dotdoctor clean: an apt copy of a pinned tool next to the pinned one in ~/.local/bin, and old copies
# that updates left behind. A farm PATH of coreutils plus fakes keeps the real apt and gh out; --apply
# runs in a pty and removes the package through a fake sudo and apt-get.
dd_cl="/tmp/test_clean_dups"
command rm -rf "$dd_cl"; mkdir -p "$dd_cl/home/.local/bin" "$dd_cl/sys" "$dd_cl/bin" "$dd_cl/farm" "$dd_cl/repo" "$dd_cl/state"
for dd_cl_c in date sort sed wc tr awk tail head grep cut uname stat mkdir mv cp find git basename dirname cat ln rm; do
    command ln -s "$(whence -p "$dd_cl_c")" "$dd_cl/farm/$dd_cl_c"
done
printf '[tools]\ngh = { version = "1.0.0", released = "2020-01-01" }\nbun = { version = "1.0.0", released = "2020-01-01" }\n' > "$dd_cl/repo/versions.toml"
print 7 > "$dd_cl/repo/.freshness"
print -rl -- '#!/bin/sh' 'echo "gh version 1.0.0"' > "$dd_cl/home/.local/bin/gh"
print -rl -- '#!/bin/sh' 'echo "gh version 9.9.9"' > "$dd_cl/sys/gh"
print -rl -- '#!/bin/sh' 'echo "bun 1.0.0"' > "$dd_cl/home/.local/bin/bun"
print -rl -- '#!/bin/sh' 'echo "bun 0.9.0"' > "$dd_cl/home/.local/bin/bun.backup-0.9.0-20200101"
print -rl -- '#!/bin/sh' 'echo agy' > "$dd_cl/home/.local/bin/agy"
print -rl -- '#!/bin/sh' 'echo agy' > "$dd_cl/home/.local/bin/agy.1790456114137782733.old"
print -rl -- '#!/bin/sh' 'echo notes' > "$dd_cl/home/.local/bin/notes.old"
print -rl -- '#!/bin/sh' 'case "$1" in -S) echo "gh: $2" ;; esac' > "$dd_cl/bin/dpkg"
print -rl -- '#!/bin/sh' "echo \"apt-get \$*\" >> '$dd_cl/calls'" 'case "$*" in "-s remove gh") echo "Remv gh [9.9.9]" ;; esac' > "$dd_cl/bin/apt-get"
print -rl -- '#!/bin/sh' "echo \"sudo \$*\" >> '$dd_cl/calls'" 'exec "$@"' > "$dd_cl/bin/sudo"
chmod +x "$dd_cl"/sys/* "$dd_cl"/home/.local/bin/* "$dd_cl"/bin/*
dd_cl_path="$dd_cl/sys:$dd_cl/home/.local/bin:$dd_cl/bin:$dd_cl/farm"
dd_cl_out=$(env -i PATH="$dd_cl_path" HOME="$dd_cl/home" DOTDOCTOR_STATE="$dd_cl/state" "$(whence -p zsh)" -f -c \
    "fpath=('$DOT_DIR/functions' \$fpath); autoload -Uz dotdoctor dotdoctor-lib dotdoctor-clean; DOTFILES_DIR='$dd_cl/repo'; dotdoctor clean" </dev/null 2>&1)
assert_contains "clean: names the apt copy of a pinned tool" "$dd_cl_out" "gh is also installed by apt"
assert_contains "clean: gives the version of that copy" "$dd_cl_out" "9.9.9"
assert_contains "clean: names the old bun copy" "$dd_cl_out" "old copy of bun"
assert_contains "clean: names the old agy copy" "$dd_cl_out" "old copy of agy"
assert_eq "clean: a .old file with no sibling is not flagged" "$([[ "$dd_cl_out" == *notes.old* ]] && echo flagged || echo ignored)" "ignored"
print -rl -- "fpath=('$DOT_DIR/functions' \$fpath)" "autoload -Uz dotdoctor dotdoctor-lib dotdoctor-clean" "DOTFILES_DIR='$dd_cl/repo'" "dotdoctor clean --apply" > "$dd_cl/runner.zsh"
dd_cl_script="script -qfec \"env -i PATH='$dd_cl_path' HOME='$dd_cl/home' DOTDOCTOR_STATE='$dd_cl/state' '$(whence -p zsh)' -f '$dd_cl/runner.zsh'\" /dev/null"
printf 'nnn' | eval "$dd_cl_script" >/dev/null 2>&1
assert_eq "clean --apply: n to every question removes nothing" \
    "$(command grep -c 'remove -y' "$dd_cl/calls"; find "$dd_cl/home/.local/bin" -name '*.backup-*' -o -name 'agy.*.old' | wc -l | tr -d ' ')" $'0\n2'
printf 'yyy' | eval "$dd_cl_script" >/dev/null 2>&1
assert_contains "clean --apply: y removes the apt package" "$(command cat -- "$dd_cl/calls")" "sudo apt-get remove -y gh"
assert_eq "clean --apply: the old copies leave ~/.local/bin" "$(find "$dd_cl/home/.local/bin" -name '*.backup-*' -o -name 'agy.*.old' | wc -l | tr -d ' ')" "0"
assert_eq "clean --apply: the old copies are in the backup folder" "$(find "$dd_cl/state/removed" -type f | wc -l | tr -d ' ')" "2"
assert_eq "clean --apply: the pinned gh is untouched" "$([[ -x "$dd_cl/home/.local/bin/gh" ]] && echo there || echo gone)" "there"
command rm -rf "$dd_cl"

# dotdoctor scan lists the programs holding established connections to addresses outside your
# network, with their ports; private peers are left out, and nothing goes into the facts.
dd_ss="/tmp/test_scan_outbound"
command rm -rf "$dd_ss"; mkdir -p "$dd_ss/bin" "$dd_ss/home"
print -rl -- '#!/bin/sh' 'case "$*" in' '    *established*)' \
    '        echo '"'"'0 0 192.168.1.5:43212 142.250.1.1:443 users:(("zzprobe",pid=11,fd=3))'"'"'' \
    '        echo '"'"'0 0 192.168.1.5:43213 142.250.1.1:80 users:(("zzprobe",pid=11,fd=4))'"'"'' \
    '        echo '"'"'0 0 192.168.1.5:50000 192.168.1.9:22 users:(("ssh",pid=12,fd=3))'"'"'' \
    '        echo '"'"'0 0 [2001:db8::5]:40000 [2001:db8::9]:8443 users:(("v6tool",pid=13,fd=3))'"'"' ;;' 'esac' > "$dd_ss/bin/ss"
chmod +x "$dd_ss/bin/ss"
dd_ss_run="fpath=('$DOT_DIR/functions' \$fpath); autoload -Uz dotdoctor dotdoctor-lib dotdoctor-scan; DOTFILES_DIR='$DOT_DIR'"
dd_ss_out=$(env -i PATH="$dd_ss/bin:/usr/bin:/bin" HOME="$dd_ss/home" TERM=dumb "$(whence -p zsh)" -f -c "$dd_ss_run; dotdoctor scan" </dev/null 2>&1)
dd_ss_facts=$(env -i PATH="$dd_ss/bin:/usr/bin:/bin" HOME="$dd_ss/home" TERM=dumb "$(whence -p zsh)" -f -c "$dd_ss_run; dotdoctor scan --facts" </dev/null 2>&1)
assert_contains "scan: lists a program with its outside ports, sorted" "$dd_ss_out" "zzprobe  port(s) 80, 443"
assert_contains "scan: reads an IPv6 peer" "$dd_ss_out" "v6tool  port(s) 8443"
assert_eq "scan: a peer inside your network is not listed" "$([[ "$dd_ss_out" == *"ssh  port"* ]] && echo listed || echo hidden)" "hidden"
assert_eq "scan --facts: outbound connections are not in the facts" "$([[ "$dd_ss_facts" == *zzprobe* ]] && echo leaked || echo clean)" "clean"
command rm -rf "$dd_ss"

# dotdoctor update: Rust toolchain, bun global packages and firmware (fwupd). The rustup and bun steps
# are no-root; the firmware one asks every time, even when everything else was answered with a.
dd_ex="/tmp/test_dd_extra_updaters"
command rm -rf "$dd_ex"; mkdir -p "$dd_ex/min" "$dd_ex/bin" "$dd_ex/home/.bun/install/global" "$dd_ex/repo"
for dd_ex_c in date sort sed wc tr awk tail head grep cut uname stat cksum mkdir timeout; do command ln -s "$(whence -p "$dd_ex_c")" "$dd_ex/min/$dd_ex_c"; done
print '{}' > "$dd_ex/home/.bun/install/global/package.json"
printf '[tools]\n' > "$dd_ex/repo/versions.toml"; print 7 > "$dd_ex/repo/.freshness"
print -rl -- '#!/bin/sh' 'case "$1" in' \
    '    check) echo "stable-x86_64-unknown-linux-gnu - update available: 1.97.1 (8bab26f4f 2026-07-14) -> 1.99.1 (58cf8f9c3 2026-10-13)"; echo "rustup - update available : 1.29.0 -> 1.29.2"; exit 100 ;;' \
    "    update) echo \"rustup update\" >> '$dd_ex/calls' ;;" 'esac' > "$dd_ex/bin/rustup"
print -rl -- '#!/bin/sh' 'case "$*" in' '    "update --help") echo "  -g, --global   Update globally installed packages" ;;' \
    "    \"update --global\") echo \"bun update --global\" >> '$dd_ex/calls' ;;" 'esac' > "$dd_ex/bin/bun"
print -rl -- '#!/bin/sh' 'case "$1" in' '    get-updates) exit 0 ;;' "    *) echo \"fwupdmgr \$*\" >> '$dd_ex/calls' ;;" 'esac' > "$dd_ex/bin/fwupdmgr"
print -rl -- '#!/bin/sh' "echo \"sudo \$*\" >> '$dd_ex/calls'" 'exec "$@"' > "$dd_ex/bin/sudo"
chmod +x "$dd_ex"/bin/*
dd_ex_inv=$(env -i PATH="$dd_ex/bin:$dd_ex/min" HOME="$dd_ex/home" "$(whence -p zsh)" -f -c \
    "fpath=('$DOT_DIR/functions' \$fpath); autoload -Uz dotdoctor dotdoctor-lib dotdoctor-update; DOTFILES_DIR='$dd_ex/repo'; dotdoctor update" </dev/null 2>&1)
assert_contains "update: offers the Rust toolchain update" "$dd_ex_inv" "Update the Rust toolchain"
assert_contains "update: offers the bun global packages update" "$dd_ex_inv" "bun update --global"
assert_contains "update: warns that firmware updates are available" "$dd_ex_inv" "firmware updates are available"
print -rl -- "fpath=('$DOT_DIR/functions' \$fpath)" "autoload -Uz dotdoctor dotdoctor-lib dotdoctor-update" "DOTFILES_DIR='$dd_ex/repo'" "dotdoctor update --apply" > "$dd_ex/runner.zsh"
dd_ex_out=$(printf 'n\n' | script -qfec "env -i PATH='$dd_ex/bin:$dd_ex/min' HOME='$dd_ex/home' DD_APPLY_ALL=1 '$(whence -p zsh)' -f '$dd_ex/runner.zsh'" /dev/null 2>&1)
dd_ex_calls=$(command cat -- "$dd_ex/calls" 2>/dev/null)
assert_contains "update (a): the Rust toolchain update runs without a question" "$dd_ex_calls" "rustup update"
assert_contains "update (a): the bun global update runs without a question" "$dd_ex_calls" "bun update --global"
assert_contains "update (a): firmware still asks, with its command" "$dd_ex_out" "Install the firmware updates (fwupd asks about each one): sudo fwupdmgr refresh; sudo fwupdmgr update [y/n/a/q]"
assert_eq "update (a): n to the firmware question installs nothing" "$([[ "$dd_ex_calls" == *"fwupdmgr update"* ]] && echo installed || echo skipped)" "skipped"
command rm -rf "$dd_ex"

# _dd_run_step: the output goes to the log; one line shows the result, plus the lines matching
# the step's pattern. A failure shows the step's last lines and the log path.
dd_rs="/tmp/test_dd_run_step"
command rm -rf "$dd_rs"; mkdir -p "$dd_rs"
printf '#!/bin/sh\nprintf "\\033[1;33mFound 0 updates\\033[0m\\n"\n' > "$dd_rs/colour.sh"; chmod +x "$dd_rs/colour.sh"
print -rl -- "fpath=('$DOT_DIR/functions' \$fpath)" "autoload -Uz dotdoctor-lib" "DOTFILES_DIR='$DOT_DIR'" "dotdoctor-lib" \
    "DD_LOG='$dd_rs/update.log'" \
    '_dd_run_step "$(_dd_step "Fake step" "print noise; print \"✅ Updated faketool -> v2\"" "Updated")"' \
    '_dd_run_step "$(_dd_step "Broken step" "print oops; false")"' \
    "_dd_run_step \"\$(_dd_step \"Colour step\" \"$dd_rs/colour.sh\" \"Found\")\"" 'print "fails=$DD_FAILS"' > "$dd_rs/runner.zsh"
dd_rs_out=$(zsh -f "$dd_rs/runner.zsh" 2>&1)
assert_contains "_dd_run_step: shows the lines matching the pattern" "$dd_rs_out" "✅ Updated faketool -> v2"
assert_eq "_dd_run_step: hides the rest of the output" "$([[ "$dd_rs_out" == *noise* ]] && echo shown || echo hidden)" "hidden"
assert_contains "_dd_run_step: the log keeps the whole output" "$(command cat -- "$dd_rs/update.log")" "noise"
assert_contains "_dd_run_step: a failed step shows its last lines" "$dd_rs_out" "oops"
assert_contains "_dd_run_step: a failed step names the log" "$dd_rs_out" "full log:"
assert_contains "_dd_run_step: a failed step counts as a failure" "$dd_rs_out" "fails=1"
assert_contains "_dd_run_step: a matching line shows" "$dd_rs_out" "Found 0 updates"
assert_eq "_dd_run_step: colour codes from the step are not shown" "$([[ "$dd_rs_out" == *$'\e'* ]] && echo escapes || echo plain)" "plain"
command rm -rf "$dd_rs"

# DD_APPLY_ALL=1 (a at "Update now?"): every step runs without a question, sudo ones too;
# steps that delete files still ask. A bare PATH of fakes keeps root and the network out.
dd_aa="/tmp/test_dd_apply_all"
command rm -rf "$dd_aa"; mkdir -p "$dd_aa/min" "$dd_aa/bin" "$dd_aa/home" "$dd_aa/repo"
for dd_aa_c in date sort sed wc tr awk tail head grep cut uname stat cksum mkdir; do command ln -s "$(whence -p "$dd_aa_c")" "$dd_aa/min/$dd_aa_c"; done
printf '[tools]\n' > "$dd_aa/repo/versions.toml"; print 7 > "$dd_aa/repo/.freshness"
print -rl -- '#!/bin/sh' "echo \"\$*\" >> '$dd_aa/calls'" 'case "$*" in' \
    '    "remote-ls --updates --user"|"remote-ls --updates --system") echo org.example.App ;;' \
    '    update*) echo flatpak-noise ;;' 'esac' 'exit 0' > "$dd_aa/bin/flatpak"
print -rl -- '#!/bin/sh' "echo \"sudo \$*\" >> '$dd_aa/calls'" 'case "$1" in -n|-v) exit 0 ;; esac' 'exec "$@"' > "$dd_aa/bin/sudo"
chmod +x "$dd_aa/bin/flatpak" "$dd_aa/bin/sudo"
print -rl -- "fpath=('$DOT_DIR/functions' \$fpath)" "autoload -Uz dotdoctor dotdoctor-lib dotdoctor-update" \
    "DOTFILES_DIR='$dd_aa/repo'" "DD_APPLY_ALL=1" "dotdoctor update --apply" > "$dd_aa/runner.zsh"
dd_aa_out=$(printf 'n\nn\n' | env -i PATH="$dd_aa/bin:$dd_aa/min" HOME="$dd_aa/home" "$(whence -p script)" -qfec "$(whence -p zsh) -f '$dd_aa/runner.zsh'" /dev/null 2>&1)
dd_aa_calls=$(command cat -- "$dd_aa/calls" 2>/dev/null)
assert_contains "apply all: the user Flatpak update runs without a question" "$dd_aa_calls" "update --user -y"
assert_contains "apply all: the sudo Flatpak update runs too" "$dd_aa_calls" "update --system -y"
assert_eq "apply all: steps that delete files still ask (answered n)" "$(print -r -- "$dd_aa_calls" | command grep -c uninstall)" "0"
assert_eq "apply all: no question for a step that deletes nothing" \
    "$([[ "$dd_aa_out" == *"Update the Flatpak apps (user) [y/n/a/q]"* ]] && echo asked || echo not-asked)" "not-asked"
assert_eq "apply all: the step's output stays out of the terminal" "$([[ "$dd_aa_out" == *flatpak-noise* ]] && echo shown || echo hidden)" "hidden"
assert_contains "apply all: the step's output is in the log" "$(command cat -- "$dd_aa/home/.cache/dotdoctor/update.log" 2>/dev/null)" "flatpak-noise"
command rm -rf "$dd_aa"

# install.sh --tools-only runs step 5 only: no apt, no sudo, no doctor, no new shell. Every pinned tool
# in ~/.local/bin answers 99.0.0, newer than any pin, so nothing is downloaded; fake sudo, curl and apt log a call.
dd_to="/tmp/test_install_tools_only"
command rm -rf "$dd_to"; mkdir -p "$dd_to/bin" "$dd_to/home" "$dd_to/repo"
command cp -p "$DOT_DIR/install.sh" "$DOT_DIR/.freshness" "$dd_to/repo/"
sed -E 's/released = "[0-9-]+"/released = "2020-01-01"/' "$DOT_DIR/versions.toml" > "$dd_to/repo/versions.toml"
mkdir -p "$dd_to/home/.local/bin"
for dd_to_t in ${(f)"$(awk '/^\[/{s = ($0 == "[tools]")} s && /^[a-z0-9_-]+ *= *\{/{sub(/ .*/, ""); print}' "$dd_to/repo/versions.toml")"}; do
    print -rl -- '#!/bin/sh' "echo '$dd_to_t 99.0.0'" > "$dd_to/home/.local/bin/$dd_to_t"
done
chmod +x "$dd_to/home/.local/bin"/*
for dd_to_t in sudo curl wget apt apt-get; do
    print -rl -- '#!/bin/sh' "echo \"$dd_to_t \$*\" >> '$dd_to/calls'" 'exit 1' > "$dd_to/bin/$dd_to_t"
done
chmod +x "$dd_to"/bin/*
dd_to_out=$(env -i PATH="$dd_to/bin:/usr/bin:/bin" HOME="$dd_to/home" "$(whence -p bash)" "$dd_to/repo/install.sh" --tools-only </dev/null 2>&1); dd_to_rc=$?
assert_eq "install.sh --tools-only exits 0" "$dd_to_rc" "0"
assert_contains "install.sh --tools-only runs the pinned-tool step" "$dd_to_out" "[5/7] Pinned tools"
assert_eq "install.sh: tools all current print one step line and no per-tool line" \
    "$([[ "$dd_to_out" != *"📦"* && "$dd_to_out" != *"✅  "* && "$(print -r -- "$dd_to_out" | command grep -c '▸')" == 1 ]] && echo quiet || echo noisy)" "quiet"
assert_eq "install.sh --tools-only skips system setup, doctor and the new shell" \
    "$([[ "$dd_to_out" == *"[1/7]"* || "$dd_to_out" == *"[7/7]"* || "$dd_to_out" == *"Launching zsh"* ]] && echo ran || echo skipped)" "skipped"
assert_eq "install.sh --tools-only calls no sudo, apt or curl" "$(command cat -- "$dd_to/calls" 2>/dev/null)" ""

# doctor.zsh --quiet prints no passing check and no banner; the old --quiet still printed the banner and rules.
dd_dq_out=$(zsh "$DOT_DIR/doctor.zsh" --quiet 2>&1)
assert_eq "doctor --quiet prints no passing (✓) line" "$([[ "$dd_dq_out" == *"✓"* ]] && echo shown || echo hidden)" "hidden"
assert_eq "doctor --quiet prints no banner or rule" "$([[ "$dd_dq_out" == *"DOTFILES DOCTOR"* || "$dd_dq_out" == *"====="* ]] && echo shown || echo hidden)" "hidden"
assert_eq "doctor --quiet with NO_COLOR prints no escape code" \
    "$([[ "$(NO_COLOR=1 zsh "$DOT_DIR/doctor.zsh" --quiet 2>&1)" == *$'\033'* ]] && echo escape || echo plain)" "plain"

# A newer gh outside ~/.local/bin (apt's) does not stop the pin: the installer goes for the pinned one.
command rm -f "$dd_to/home/.local/bin/gh" "$dd_to/home/.local/bin/zoxide"
print -rl -- '#!/bin/sh' "echo 'gh version 99.0.0'" > "$dd_to/bin/gh"; chmod +x "$dd_to/bin/gh"
dd_to_out=$(env -i PATH="$dd_to/bin:/usr/bin:/bin" HOME="$dd_to/home" "$(whence -p bash)" "$dd_to/repo/install.sh" --tools-only </dev/null 2>&1); dd_to_rc=$?
assert_contains "install.sh: a failed tool does not stop the next one" "$dd_to_out" "Download failed for zoxide"
assert_contains "install.sh: the failed tools are listed at the end" "$dd_to_out" "Not installed: gh zoxide"
assert_eq "install.sh: a failed tool makes the run exit 1" "$dd_to_rc" "1"
assert_contains "install.sh: a newer apt gh does not keep the pin out of ~/.local/bin" "$dd_to_out" "Download failed for gh"
assert_eq "install.sh: no 'newer than the pin' keep for a copy outside ~/.local/bin" \
    "$([[ "$dd_to_out" == *"gh 99.0.0 is newer than the pin"* ]] && echo kept || echo installs)" "installs"
command rm -rf "$dd_to"

# _resolve_gh_asset finds a release asset by name regex, with or without a v in the tag, and returns
# its digest; _place_bin replaces a symlink instead of writing through it into the file it points at.
dd_gr="/tmp/test_gh_resolve"
command rm -rf "$dd_gr"; mkdir -p "$dd_gr/bin" "$dd_gr/home/.local/bin"
awk '/^    _(resolve_gh_asset|place_bin)\(\) \{/{p=1} p{print} p&&/^    \}/{p=0}' "$DOT_DIR/install.sh" > "$dd_gr/fns.sh"
print -r -- '{"assets":[{"name":"tool-2.0.0-x86_64-linux.tar.gz","browser_download_url":"https://example.invalid/x86_64","digest":"sha256:abc123"},{"name":"tool-2.0.0-aarch64-linux.tar.gz","browser_download_url":"https://example.invalid/aarch64","digest":"sha256:fff"}]}' > "$dd_gr/release.json"
print -rl -- '#!/bin/sh' 'case "$*" in' "    *\"/releases/tags/2.0.0\"*) cat '$dd_gr/release.json' ;;" '    *) exit 22 ;;' 'esac' > "$dd_gr/bin/curl"
chmod +x "$dd_gr/bin/curl"
dd_gr_hit=$(PATH="$dd_gr/bin:/usr/bin:/bin" bash -c "source '$dd_gr/fns.sh'; _resolve_gh_asset 'gh:o/r|2.0.0|tool-[0-9.]+-x86_64-linux\\.tar\\.gz\$'" 2>&1 | tr '\t' '|')
assert_eq "_resolve_gh_asset: finds the asset on the tag without a v, with its digest" "$dd_gr_hit" "https://example.invalid/x86_64|sha256:abc123"
PATH="$dd_gr/bin:/usr/bin:/bin" bash -c "source '$dd_gr/fns.sh'; _resolve_gh_asset 'gh:o/r|2.0.0|nothing-matches'" >/dev/null 2>&1
assert_eq "_resolve_gh_asset: no matching asset fails" "$?" "1"
print old > "$dd_gr/target"; ln -s "$dd_gr/target" "$dd_gr/home/.local/bin/x"; print new > "$dd_gr/src"
HOME="$dd_gr/home" bash -c "source '$dd_gr/fns.sh'; _place_bin '$dd_gr/src' x" >/dev/null 2>&1
assert_eq "_place_bin: the file a symlink pointed at is left alone" "$(command cat -- "$dd_gr/target")" "old"
assert_eq "_place_bin: the new file replaces the symlink and is executable" \
    "$([[ ! -L "$dd_gr/home/.local/bin/x" && -x "$dd_gr/home/.local/bin/x" && "$(command cat -- "$dd_gr/home/.local/bin/x")" == new ]] && echo yes || echo no)" "yes"
command rm -rf "$dd_gr"

# update-versions.sh adds a row for a tool in REPOS that has none yet (into [tools]) and still
# updates the rows it has. A fake curl serves one release for every repository.
dd_uv="/tmp/test_update_versions"
command rm -rf "$dd_uv"; mkdir -p "$dd_uv/bin" "$dd_uv/repo"
command cp -p "$DOT_DIR/update-versions.sh" "$dd_uv/repo/"; print 7 > "$dd_uv/repo/.freshness"
printf '[tools]\nbat = { version = "0.1.0", released = "2020-01-01" }\n\n[fonts]\nfiracode-nerd = { version = "0.1.0", released = "2020-01-01" }\n\n[fixes]\nrg-note = { fixed = "1" }\n' > "$dd_uv/repo/versions.toml"
print -rl -- '#!/bin/sh' 'echo "[{\"tag_name\":\"v1.2.3\",\"published_at\":\"2020-02-01T00:00:00Z\",\"draft\":false,\"prerelease\":false}]"' > "$dd_uv/bin/curl"
print -rl -- '#!/bin/sh' 'exit 1' > "$dd_uv/bin/gh"
chmod +x "$dd_uv/bin/curl" "$dd_uv/bin/gh"
dd_uv_out=$(env -i PATH="$dd_uv/bin:/usr/bin:/bin" HOME="$dd_uv/home" "$(whence -p bash)" "$dd_uv/repo/update-versions.sh" --apply 2>&1)
assert_contains "update-versions: a tool with no row is added" "$dd_uv_out" "Added rg -> v1.2.3 (2020-02-01)"
assert_contains "update-versions: a tool with a row is still updated" "$dd_uv_out" "Updated bat -> v1.2.3"
assert_eq "update-versions: the new row is in [tools]" \
    "$(awk '/^\[/{s = ($0 == "[tools]")} s && /^rg =/' "$dd_uv/repo/versions.toml")" 'rg = { version = "1.2.3", released = "2020-02-01" }'
assert_eq "update-versions: nothing is added to [fixes] and the font row is not duplicated" \
    "$(command grep -c '^firacode-nerd\|^rg =' "$dd_uv/repo/versions.toml")" "2"
# A release published on the cutoff day counts, whatever the hour: the installer and dotdoctor compare dates too.
dd_uv_cut=$(date -d "-7 days" +%F)
print -rl -- '#!/bin/sh' "echo \"[{\\\"tag_name\\\":\\\"v9.9.9\\\",\\\"published_at\\\":\\\"${dd_uv_cut}T23:59:59Z\\\",\\\"draft\\\":false,\\\"prerelease\\\":false}]\"" > "$dd_uv/bin/curl"
dd_uv_out=$(env -i PATH="$dd_uv/bin:/usr/bin:/bin" HOME="$dd_uv/home" "$(whence -p bash)" "$dd_uv/repo/update-versions.sh" --apply 2>&1)
assert_contains "update-versions: a release from the cutoff day counts, whatever the hour" "$dd_uv_out" "Updated bat -> v9.9.9"
command rm -rf "$dd_uv"

# update-versions.sh takes the highest safe version, not the latest publish: 1.16.7 went out after 1.17.0,
# and 1.17.1 is inside the 7-day quarantine. Release dates are relative to today, so the fixture stays in the window.
dd_uvv="/tmp/test_update_versions_order"
command rm -rf "$dd_uvv"; mkdir -p "$dd_uvv/bin" "$dd_uvv/repo" "$dd_uvv/home"
command cp -p "$DOT_DIR/update-versions.sh" "$dd_uvv/repo/"; print 7 > "$dd_uvv/repo/.freshness"
typeset -A dd_uvv_at=()
for dd_n in 4 10 11 18 25 30; do dd_uvv_at[$dd_n]=$(date -d "-$dd_n days" +%FT12:00:00Z 2>/dev/null || date -v-${dd_n}d +%FT12:00:00Z); done
printf '[tools]\nterraform = { version = "1.16.7", released = "%s" }\nterraform-ls = { version = "1.17.0", released = "%s" }\nrg = { version = "9.9.9", released = "%s" }\n' \
    "${dd_uvv_at[10]%%T*}" "${dd_uvv_at[11]%%T*}" "${dd_uvv_at[11]%%T*}" > "$dd_uvv/repo/versions.toml"
dd_uvv_rel="[{\"tag_name\":\"v1.17.1\",\"published_at\":\"${dd_uvv_at[4]}\",\"draft\":false,\"prerelease\":false},{\"tag_name\":\"v1.16.7\",\"published_at\":\"${dd_uvv_at[10]}\",\"draft\":false,\"prerelease\":false},{\"tag_name\":\"v1.17.0\",\"published_at\":\"${dd_uvv_at[11]}\",\"draft\":false,\"prerelease\":false},{\"tag_name\":\"v1.17.0-rc2\",\"published_at\":\"${dd_uvv_at[18]}\",\"draft\":false,\"prerelease\":true},{\"tag_name\":\"v1.16.6\",\"published_at\":\"${dd_uvv_at[18]}\",\"draft\":false,\"prerelease\":false},{\"tag_name\":\"v1.17.0-rc1\",\"published_at\":\"${dd_uvv_at[25]}\",\"draft\":false,\"prerelease\":true},{\"tag_name\":\"v1.16.5\",\"published_at\":\"${dd_uvv_at[30]}\",\"draft\":false,\"prerelease\":false}]"
print -r -- "$dd_uvv_rel" > "$dd_uvv/releases.json"
print -rl -- '#!/bin/sh' "cat '$dd_uvv/releases.json'" > "$dd_uvv/bin/curl"
print -rl -- '#!/bin/sh' 'exit 1' > "$dd_uvv/bin/gh"
chmod +x "$dd_uvv/bin/curl" "$dd_uvv/bin/gh"
dd_uvv_out=$(env -i PATH="$dd_uvv/bin:/usr/bin:/bin" HOME="$dd_uvv/home" "$(whence -p bash)" "$dd_uvv/repo/update-versions.sh" 2>&1 </dev/null | sed $'s/\e\\[[0-9;]*m//g')
dd_uvv_tf=$(print -r -- "$dd_uvv_out" | awk '$1=="terraform"{print $2, $3, $4}')
assert_eq "update-versions: 1.17.0 is chosen over 1.16.7, which was published later" "$dd_uvv_tf" "1.16.7 1.17.0 ${dd_uvv_at[11]%%T*}"
assert_eq "update-versions: 1.17.1, inside the quarantine, is not chosen" \
    "$([[ "$dd_uvv_tf" == *1.17.1* ]] && echo yes || echo no)" "no"
dd_uvv_ls=$(print -r -- "$dd_uvv_out" | awk '$1=="terraform-ls"')
assert_contains "update-versions: a pin that is the highest safe version is up to date" "$dd_uvv_ls" "up to date"
dd_uvv_rg=$(print -r -- "$dd_uvv_out" | awk '$1=="rg"')
assert_eq "update-versions: a pin above every safe version is kept, not downgraded" \
    "$(print -r -- "$dd_uvv_rg" | awk '{print $3}')" "9.9.9"
assert_contains "update-versions: a pin above every safe version reports up to date" "$dd_uvv_rg" "up to date"
command rm -rf "$dd_uvv"

# --- Failed trash commands print no success mark ------------------------------
# Shell functions stand in for the tools (they win over the PATH mocks); each runs in a subshell.
dd_fs=/tmp/test_failmarks
command rm -rf "$dd_fs"; mkdir -p "$dd_fs/cwd"; print x > "$dd_fs/orig"
dd_fs_run() {  # $1 = stdin text, rest = command; stdout+stderr captured
    ( HAS_FZF=true
      command rm -f -- "$dd_fs/orig" "$dd_fs/cwd/orig"
      trash-list() { [[ -e "$dd_fs/orig" ]] || print -r -- "2024-01-01 10:00:00 $dd_fs/orig"; }
      fzf() { command head -1; }
      # Lists its one entry, and restores only when it is handed an index.
      trash-restore() { local pick; read -r pick; print -r -- "   0 2024-01-01 10:00:00 $dd_fs/orig"
          [[ -n "$pick" ]] || return 0; (( ${DD_RESTORE_RC:-0} )) && return $DD_RESTORE_RC; print x > "$dd_fs/orig"; }
      trash-empty() { return ${DD_EMPTY_RC:-0}; }
      mv() { (( ${DD_MV_RC:-0} )) && return $DD_MV_RC; command mv "$@"; }
      cd "$dd_fs/cwd"
      print -r -- "$1" | "${@:2}" 2>&1 )
}
dd_fs_o=$(DD_RESTORE_RC=1 dd_fs_run 1 rt)
assert_eq "rt option 1: failed trash-restore prints no ok mark (old code printed it)" \
    "$([[ "$dd_fs_o" == *"✅"* ]] && echo yes || echo no)" "no"
assert_contains "rt option 1: failed trash-restore prints an error mark" "$dd_fs_o" "❌"
assert_eq "rt option 1: failed trash-restore returns 1 (old code returned 0)" "$(DD_RESTORE_RC=1 dd_fs_run 1 rt >/dev/null; echo $?)" "1"
dd_fs_o=$(dd_fs_run 1 rt)
assert_contains "rt option 1: successful restore still prints the ok mark" "$dd_fs_o" "✅"
dd_fs_o=$(DD_RESTORE_RC=1 dd_fs_run 2 rt)
assert_eq "rt option 2: failed trash-restore prints no ok mark (old code printed it)" \
    "$([[ "$dd_fs_o" == *"✅"* ]] && echo yes || echo no)" "no"
dd_fs_o=$(DD_MV_RC=1 dd_fs_run 2 rt)
assert_eq "rt option 2: failed mv prints no ok mark (old code printed it)" \
    "$([[ "$dd_fs_o" == *"✅"* ]] && echo yes || echo no)" "no"
assert_contains "rt option 2: failed mv prints an error mark" "$dd_fs_o" "❌"
assert_eq "rt option 2: failed mv returns 1 (old code returned 0)" "$(DD_MV_RC=1 dd_fs_run 2 rt >/dev/null; echo $?)" "1"
dd_fs_o=$(dd_fs_run 2 rt)
assert_contains "rt option 2: successful restore and mv still print the ok mark" "$dd_fs_o" "✅"
dd_fs_o=$(DD_EMPTY_RC=1 dd_fs_run y empty-trash)
assert_eq "empty-trash: failed trash-empty prints no ok mark (old code printed it)" \
    "$([[ "$dd_fs_o" == *"✅"* ]] && echo yes || echo no)" "no"
assert_eq "empty-trash: failed trash-empty returns 1 (old code returned 0)" "$(DD_EMPTY_RC=1 dd_fs_run y empty-trash >/dev/null; echo $?)" "1"
dd_fs_o=$(dd_fs_run y empty-trash)
assert_contains "empty-trash: successful trash-empty still prints the ok mark" "$dd_fs_o" "✅"

command rm -rf "$dd_fs"
unfunction dd_fs_run

# --- rm, rt, empty-trash against the real trash-cli (fake HOME and XDG_DATA_HOME) --
# Each case runs in `env -i` zsh -f with PATH=/usr/bin:/bin, so the real tools answer, not the PATH mocks.
tw_root=/tmp/test_rmfix
tw_reset() { command rm -rf "$tw_root"; mkdir -p "$tw_root/home" "$tw_root/xdg" "$tw_root/w" "$tw_root/o"; }
# $1 = script run inside $tw_root/w after the wrapper is loaded; stdout+stderr captured. TW_ENV adds env words.
tw() {
    env -i PATH=/usr/bin:/bin HOME="$tw_root/home" XDG_DATA_HOME="$tw_root/xdg" TERM=dumb TW_PICK="$TW_PICK" \
        HAS_TRASH=true HAS_TRASH_PUT=true HAS_FZF=true ${=TW_ENV} zsh -f -c "
        source '$DOT_DIR/modules/files/trash.zsh'
        cd '$tw_root/w'
        # fzf picks the first entry whose line ends with \$TW_PICK
        fzf() { command awk -v p=\"\$TW_PICK\" 'substr(\$0, length(\$0)-length(p)+1)==p { print; exit }'; }
        $1" </dev/null 2>&1
}
tw_count() { env -i PATH=/usr/bin:/bin HOME="$tw_root/home" XDG_DATA_HOME="$tw_root/xdg" trash-list 2>/dev/null | command wc -l | tr -d ' '; }

if [[ -x /usr/bin/trash-put && -x /usr/bin/trash-list && -x /usr/bin/trash-restore && -x /usr/bin/trash-empty ]]; then
    # A1: the chosen path is a prefix of another entry
    tw_reset
    tw_o=$(TW_PICK=/w/x tw 'print a >xy; print b >x; rm xy; rm x; print 1 | rt')
    assert_eq "rt: picking 'x' brings back x, not xy (old code restored xy)" \
        "$([[ -e $tw_root/w/x && ! -e $tw_root/w/xy ]] && echo ok || echo wrong)" "ok"
    assert_contains "rt: prefix pick prints the ok mark" "$tw_o" "✅"
    assert_eq "rt: prefix pick leaves exactly the other entry trashed" "$(tw_count)" "1"

    # A1b: the same path trashed twice
    tw_reset
    tw_o=$(TW_PICK=/w/x tw 'print one >x; rm x; print two >x; rm x; print 1 | rt')
    assert_eq "rt: duplicate names, one comes back (guards the path; old code also managed)" \
        "$([[ -e $tw_root/w/x ]] && echo yes || echo no)" "yes"
    assert_eq "rt: duplicate names, exactly one entry left in the trash" "$(tw_count)" "1"

    # A2: the entry lives in another directory than the current one
    tw_reset
    tw_o=$(TW_PICK=/o/a tw 'print A >../o/a; print B >b; rm ../o/a; rm b; print 1 | rt')
    assert_eq "rt: an entry from another directory is restored there (old code restored w/b)" \
        "$([[ -e $tw_root/o/a && ! -e $tw_root/w/b ]] && echo ok || echo wrong)" "ok"
    assert_eq "rt: restoring from another directory leaves the other entry trashed" "$(tw_count)" "1"
    tw_reset
    tw_o=$(TW_PICK=/o/a tw 'print A >../o/a; rm ../o/a; command rmdir ../o; print 1 | rt')
    assert_eq "rt: restore recreates a missing parent directory (old code found nothing)" \
        "$(command cat -- "$tw_root/o/a" 2>/dev/null)" "A"

    # A3: the original path is taken again by a live file
    tw_reset
    tw_o=$(TW_PICK=/o/a tw 'print old >../o/a; rm ../o/a; print live >../o/a; print 2 | rt; print rc=$?')
    assert_eq "rt option 2: a live file at the original path is not moved (old code moved it)" \
        "$(command cat -- "$tw_root/o/a" 2>/dev/null)|$([[ -e $tw_root/w/a ]] && echo moved || echo still)" "live|still"
    assert_contains "rt option 2: refusing prints an error mark and rc=1" "$tw_o" "❌"
    assert_contains "rt option 2: refusing returns 1" "$tw_o" "rc=1"
    assert_eq "rt option 2: the refused entry stays in the trash" "$(tw_count)" "1"
    tw_o=$(TW_PICK=/o/a tw 'print 1 | rt; print rc=$?')
    assert_contains "rt option 1: original exists returns 1 (old code printed an error and carried on)" "$tw_o" "rc=1"
    assert_eq "rt option 1: original exists, the live file is intact" "$(command cat -- "$tw_root/o/a")" "live"
    tw_reset
    tw_o=$(TW_PICK=/o/a tw 'print old >../o/a; rm ../o/a; print here >a; print 2 | rt; print rc=$?')
    assert_eq "rt option 2: an existing ./name is not overwritten, nothing restored" \
        "$(command cat -- "$tw_root/w/a")|$([[ -e $tw_root/o/a ]] && echo restored || echo no)|$(tw_count)" "here|no|1"
    tw_reset
    tw_o=$(TW_PICK=/o/a tw 'print old >../o/a; rm ../o/a; print 2 | rt; print rc=$?')
    assert_eq "rt option 2: restore lands in the current directory (old code left it in o)" \
        "$(command cat -- "$tw_root/w/a" 2>/dev/null)|$([[ -e $tw_root/o/a ]] && echo left || echo gone)" "old|gone"
    assert_contains "rt option 2: success prints the ok mark" "$tw_o" "✅"

    # B2, C3: operands
    tw_reset
    tw_o=$(tw 'print a >keep; rm keep nope; print rc=$?')
    assert_contains "rm: a missing operand without -f is reported (old code was silent)" "$tw_o" "rm: cannot remove 'nope': No such file or directory"
    assert_contains "rm: a missing operand without -f makes rc 1 (old code returned 0)" "$tw_o" "rc=1"
    assert_eq "rm: the existing operand is still trashed" "$([[ -e $tw_root/w/keep ]] && echo kept || echo gone)" "gone"
    tw_o=$(tw 'rm -f nope also-nope; print rc=$?')
    assert_eq "rm -f on missing operands is silent and 0" "$tw_o" "rc=0"
    tw_o=$(tw 'rm nope; print rc=$?')
    assert_contains "rm of one missing path prints the rm-style error" "$tw_o" "rm: cannot remove 'nope'"
    tw_o=$(tw 'rm; print rc=$?')
    assert_contains "rm with no operand says so (old code was silent)" "$tw_o" "rm: missing operand"
    assert_contains "rm with no operand returns 1 (old code returned 0)" "$tw_o" "rc=1"
    tw_reset
    tw_o=$(tw 'rm .; print rc=$?')
    assert_contains "rm . is refused with an error mark (old code returned 0)" "$tw_o" "❌"
    assert_contains "rm . returns 1" "$tw_o" "rc=1"
    tw_o=$(tw 'rm ..; print rc=$?')
    assert_contains "rm .. is refused and returns 1" "$tw_o" "rc=1"
    assert_eq "rm . and rm .. trash nothing" "$(tw_count)" "0"
    tw_reset
    tw_o=$(tw 'print a >keep; rm keep "$HOME"; print rc=$?')
    assert_eq "rm of \$HOME is refused as a whole: the other operand stays too (old code trashed both)" \
        "$([[ -e $tw_root/w/keep ]] && echo kept || echo gone)|$([[ -d $tw_root/home ]] && echo home-ok || echo home-gone)|$(tw_count)" "kept|home-ok|0"
    assert_contains "rm of \$HOME returns 1" "$tw_o" "rc=1"
    tw_o=$(tw 'rm -rf /; print rc=$?')
    assert_contains "rm -rf / is refused" "$tw_o" "rc=1"
    tw_o=$(tw 'rm -rf "$HOME/"; print rc=$?')
    assert_contains "rm of \$HOME/ with a trailing slash is refused" "$tw_o" "rc=1"
    tw_o=$(tw 'ln -s "$HOME" lnk; rm lnk; print rc=$?')
    assert_eq "rm of a symlink that points at \$HOME removes the link only" \
        "$tw_o|$([[ -L $tw_root/w/lnk ]] && echo link-left || echo link-gone)|$([[ -d $tw_root/home ]] && echo home-ok || echo home-gone)" "rc=0|link-gone|home-ok"
    tw_reset
    tw_o=$(tw 'mkdir -p "$HOME/dd"; print a >"$HOME/dd/f1"; print b >"$HOME/dd/f2"; rm -rf "$HOME"/dd/*; print rc=$?')
    assert_contains "rm -rf ~/dd/* (children) is allowed" "$tw_o" "rc=0"
    assert_eq "rm -rf ~/dd/* trashed both children" "$(tw_count)" "2"
    tw_reset
    tw_o=$(tw 'mkdir d1; rm d1; print rc=$?')
    assert_eq "rm of a directory without -r is trashed (deliberate)" "$tw_o|$(tw_count)" "rc=0|1"
    tw_reset
    tw_o=$(tw 'print a >f; eval "del f"; print rc=$?')
    assert_eq "del behaves as rm" "$tw_o|$([[ -e $tw_root/w/f ]] && echo kept || echo gone)|$(tw_count)" "rc=0|gone|1"
    for tw_env in "TERM=dumb" "TERM=xterm-256color" "CLAUDECODE=1" "DOTFILES_AGENT=1"; do
        tw_reset
        tw_o=$(TW_ENV="$tw_env" tw 'print a >f; rm f nope; print rc=$?' | command sed "s#$tw_root#R#g")
        assert_eq "rm output is the same under $tw_env" "$tw_o|$(tw_count)" "rm: cannot remove 'nope': No such file or directory
rc=1|1"
    done

    # C1: empty-trash accepts only y, Y, yes, YES
    tw_reset
    tw_o=$(tw 'print a >f; rm f; print yolo | empty-trash')
    assert_eq "empty-trash: 'yolo' does not empty the trash (old code emptied it)" \
        "$([[ $tw_o == *Cancelled* ]] && echo cancelled || echo other)|$(tw_count)" "cancelled|1"
    tw_o=$(tw 'print yup | empty-trash')
    assert_eq "empty-trash: 'yup' does not empty the trash" "$(tw_count)" "1"
    tw_o=$(tw 'print y | empty-trash')
    assert_eq "empty-trash: 'y' empties the trash" "$(tw_count)" "0"
    tw_reset
    tw_o=$(tw 'print a >f; rm f; print YES | empty-trash')
    assert_eq "empty-trash: 'YES' empties the trash" "$(tw_count)" "0"
else
    echo "  ⚠️  [SKIPPED] real trash-cli tools not installed: the rm/rt/empty-trash round trips did not run"
fi

# B1: no trash tool at all, rm falls back to an interactive rm that -f cannot silence
tw_farm="$tw_root/farm"
tw_reset
mkdir -p "$tw_farm" && ln -s /usr/bin/rm "$tw_farm/rm" && ln -s /usr/bin/yes "$tw_farm/yes"
tw_fb() {  # $1 = answers piped to rm, $2 = rm command line; runs in $tw_root/w with a dir dd and a file ff
    mkdir -p "$tw_root/w/dd"; print x >"$tw_root/w/dd/in"; print y >"$tw_root/w/ff"
    env -i PATH="$tw_farm" HOME="$tw_root/home" HAS_TRASH=false HAS_TRASH_PUT=false /usr/bin/timeout 20 /usr/bin/zsh -f -c "
        source '$DOT_DIR/modules/files/trash.zsh'
        cd '$tw_root/w'
        yes $1 | $2" </dev/null >/dev/null 2>&1
}
tw_fb n 'rm -rf dd ff'
assert_eq "fallback rm -rf keeps asking: answering n deletes nothing (old code deleted for real)" \
    "$([[ -e $tw_root/w/dd/in && -e $tw_root/w/ff ]] && echo kept || echo deleted)" "kept"
tw_fb n 'rm -f ff'
assert_eq "fallback rm -f keeps asking (old code deleted ff)" "$([[ -e $tw_root/w/ff ]] && echo kept || echo deleted)" "kept"
tw_fb n 'rm -fR dd'
assert_eq "fallback rm -fR (cluster) keeps asking" "$([[ -e $tw_root/w/dd/in ]] && echo kept || echo deleted)" "kept"
tw_fb n 'rm --force --interactive=never ff'
assert_eq "fallback rm --force --interactive=never keeps asking" "$([[ -e $tw_root/w/ff ]] && echo kept || echo deleted)" "kept"
tw_fb y 'rm -f ff'
assert_eq "fallback rm answering y still removes the file (guards the path)" "$([[ -e $tw_root/w/ff ]] && echo kept || echo deleted)" "deleted"
tw_fb n 'eval "del ff"'
assert_eq "fallback del keeps asking" "$([[ -e $tw_root/w/ff ]] && echo kept || echo deleted)" "kept"

command rm -rf "$tw_root"
unfunction tw tw_count tw_reset tw_fb

# --- Final check: this run printed no "command not found" ----------------------
# Stop the capture first: tee has then read the whole run, and the log is complete.
exec 1>&3 2>&4 3>&- 4>&-
wait "$SUITE_TEE_PID"
command rm -f -- "$SUITE_FIFO"
suite_not_found=$(command grep -c 'command not found' "$SUITE_LOG")
command rm -f -- "$SUITE_LOG"
assert_eq "no missing-command errors in the run output (a helper used before it is defined)" "$suite_not_found" "0"

echo -e "\n📊 Results: $test_passed Passed, $test_failed Failed."
if (( test_failed > 0 )); then
    echo -e "\n🛑 FAILURE: $test_failed tests failed."
    exit 1
else
    echo -e "\n🎉 SUCCESS: All tests passed."
    exit 0
fi
