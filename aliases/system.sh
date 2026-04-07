#!/usr/bin/env bash
# ============================================================================
# SYSTEM UTILITY ALIASES
# ============================================================================

# --- Clipboard Handling ---
if [ "$IS_MAC" = "true" ]; then
    alias copy='pbcopy'
elif [ "$IS_WIN" = "true" ]; then
    alias copy='clip.exe'
elif [ "$IS_LINUX" = "true" ]; then
    if command -v xclip >/dev/null 2>&1; then
        alias copy='xclip -selection clipboard'
    elif command -v wl-copy >/dev/null 2>&1; then
        alias copy='wl-copy'
    elif command -v xsel >/dev/null 2>&1; then
        alias copy='xsel --clipboard --input'
    fi
fi

alias cpwd='pwd | copy'
alias c='clear'
alias path='echo $PATH | tr ":" "\n"'

# 'Please' as a sudo shortcut for the last command
if [ "$IS_WIN" != "true" ]; then
    alias please='sudo $(fc -ln -1)'
fi
