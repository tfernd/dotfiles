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
    setopt INC_APPEND_HISTORY   # Save every command as it's typed
    setopt EXTENDED_HISTORY     # Save timestamps
    
else
    # Fallback for Bash
    export HISTFILE="$HOME/.bash_history"
    export HISTFILESIZE=$HISTSIZE      
    export HISTCONTROL=ignoreboth:erasedups
    shopt -s histappend
    shopt -s cmdhist           # Save multi-line commands as one line
    
    # Save to disk after every command
    case "$PROMPT_COMMAND" in
        *"history -a"*) ;;
        *) PROMPT_COMMAND="history -a${PROMPT_COMMAND:+; $PROMPT_COMMAND}" ;;
    esac
    history -r "$HISTFILE" 2>/dev/null || true
fi

# --- Secure History Sanitization ---
# Wipes the command history from both memory and disk across Bash and Zsh.
function hclear() {
    echo -n "⚠️  Clear all terminal history? (y/N): "
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        if [ -n "$ZSH_VERSION" ]; then
            truncate -s 0 "$HISTFILE"
            history -p
            hash -r
        else
            history -c
            history -w
            [ -f "$HISTFILE" ] && truncate -s 0 "$HISTFILE"
        fi
        echo "✅ History cleared!"
    else
        echo "Operation cancelled."
    fi
}
