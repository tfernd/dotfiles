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

    # GitHub Dashboard Extensions
    alias ghn='gh api notifications'
    alias ghm='gh search issues --mentions @me --state open'
    alias ghr='gh pr list --search "review-requested:@me"'

    # gstats — Unified GitHub Statistics Dashboard
    function gstats() {
        if ! gh auth status >/dev/null 2>&1; then
            echo -e "❌ \033[1;31mNot logged into GitHub CLI.\033[0m Run 'gh auth login' to enable stats."
            return 1
        fi

        echo -e "📊 \033[1;36mFetching GitHub Dashboard for @me...\033[0m\n"

        local notifs=$(gh api notifications --jq 'length' 2>/dev/null || echo "0")
        local mentions=$(gh search issues --mentions @me --state open --json number --jq 'length' 2>/dev/null || echo "0")
        local reviews=$(gh pr list --search "review-requested:@me" --json number --jq 'length' 2>/dev/null || echo "0")
        local myprs=$(gh pr list --author "@me" --json number --jq 'length' 2>/dev/null || echo "0")

        echo -e "  📬 \033[1;34mUnread Notifications:\033[0m $notifs"
        echo -e "  ✉️  \033[1;32mMentions (Open):\033[0m     $mentions"
        echo -e "  🔍 \033[1;33mReview Requests:\033[0m    $reviews"
        echo -e "  🏗️  \033[1;35mYour Open PRs:\033[0m      $myprs"
        
        echo -e "\n💡 \033[0;37mUse 'ghn', 'ghm', or 'ghr' to view details.\033[0m"
    }
fi
