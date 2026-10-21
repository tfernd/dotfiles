#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────
# smart-commit-context.sh (universal version with auto-detect)
#
# Gathers git context for commit message generation. Works in any repo,
# submodule, or worktree.
#
# Repo discovery (in order of priority):
#   1. Explicit argument:  bash smart-commit-context.sh <path>
#   2. Current working directory: walks up to find nearest .git
#
# Usage:
#   bash .kiro/scripts/smart-commit-context.sh              (uses cwd)
#   bash .kiro/scripts/smart-commit-context.sh .docs        (explicit path)
#   bash .kiro/scripts/smart-commit-context.sh IaC/my-app   (explicit path)
# ─────────────────────────────────────────────────────────────────────────

set -euo pipefail

export GIT_PAGER=cat

# ── Colors ────────────────────────────────────────────────────────────────

BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[36m'
YELLOW='\033[33m'
RED='\033[31m'
GREEN='\033[32m'
RESET='\033[0m'

divider() { echo -e "${DIM}$(printf '─%.0s' {1..72})${RESET}"; }
header()  { echo ""; divider; echo -e "${BOLD}${CYAN}  $1${RESET}"; divider; echo ""; }

# ── Discover repo root ────────────────────────────────────────────────────

discover_repo() {
  local search_dir="$1"

  # Resolve to absolute path
  search_dir="$(cd "$search_dir" 2>/dev/null && pwd)" || {
    echo -e "${RED}${BOLD}  ✘ Directory not found: $1${RESET}"
    exit 1
  }

  # Use git rev-parse to find the repo toplevel from that directory
  local toplevel
  toplevel="$(git -C "$search_dir" rev-parse --show-toplevel 2>/dev/null)" || {
    echo -e "${RED}${BOLD}  ✘ Not a git repository: $search_dir${RESET}"
    echo "Could not find a .git directory walking up from: $search_dir"
    exit 1
  }

  echo "$toplevel"
}

# Determine the target directory
if [ $# -ge 1 ] && [ -n "$1" ]; then
  TARGET_DIR="$1"
else
  TARGET_DIR="$(pwd)"
fi

REPO_ROOT="$(discover_repo "$TARGET_DIR")"

# Remove stale lock file if present
rm -f "$REPO_ROOT/.git/index.lock" 2>/dev/null || true
# For submodules, .git is a file pointing elsewhere; handle that too
if [ -f "$REPO_ROOT/.git" ]; then
  GITDIR="$(git -C "$REPO_ROOT" rev-parse --git-dir 2>/dev/null)"
  rm -f "$GITDIR/index.lock" 2>/dev/null || true
fi

# All git commands target the discovered repo
G="git -C $REPO_ROOT"

# ── Show which repo we're targeting ──────────────────────────────────────

header "0/5  REPO DETECTED"
BRANCH=$($G rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")
REMOTE=$($G remote get-url origin 2>/dev/null || echo "no remote")
echo -e "  ${BOLD}Root:${RESET}   $REPO_ROOT"
echo -e "  ${BOLD}Branch:${RESET} $BRANCH"
echo -e "  ${BOLD}Remote:${RESET} $REMOTE"

# ── Check: anything staged? ──────────────────────────────────────────────

STAGED_COUNT=$($G diff --staged --name-only | wc -l | tr -d ' ')

if [ "$STAGED_COUNT" -eq 0 ]; then
  echo ""
  divider
  echo -e "${RED}${BOLD}  ✘ Nothing is staged${RESET}"
  divider
  echo ""
  echo -e "${YELLOW}Nothing to do here.${RESET}"
  echo "Please tell the user:"
  echo "  \"Nothing is staged in ${BOLD}$REPO_ROOT${RESET} (branch: $BRANCH)."
  echo "   Stage your changes with ${BOLD}git add${RESET} first.\""
  echo ""
  echo -e "${DIM}Tip: git -C $REPO_ROOT add -p  (interactive)  |  git add <file>  (specific)${RESET}"
  exit 0
fi

# ── 1. Git status ────────────────────────────────────────────────────────

header "1/5  GIT STATUS"
$G status

# ── 2. Staged files summary ──────────────────────────────────────────────

header "2/5  STAGED FILES (stat)"
$G diff --staged --stat

# ── 3. Full staged diff ──────────────────────────────────────────────────

header "3/5  STAGED DIFF (excluding lock files, notebooks, and diagrams)"
$G diff --staged -- . ":(exclude)uv.lock" ":(exclude)*.ipynb" ":(exclude)*.lock" ":(exclude)bun.lockb" ":(exclude)*.svg" ":(exclude)*.drawio"

# ── 4. Recent commit history ─────────────────────────────────────────────

header "4/5  RECENT COMMITS (last 10)"
$G log -10 --decorate

# ── 5. Commit message conventions ────────────────────────────────────────

header "5/5  COMMIT FORMAT REFERENCE"
cat << 'CONVENTIONS'
Format:
  <type>(<optional scope>): <description>

  - bullet explaining why or what changed
  - additional context if needed

Rules:
  - Max 72 characters on the subject line
  - Type must be lowercase
  - NEVER use --no-verify or -n on git commit

Allowed types:
  feat      New feature
  fix       Bug fix
  docs      Documentation only
  style     Code style / formatting
  refactor  Code refactoring
  test      Adding or updating tests
  chore     Maintenance tasks
  ci        CI/CD changes
  build     Build system or dependencies
  perf      Performance improvement
  hotfix    Critical production fix
  revert    Revert previous commit

Scope:
  Use module or component as scope when changes are localized.
  Omit scope when changes span multiple areas.

Pre-commit hooks:
  This repo uses pre-commit. Hooks run on every commit and are mandatory.
  If hooks fail, fix the issues and re-stage. If hooks auto-fix files,
  re-stage the fixed files and retry. NEVER bypass with --no-verify.
CONVENTIONS

echo ""
divider
echo -e "${GREEN}${BOLD}  ✔ Context gathered from: $REPO_ROOT (branch: $BRANCH)${RESET}"
divider
echo ""
