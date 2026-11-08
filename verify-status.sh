#!/usr/bin/env bash
# ============================================================================
# 🧪 STARSHIP GIT STATUS VERIFIER (AI-assisted, visual)
# ============================================================================
# Recreates ./.verify-status-worktree, drives every git_branch / git_commit / git_state /
# git_status case Starship can show, and prints the rendered modules.
#
# This is NOT test/suite.zsh (that suite mocks tools and checks aliases).
# This one is meant to be watched: you (or an AI) read the printed pills.
#
# Usage:
#   bash ./verify-status.sh
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$SCRIPT_DIR/.verify-status-worktree"
STARSHIP_TOML="$SCRIPT_DIR/config/starship.toml"
PASS=0
FAIL=0
ORIGIN_DIR="$(mktemp -d /tmp/verify-status-origin.XXXXXX)"
PATCH_FILE="$(mktemp /tmp/verify-status-patch.XXXXXX)"
trap 'rm -rf -- "${ORIGIN_DIR:?}" "${PATCH_FILE:?}"' EXIT

if ! command -v starship >/dev/null 2>&1; then
    echo "❌ starship not on PATH"
    exit 1
fi
if [[ ! -f "$STARSHIP_TOML" ]]; then
    echo "❌ missing $STARSHIP_TOML"
    exit 1
fi

export STARSHIP_CONFIG="$STARSHIP_TOML"
export TERM="${TERM:-xterm-256color}"
[[ "$TERM" == "dumb" ]] && export TERM=xterm-256color

git_silent() { git -c advice.detachedHead=false "$@"; }

setup_repo() {
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"

    git_silent init -b main >/dev/null
    git config user.email "verify@dotfiles.test"
    git config user.name "Verify Status"
    git config commit.gpgsign false

    echo "base" > base.txt
    git add base.txt
    git_silent commit -m "base" >/dev/null
    # Tag the *root* commit only, so later main HEAD is untagged (DETACHED vs TAG differ).
    git_silent tag -a v1.2.0 -m "release" >/dev/null

    git_silent checkout -b feature >/dev/null
    echo "feature-only" > feature.txt
    echo "feature version" > conflict.txt
    git add feature.txt conflict.txt
    git_silent commit -m "feature commit" >/dev/null

    git_silent checkout main >/dev/null
    echo "main-only" > branch.txt
    echo "main version" > conflict.txt
    git add branch.txt conflict.txt
    git_silent commit -m "main commit" >/dev/null

    # Keep origin outside the generated worktree so Starship does not count a bare repo as ?N
    git_silent clone --bare "$TEST_DIR" "$ORIGIN_DIR" >/dev/null 2>&1
    git_silent remote add origin "$ORIGIN_DIR"
    git_silent push -u origin main >/dev/null 2>&1
    git_silent push origin feature >/dev/null 2>&1
}

