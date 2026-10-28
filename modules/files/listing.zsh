# ============================================================================
# FILE LISTING & READING (ls, cat)
# ============================================================================

# --- File Listing (eza or platform fallback) ---
# ls is never aliased: it is the real ls in every shell (human, agent, script).
# l is the colourful listing that ls used to be.
# Oh My Zsh (loaded earlier by plugins/shell.zsh) defines alias ls='ls --color=tty': drop it
unalias ls 2>/dev/null || true
# --color=auto / --icons=auto keep piped output plain (no escape codes or glyphs)
if [[ "$DOTFILES_PLATFORM" == "macos" ]]; then
    export CLICOLOR=1
    export LSCOLORS='Gxfxcxdxbxegedabagacad'
fi

if [[ "$HAS_EZA" == "true" ]]; then
    alias l='eza --icons=auto --group-directories-first --color=auto'
    alias ll='eza -l --icons=auto --group-directories-first --color=auto --time-style=long-iso --git --git-repos'
    alias lt='eza --tree --icons=auto --group-directories-first -L 2 --color=auto'
    alias lsh='eza -a --icons=auto --group-directories-first --color=auto'
    alias llh='eza -la --icons=auto --group-directories-first --color=auto --time-style=long-iso --git --git-repos'
    alias lth='eza -a --tree --icons=auto --group-directories-first -L 2 --color=auto'
else
    # Plain-ls fallbacks for the views (no tree view without eza)
    if [[ "$DOTFILES_PLATFORM" == "macos" ]]; then
        alias l='ls -G'
        alias ll='ls -l'
        alias lsh='ls -a'
        alias llh='ls -la'
    else
        alias l='ls --color=auto --group-directories-first'
        alias ll='ls -l --color=auto --group-directories-first'
        alias lsh='ls -a --color=auto --group-directories-first'
        alias llh='ls -la --color=auto --group-directories-first'
    fi
fi

# --- File Reading (bat/batcat) ---
if [[ "$HAS_BAT" == "true" ]]; then
    [[ "$HAS_BATCAT" == "true" ]] && alias bat='batcat'
    alias cat='bat --style=plain --paging=never'
fi
