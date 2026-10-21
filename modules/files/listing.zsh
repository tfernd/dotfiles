# ============================================================================
# FILE LISTING & READING (ls, cat)
# ============================================================================

# --- File Listing (eza or platform fallback) ---
if [[ "$HAS_EZA" == "true" ]]; then
    alias ls='eza --icons --group-directories-first --color=always'
    alias ll='eza -l --icons --group-directories-first --color=always --time-style=long-iso --git --git-repos'
    alias lt='eza --tree --icons --group-directories-first -L 2 --color=always'
    alias lsh='eza -a --icons --group-directories-first --color=always'
    alias llh='eza -la --icons --group-directories-first --color=always --time-style=long-iso --git --git-repos'
    alias lth='eza -a --tree --icons --group-directories-first -L 2 --color=always'
elif [[ "$DOTFILES_PLATFORM" == "macos" ]]; then
    export CLICOLOR=1
    export LSCOLORS='Gxfxcxdxbxegedabagacad'
    alias ls='ls -G'
else
    alias ls='ls --color=auto --group-directories-first'
fi

# --- File Reading (bat/batcat) ---
if [[ "$HAS_BAT" == "true" ]]; then
    [[ "$HAS_BATCAT" == "true" ]] && alias bat='batcat'
    alias cat='bat --style=plain --paging=never'
fi
