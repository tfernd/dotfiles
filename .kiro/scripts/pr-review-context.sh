#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────
# pr-review-context.sh (universal version with auto-detect)
#
# Gathers branch diff context for adversarial PR review. Works in any repo,
# submodule, or worktree. Smart about context size — truncates large file
# diffs per-file, never cuts off the full output.
#
# Repo discovery (in order of priority):
#   1. Explicit first argument:  bash pr-review-context.sh <path>
#   2. Current working directory: walks up to find nearest .git
#
# Usage:
#   bash .kiro/scripts/pr-review-context.sh                       (cwd, auto-detect base)
#   bash .kiro/scripts/pr-review-context.sh .docs                 (explicit repo)
#   bash .kiro/scripts/pr-review-context.sh . main                (explicit base branch)
#   bash .kiro/scripts/pr-review-context.sh sdk/ai/dlp-ai-jedai develop
# ─────────────────────────────────────────────────────────────────────────

set -euo pipefail

export GIT_PAGER=cat

# ── Config ────────────────────────────────────────────────────────────────

MAX_DIFF_LINES_PER_FILE=1000  # Files with diffs larger than this get truncated
HUNK_HEAD_LINES=200           # First N lines of diff for large files
HUNK_TAIL_LINES=150           # Last N lines of diff for large files

# ── Colors ────────────────────────────────────────────────────────────────

BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[36m'
YELLOW='\033[33m'
RED='\033[31m'
GREEN='\033[32m'
MAGENTA='\033[35m'
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

# Determine the target directory (first arg = path, second arg = branch)
if [ $# -ge 1 ] && [ -n "$1" ]; then
  TARGET_DIR="$1"
else
  TARGET_DIR="$(pwd)"
fi

TARGET_BRANCH="${2:-}"

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

# ── Detect target branch ──────────────────────────────────────────────────

if [ -z "$TARGET_BRANCH" ]; then
  if $G rev-parse --verify main >/dev/null 2>&1; then
    TARGET_BRANCH="main"
  elif $G rev-parse --verify master >/dev/null 2>&1; then
    TARGET_BRANCH="master"
  else
    echo -e "${RED}${BOLD}  ✘ Cannot detect base branch. Pass it as second argument.${RESET}"
    echo "  Usage: bash .kiro/scripts/pr-review-context.sh <path> <target-branch>"
    exit 1
  fi
fi

CURRENT_BRANCH=$($G rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")
REMOTE=$($G remote get-url origin 2>/dev/null || echo "no remote")

if [ "$CURRENT_BRANCH" = "$TARGET_BRANCH" ]; then
  echo ""
  divider
  echo -e "${RED}${BOLD}  ✘ Already on ${TARGET_BRANCH} — nothing to review${RESET}"
  divider
  echo ""
  echo "Switch to a feature branch first, or pass a different target:"
  echo "  bash .kiro/scripts/pr-review-context.sh <path> develop"
  exit 0
fi

# Find the merge base (where this branch diverged)
MERGE_BASE=$($G merge-base "$TARGET_BRANCH" HEAD 2>/dev/null || echo "")

if [ -z "$MERGE_BASE" ]; then
  echo -e "${RED}${BOLD}  ✘ No common ancestor with ${TARGET_BRANCH}${RESET}"
  exit 1
fi

# ── 0. Show which repo we're targeting ────────────────────────────────────

header "0/6  REPO DETECTED"
echo -e "  ${BOLD}Root:${RESET}     $REPO_ROOT"
echo -e "  ${BOLD}Branch:${RESET}   $CURRENT_BRANCH"
echo -e "  ${BOLD}Target:${RESET}   $TARGET_BRANCH"
echo -e "  ${BOLD}Remote:${RESET}   $REMOTE"
echo -e "  ${BOLD}Base:${RESET}     ${MERGE_BASE:0:12}"

COMMIT_COUNT=$($G rev-list --count "${MERGE_BASE}..HEAD")
echo -e "  ${BOLD}Ahead by:${RESET} ${COMMIT_COUNT} commits"

# ── 1. Commit log for this branch ────────────────────────────────────────

header "1/6  BRANCH COMMITS"
$G log --oneline --decorate "${MERGE_BASE}..HEAD"

# ── 2. Changed files overview (stat) ─────────────────────────────────────

header "2/6  CHANGED FILES (stat)"
$G diff --stat "${MERGE_BASE}..HEAD"

# ── 3. File-by-file diff (smart truncation) ──────────────────────────────

header "3/6  DIFFS (smart-truncated per file)"

CHANGED_FILES=$($G diff --name-only "${MERGE_BASE}..HEAD")

while IFS= read -r file; do
  # Skip binary files and lock files
  if [[ "$file" == *.lock ]] || [[ "$file" == "uv.lock" ]] || [[ "$file" == "bun.lockb" ]] || [[ "$file" == *.ipynb ]] || [[ "$file" == *.svg ]] || [[ "$file" == *.drawio ]]; then
    echo -e "  ${DIM}[skip diff] ${file} (binary/generated — see stat above for change summary)${RESET}"
    continue
  fi

  # Get the diff for this file
  FILE_DIFF=$($G diff "${MERGE_BASE}..HEAD" -- "$file" 2>/dev/null || true)
  FILE_DIFF_LINES=$(echo "$FILE_DIFF" | wc -l)

  if [ "$FILE_DIFF_LINES" -le "$MAX_DIFF_LINES_PER_FILE" ]; then
    # Small diff — include in full
    echo -e "${GREEN}  ── ${file} (${FILE_DIFF_LINES} lines, full) ──${RESET}"
    echo "$FILE_DIFF"
  else
    # Large diff — truncate with head + tail
    echo -e "${MAGENTA}  ── ${file} (${FILE_DIFF_LINES} lines, TRUNCATED) ──${RESET}"
    echo -e "${YELLOW}  [Showing first ${HUNK_HEAD_LINES} + last ${HUNK_TAIL_LINES} lines. Use readFile for full content.]${RESET}"
    echo ""
    echo "$FILE_DIFF" | head -n "$HUNK_HEAD_LINES"
    echo ""
    echo -e "${DIM}  ... [$(( FILE_DIFF_LINES - HUNK_HEAD_LINES - HUNK_TAIL_LINES )) lines omitted] ...${RESET}"
    echo ""
    echo "$FILE_DIFF" | tail -n "$HUNK_TAIL_LINES"
  fi

  echo ""
done <<< "$CHANGED_FILES"

# ── 4. Files that might need full reading ─────────────────────────────────

header "4/6  LARGE FILES (read these if suspicious)"

echo -e "${DIM}  Files with diffs > ${MAX_DIFF_LINES_PER_FILE} lines (truncated above):${RESET}"
echo ""

HAS_LARGE=false
while IFS= read -r file; do
  if [[ "$file" == *.lock ]] || [[ "$file" == "uv.lock" ]] || [[ "$file" == "bun.lockb" ]] || [[ "$file" == *.ipynb ]] || [[ "$file" == *.svg ]] || [[ "$file" == *.drawio ]]; then
    continue
  fi
  FILE_DIFF_LINES=$($G diff "${MERGE_BASE}..HEAD" -- "$file" 2>/dev/null | wc -l)
  if [ "$FILE_DIFF_LINES" -gt "$MAX_DIFF_LINES_PER_FILE" ]; then
    echo -e "  ${MAGENTA}→${RESET} ${file}  (${FILE_DIFF_LINES} diff lines)"
    HAS_LARGE=true
  fi
done <<< "$CHANGED_FILES"

if [ "$HAS_LARGE" = false ]; then
  echo -e "  ${GREEN}None — all diffs fit within context.${RESET}"
fi

# ── 5. Review instructions ────────────────────────────────────────────────

header "5/6  REVIEW INSTRUCTIONS"
cat << 'INSTRUCTIONS'
You are an ADVERSARIAL CODE REVIEWER. Your only job is to find problems.

Approach:
  1. First, understand WHAT the branch is trying to do (read commits, diff)
  2. Then, ASSUME THE CODE IS WRONG and try to prove it:
     - Logic errors, off-by-one, wrong conditions
     - Missing error handling / uncaught exceptions
     - Resource leaks (files, connections, memory)
     - Race conditions / concurrency issues
     - Security vulnerabilities (injection, auth bypass, secrets)
     - Breaking changes that affect other code
     - Things that pass tests but fail in production
     - Inconsistencies with the stated intent
     - Missing edge cases
  3. For truncated files, use readFile to inspect suspicious sections
  4. Check if the context summary from the main agent reveals intent
     that CONTRADICTS what the code actually does

Output format:
  🔴 CRITICAL  — Will cause bugs, crashes, or security issues
  🟡 WARNING   — Likely to cause problems in some scenarios
  🔵 NOTICE    — Style, maintainability, or minor improvements
  ✅ GOOD      — Things done well (brief, max 2-3 items)

For each finding:
  - File and line/section
  - What's wrong
  - Why it's wrong (the failure scenario)
  - Suggested fix (one-liner if possible)

If you find NOTHING wrong, say so honestly. Don't invent issues.
INSTRUCTIONS

echo ""
divider
echo -e "${GREEN}${BOLD}  ✔ Context gathered from: $REPO_ROOT (branch: $CURRENT_BRANCH → $TARGET_BRANCH)${RESET}"
divider
echo ""
