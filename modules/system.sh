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
    fi
}

# --- Interactive Process Viewer ---
# Launches the best available monitoring tool (btm, top) for real-time analysis.
unalias top 2>/dev/null || true
function top() {
    if [ "$HAS_BTM" = "true" ]; then
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
    fi
}

# --- System & Environment (interactive-only) ---
alias reload='exec $SHELL -l'
alias weather='curl wttr.in'

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
alias please='sudo $(fc -ln -1)'



# ============================================================================
# ALWAYS loaded (including AI terminals) — Safe deletion only
# ============================================================================

# --- Clipboard Handling ---
if [ "$IS_MAC" = "true" ]; then
    alias copy='pbcopy'
elif [ "$IS_LINUX" = "true" ]; then
    if [ "$IS_WSL" = "true" ] && command -v clip.exe >/dev/null 2>&1; then
        alias copy='clip.exe'
    elif command -v xclip >/dev/null 2>&1; then
        alias copy='xclip -selection clipboard'
    elif command -v wl-copy >/dev/null 2>&1; then
        alias copy='wl-copy'
    elif command -v xsel >/dev/null 2>&1; then
        alias copy='xsel --clipboard --input'
    fi
fi

alias cpwd='pwd | copy'
alias c='clear'

# path — Pretty-print $PATH one entry per line
alias path='echo "$PATH" | tr ":" "\n"'

# --- System & Environment ---
alias df='df -h'
alias x='exit'

# free — Memory usage (Linux only, falls back to memhog on others)
if [ "$IS_LINUX" = "true" ]; then
    alias free='free -m'
else
    alias free='memhog'
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
        # trash-restore is interactive: it prints numbered entries and waits for
        # a number on stdin. We capture that numbered list, let fzf pick one,
        # extract the number, and feed it back into trash-restore.
        function _fzf_rt() {
            local search_dir="${1:-}"

            # Get the numbered list from trash-restore by sending an invalid
            # input ("") so it prints the list and exits without restoring.
            local list
            if [ -n "$search_dir" ]; then
                list=$(echo "" | trash-restore "$search_dir" 2>/dev/null)
            else
                list=$(echo "" | trash-restore 2>/dev/null)
            fi

            # Strip the trailing "What file to restore [0..N]:" prompt line
            local entries
            entries=$(echo "$list" | sed '/^[[:space:]]*$/d' | head -n -1)

            if [ -z "$entries" ]; then
                echo "🗑️  Trash is empty (nothing to restore)." >&2
                return 0
            fi

            local selected
            selected=$(echo "$entries" | fzf --height 50% --reverse --header "Select file to restore" --preview "echo {}")
            if [ -n "$selected" ]; then
                # Extract the leading number from the selected line (e.g. "   3 2026-04-19 ...")
                local idx
                idx=$(echo "$selected" | sed 's/^[[:space:]]*//' | cut -d' ' -f1)
                if [ -n "$search_dir" ]; then
                    echo "$idx" | trash-restore "$search_dir"
                else
                    echo "$idx" | trash-restore
                fi
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
