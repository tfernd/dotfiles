#!/usr/bin/env bash
# ============================================================================
# NAVIGATION & FILE READING ALIASES
# ============================================================================

# --- File Listing (ls/eza) ---
if [ "$HAS_EZA" = "true" ]; then
    alias ls='eza --icons --group-directories-first --color=always'
    alias ll='eza -l --icons --group-directories-first --color=always --time-style=long-iso --git'
    alias lt='eza --tree --icons --group-directories-first -L 2 --color=always'

    alias lsh='eza -a --icons --group-directories-first --color=always'
    alias llh='eza -la --icons --group-directories-first --color=always --time-style=long-iso --git'
    alias lth='eza -a --tree --icons --group-directories-first -L 2 --color=always'
fi

# --- File Reading (cat/bat) ---
if [ "$HAS_BAT" = "true" ]; then
    [ "$HAS_BATCAT" = "true" ] && alias bat='batcat'
    alias cat='bat --style=plain --paging=never'
fi

[ "$HAS_FD" = "true" ]   && alias fd='fd --color=auto'
[ "$HAS_YAZI" = "true" ] && alias y='yazi'
