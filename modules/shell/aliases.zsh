# ============================================================================
# SHELL ALIASES (one-liners)
# ============================================================================

alias c='clear && printf "\e[3J"'
alias x='exit'
alias reload='exec zsh --login'
alias doctor='zsh "$DOTFILES_DIR/doctor.zsh"'
alias path='echo "$PATH" | tr ":" "\n"'
alias grep='grep --color=auto'

# Drop cached sudo credentials immediately
alias sudok='sudo -k && echo "🔒 Sudo credentials revoked."'

# --- SSH shortcuts ---
alias ssh-login='eval "$(ssh-agent -s)" &>/dev/null && ssh-add ~/.ssh/id_ed25519 && echo "✅ SSH agent ready (key loaded)"'
alias ssh-test='ssh -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 | head -1'

# --- GitHub ---
[[ "$HAS_GH" == "true" ]] && alias ghv='gh repo view --web'
