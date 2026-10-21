# ============================================================================
# FILE LISTING & READING (ls, cat)
# ============================================================================

# --- File Listing (eza or platform fallback) ---
# --color=auto / --icons=auto keep piped output plain (no escape codes or glyphs)
if [[ "$HAS_EZA" == "true" ]]; then
    # Agents get the real ls: tools parse its output and expect its flags
    [[ "$IS_AGENT" != "true" ]] && alias ls='eza --icons=auto --group-directories-first --color=auto'
    alias ll='eza -l --icons=auto --group-directories-first --color=auto --time-style=long-iso --git --git-repos'
    alias lt='eza --tree --icons=auto --group-directories-first -L 2 --color=auto'
    alias lsh='eza -a --icons=auto --group-directories-first --color=auto'
    alias llh='eza -la --icons=auto --group-directories-first --color=auto --time-style=long-iso --git --git-repos'
    alias lth='eza -a --tree --icons=auto --group-directories-first -L 2 --color=auto'
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
