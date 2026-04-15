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

# --- System & Environment ---
alias df='df -h'
alias x='exit'
alias reload='exec $SHELL -l'
alias weather='curl wttr.in'

# free — Memory usage (Linux only, falls back to memhog on others)
if [ "$IS_LINUX" = "true" ]; then
    alias free='free -m'
else
    alias free='memhog'
fi

# daemonize — Run a command in the background and log output.
unalias daemonize 2>/dev/null || true
function daemonize() {
    if [ -z "$1" ]; then
        echo -e "📝 \033[1;33mUsage:\033[0m daemonize <command> [args...]"
        return 1
    fi
    local log="daemon_$(date +%Y%m%d_%H%M%S).log"
    nohup "$@" > "$log" 2>&1 &
    local pid=$!
    echo -e "🚀 \033[1;32mStarted:\033[0m '$1' in background (PID: $pid)"
    echo -e "📝 \033[1;34mLogging to:\033[0m $log"
}

# --- Fun & Aesthetics ---
alias matrix='cmatrix -b'
alias starwars='telnet towel.blinkenlights.nl'


# 'Please' as a sudo shortcut for the last command
if [ "$IS_WIN" != "true" ]; then
    alias please='sudo $(fc -ln -1)'
fi

# --- Safety & Deletion Aliases ---

# --- Smart File Deletion (rm / del) -> Safe Trash Mapping ---
if [ "$HAS_TRASH" = "true" ]; then
    unalias rm del 2>/dev/null || true
    
    function rm() {
        local args=()
        local force=false
        
        # Parse flags
        for arg in "$@"; do
            case "$arg" in
                -rf|-f|-fr) force=true ;;
                -*) ;; # Ignore other flags for trash-put
                *) args+=("$arg") ;;
            esac
        done

        # Filter existing items
        local existing=()
        for item in "${args[@]}"; do
            [ -e "$item" ] && existing+=("$item")
        done

        if [ ${#existing[@]} -gt 0 ]; then
            if [ "$HAS_TRASH_PUT" = "true" ]; then
                command trash-put "${existing[@]}"
            else
                command trash "${existing[@]}"
            fi
        elif [ "$force" = "false" ] && [ ${#args[@]} -gt 0 ]; then
            # Show error only if not forced and arguments were provided
            [ "$HAS_TRASH_PUT" = "true" ] && command trash-put "${args[@]}" || command trash "${args[@]}"
        fi
    }
    alias del='rm'
    
    if [ "$HAS_TRASH_PUT" = "true" ]; then
        alias rl='trash-list'
        # ... (rest of the trash-restore functions)
        
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
