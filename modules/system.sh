#!/usr/bin/env bash
# ============================================================================
# SYSTEM MONITORING & UTILITIES
# ============================================================================

# --- Resource Monitoring (Memory) ---
# Identifies the top 15 processes by memory consumption for rapid troubleshooting.
unalias memhog 2>/dev/null || true
function memhog() {
    if [ "$IS_MAC" = "true" ]; then
        ps -m -o user,pid,%cpu,%mem,vsz,rss,stat,comm | head -n 15
    elif [ "$IS_LINUX" = "true" ]; then
        ps axo user,pid,%cpu,%mem,vsz,rss,stat,comm --sort=-%mem | head -n 15
    else
        # Windows/Git Bash fallback
        ps | head -n 15
    fi
}

# --- Interactive Process Viewer ---
# Launches the best available monitoring tool (btm, top) for real-time analysis.
unalias top 2>/dev/null || true
function top() {
    if command -v btm >/dev/null 2>&1; then
        command btm "$@"
    elif command -v top >/dev/null 2>&1; then
        command top "$@"
    else
        echo "❌ btm (bottom) and top not found. Install bottom or use memhog." >&2
        return 127
    fi
}

# --- Resilient Delay Helper ---
# Implements a reliable sleep across platforms using native or scripted fallbacks.
unalias sleep 2>/dev/null || true
function sleep() {
    local seconds="$1"
    if command -v sleep >/dev/null 2>&1; then
        command sleep "$seconds"
    elif command -v uv >/dev/null 2>&1; then
        uv run --no-project python -c "import time; time.sleep(float('$seconds'))"
    elif [ "$IS_WIN" = "true" ]; then
        ping -n $((${seconds%.*} + 1)) 127.0.0.1 > /dev/null
    fi
}


# --- System Utility Aliases ---

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

# --- Safety & Deletion Aliases ---

# --- File Deletion (rm / del) -> Trash Mapping ---
if [ "$HAS_TRASH" = "true" ]; then
    # Prefer trash-put (Linux/Python), fallback to trash (Windows/Node)
    if [ "$HAS_TRASH_PUT" = "true" ]; then
        alias rm='trash-put'
        alias del='trash-put'
        alias rl='trash-list'
        
        # --- Interactive Trash Recovery ---
        # Provides a fuzzy-search interface to selectively restore deleted files.
        function _fzf_rt() {
            local search_dir="$1"
            local list_cmd="trash-list"
            [ -n "$search_dir" ] && list_cmd="trash-list | grep \"$search_dir\""
            
            local selected=$(eval "$list_cmd" | fzf --height 50% --reverse --header "Select file to restore" --preview "echo {}")
            if [ -n "$selected" ]; then
                local path=$(echo "$selected" | cut -d' ' -f3-)
                trash-restore "$path"
            fi
        }
        alias rt='_fzf_rt "$PWD"'   # Current directory only
        alias rtt='_fzf_rt'         # Everything
        alias empty-trash='trash-empty'
    else
        alias rm='trash'
        alias del='trash'
    fi
else
    # Fallback to interactive standard deletion
    alias rm='rm -i'
    alias del='rm -i'
fi
