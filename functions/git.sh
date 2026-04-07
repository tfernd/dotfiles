#!/usr/bin/env bash
# ============================================================================
# GIT WORKFLOWS & FUNCTIONS
# ============================================================================

# gr (Git Redo): Reset point with fuzzy selection (Time Machine)
unalias gr 2>/dev/null || true
function gr() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "❌ Not in a git repository!"
        return 1
    fi

    if [ "$HAS_FZF" != "true" ]; then
        echo "❌ FZF is required for Git Redo."
        return 1
    fi

    local target=$(git reflog --date=relative |
        fzf --height 50% --reverse --ansi \
            --header "Select a point to REDO/RESET to (ESC to cancel)" \
            --prompt "Time Machine > " | awk '{print $1}')

    if [ -n "$target" ]; then
        git reset --soft "$target"
        echo "✅ Moved HEAD to $target. Your files are in the staging area."
    else
        echo "❌ Redoing cancelled."
    fi
}
