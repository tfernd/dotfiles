#!/usr/bin/env bash
# ============================================================================
# GIT & GITHUB ALIASES
# ============================================================================

[ "$HAS_LAZYGIT" = "true" ] && alias lg="lazygit"

alias gs='git status -sb'
alias gam='git commit --amend --no-edit'
alias gu='git reset --soft HEAD~1'

# Beautiful git log
alias gl='git log --graph --abbrev-commit --decorate --date=relative --format=format:"%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)" -n 15'

if [ "$HAS_GH" = "true" ]; then
    alias pr='gh pr create --web'
    alias prs='gh pr list'
fi