# Strip ANSI so grep/expects stay readable; still print the colored line.
_plain() { printf '%s' "$1" | sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g'; }

snap() {
    local title="$1"
    local expect="$2"
    local unexpect="${3:-}"
    local branch commit tagpill state status combo plain

    # Must run inside the generated worktree so Starship sees this repo, not the parent dotfiles git.
    branch="$(starship module git_branch 2>/dev/null || true)"
    commit="$(starship module git_commit 2>/dev/null || true)"
    tagpill="$(starship module custom.git_tag 2>/dev/null || true)"
    state="$(starship module git_state 2>/dev/null || true)"
    status="$(starship module git_status 2>/dev/null || true)"

    echo ""
    echo -e "\033[1;36m────────────────────────────────────────────────────────────\033[0m"
    echo -e "\033[1;35m  $title\033[0m"
    echo -e "  git: $(git rev-parse --abbrev-ref HEAD 2>/dev/null) | $(git status -sb | head -1)"
    echo -e "  porcelain: $(git status --porcelain=v1 | tr '\n' ' | ')"
    echo -e "  git_branch: ${branch:-∅}"
    echo -e "  git_tag:    ${tagpill:-∅}"
    echo -e "  git_commit: ${commit:-∅}"
    echo -e "  git_state:  ${state:-∅}"
    echo -e "  git_status: ${status:-∅}"

    combo="${branch}${tagpill}${commit}${state}${status}"
    plain="$(_plain "$combo")"

    if [[ -z "$expect" && -z "$unexpect" ]]; then
        echo -e "  \033[33mRESULT: (no auto-check)\033[0m"
        return 0
    fi
    local ok=true
    if [[ -n "$expect" ]] && ! printf '%s' "$plain" | grep -q -- "$expect"; then
        echo -e "  \033[31mRESULT: FAIL\033[0m  expected '$expect'  got: $plain"
        ok=false
    fi
    if [[ -n "$unexpect" ]] && printf '%s' "$plain" | grep -q -- "$unexpect"; then
        echo -e "  \033[31mRESULT: FAIL\033[0m  unexpectedly found '$unexpect'  got: $plain"
        ok=false
    fi
    if [[ "$ok" == true ]]; then
        echo -e "  \033[32mRESULT: PASS\033[0m  expected '$expect'${unexpect:+, not '$unexpect'}"
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
    fi
}

abort_all() {
    git_silent merge --abort >/dev/null 2>&1 || true
    git_silent rebase --abort >/dev/null 2>&1 || true
    git_silent cherry-pick --abort >/dev/null 2>&1 || true
    git_silent revert --abort >/dev/null 2>&1 || true
    git_silent am --abort >/dev/null 2>&1 || true
    git_silent bisect reset >/dev/null 2>&1 || true
    git_silent checkout main >/dev/null 2>&1 || true
    git_silent reset --hard HEAD >/dev/null 2>&1 || true
    git_silent clean -fd >/dev/null 2>&1 || true
    git_silent stash drop >/dev/null 2>&1 || true
}

echo -e "\n\033[1;36m=================================================================\033[0m"
echo -e "\033[1;35m  🧪 STARSHIP GIT VERIFIER  (not test/suite.zsh)\033[0m"
echo -e "  repo: $TEST_DIR"
echo -e "  config: $STARSHIP_TOML"
echo -e "\033[1;36m=================================================================\033[0m"

setup_repo

# -----------------------------------------------------------------------------
# git_status
# -----------------------------------------------------------------------------
snap "CLEAN" " main"

echo "untracked" > untracked.txt
snap "UNTRACKED" "?"
rm -f untracked.txt

echo "dirty" >> base.txt
snap "MODIFIED" "○"
git_silent checkout -- base.txt >/dev/null

echo "staged" >> base.txt
git add base.txt
snap "STAGED" "●"
git_silent reset --hard HEAD >/dev/null

rm -f branch.txt
snap "DELETED (unstaged)" "✕"
git_silent checkout -- branch.txt >/dev/null

git_silent mv branch.txt renamed.txt
snap "RENAMED (staged)" "→"
git_silent reset --hard HEAD >/dev/null

echo "stash-me" >> base.txt
git_silent stash push -u -m "verify-stash" >/dev/null
snap "STASHED" "▪"
git_silent stash drop >/dev/null
git_silent checkout -- base.txt >/dev/null 2>&1 || true

echo "ahead" >> base.txt
git add base.txt
git_silent commit -m "ahead commit" >/dev/null
snap "AHEAD of origin" "▲"
git_silent reset --hard origin/main >/dev/null

git_silent reset --hard origin/main >/dev/null
git_silent reset --hard HEAD~1 >/dev/null
snap "BEHIND origin" "▼"
git_silent reset --hard origin/main >/dev/null

git_silent reset --hard HEAD~1 >/dev/null
echo "diverged-local" >> base.txt
git add base.txt
git_silent commit -m "diverged local" >/dev/null
snap "DIVERGED" "⇄"
git_silent reset --hard origin/main >/dev/null

echo "regular" > typechange.txt
git add typechange.txt
git_silent commit -m "add regular file" >/dev/null
rm -f typechange.txt
ln -sf base.txt typechange.txt
git add typechange.txt
# Starship 1.26 maps git 'T' to staged/modified (●/○), not typechanged (◈).
# Still print it so we can see what the prompt actually does.
snap "TYPECHANGED (git T; Starship may show ● not ◈)" ""
git_silent reset --hard origin/main >/dev/null
git_silent push --force origin main >/dev/null 2>&1 || true

# -----------------------------------------------------------------------------
# git_state
# -----------------------------------------------------------------------------
git_silent checkout main >/dev/null
git_silent merge feature >/dev/null 2>&1 || true
snap "MERGING (conflict)" "MERGING"
git_silent merge --abort >/dev/null

git_silent checkout feature >/dev/null
git_silent rebase main >/dev/null 2>&1 || true
snap "REBASING (conflict)" "REBASING"
git_silent rebase --abort >/dev/null

git_silent checkout main >/dev/null
git_silent cherry-pick feature >/dev/null 2>&1 || true
snap "CHERRY-PICKING (conflict)" "PICKING"
git_silent cherry-pick --abort >/dev/null

git_silent checkout main >/dev/null
git_silent revert HEAD --no-commit >/dev/null 2>&1 || true
snap "REVERTING" "REVERTING"
git_silent revert --abort >/dev/null 2>&1 || true
git_silent reset --hard HEAD >/dev/null

git_silent checkout main >/dev/null
git_silent bisect start >/dev/null
git_silent bisect bad HEAD >/dev/null
git_silent bisect good "$(git rev-list --max-parents=0 HEAD)" >/dev/null 2>&1 || true
snap "BISECTING" "BISECTING"
git_silent bisect reset >/dev/null

# mailbox apply (git am)
git_silent checkout feature >/dev/null
git_silent format-patch -1 --stdout > "$PATCH_FILE"
git_silent checkout main >/dev/null
git_silent am "$PATCH_FILE" >/dev/null 2>&1 || true
snap "APPLYING MAILBOX (git am)" "APPLYING"
git_silent am --abort >/dev/null 2>&1 || true

# -----------------------------------------------------------------------------
# git_commit (detached / tag)
# -----------------------------------------------------------------------------
git_silent checkout --detach main >/dev/null
snap "DETACHED HEAD (untagged)" "DETACHED" "v1.2.0"
git_silent checkout main >/dev/null

git_silent checkout --detach v1.2.0 >/dev/null
snap "DETACHED + TAG v1.2.0" "v1.2.0"
git_silent checkout main >/dev/null

git_silent checkout -B tagged v1.2.0 >/dev/null
snap "ATTACHED + TAG (no DETACHED)" "v1.2.0" "DETACHED"
git_silent checkout main >/dev/null
git_silent branch -D tagged >/dev/null 2>&1 || true

abort_all

echo ""
echo -e "\033[1;36m=================================================================\033[0m"
echo -e "  PASS=$PASS  FAIL=$FAIL"
if (( FAIL > 0 )); then
    echo -e "  \033[31mSome Starship git pills did not match.\033[0m"
    echo -e "\033[1;36m=================================================================\033[0m\n"
    exit 1
fi
echo -e "  \033[32mAll expected pills were present.\033[0m"
echo -e "\033[1;36m=================================================================\033[0m\n"
exit 0
