#!/usr/bin/env bash
# ============================================================================
# GIT WORKFLOWS & FUNCTIONS
# ============================================================================

# --- Git Time Machine (Redo) ---
# Resets the repository to a previous state using a fuzzy-selected reflog entry.
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

# --- Git & GitHub Aliases ---

[ "$HAS_LAZYGIT" = "true" ] && alias lg="lazygit"

alias gs='git status -sb'
alias gd='git diff'
alias gds='git diff --staged'
alias gb='git branch'
alias gba='git branch -a'
alias ga='git add --all'
alias gam='git commit --amend --no-edit'
alias gpf='git push --force-with-lease'
alias gu='git reset --soft HEAD~1'
alias gl='git log --graph --abbrev-commit --decorate --date=relative --format=format:"%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)" -n 15'

if [ "$HAS_GH" = "true" ]; then
    alias pr='gh pr create --web'
    alias prs='gh pr list'
    alias ghv='gh repo view --web'
    alias ghme='gh pr list --author "@me"'
fi
