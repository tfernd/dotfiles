#!/usr/bin/env bash
# ============================================================================
# HISTORY CONFIGURATION
# ============================================================================
export HISTSIZE=100000

if [ -n "$ZSH_VERSION" ]; then
    export HISTFILE="$HOME/.zsh_history"
    export SAVEHIST=$HISTSIZE         
    
    setopt APPEND_HISTORY
    setopt HIST_IGNORE_DUPS
    setopt HIST_IGNORE_SPACE
    setopt HIST_VERIFY
    setopt INC_APPEND_HISTORY # Save every command as it's typed
    
else
    # Fallback for Bash
    export HISTFILE="$HOME/.bash_history"
    export HISTFILESIZE=$HISTSIZE      
    export HISTCONTROL=ignoredups:ignorespace
    shopt -s histappend
    
    # Save to disk after every command, but don't force-reload in other tabs
    case "$PROMPT_COMMAND" in
        *"history -a"*) ;;
        *) PROMPT_COMMAND="history -a${PROMPT_COMMAND:+; $PROMPT_COMMAND}" ;;
    esac
    
    # Load history file on startup
    history -r "$HISTFILE" 2>/dev/null || true
fi
