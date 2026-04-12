#!/usr/bin/env bash
# ============================================================================
# 🔍 FUZZY FINDER (FZF) WORKFLOWS
# ============================================================================
# f / ff   : Search files/folders in CWD/HOME -> insert at cursor
# h / hh   : Search history -> insert at cursor / copy to clipboard
# ============================================================================

if [ "$HAS_FZF" != "true" ]; then return 0; fi

# ============================================================================
# 🧠 SECTION 1: CORE LOGIC (The Brain)
# ============================================================================

# __fzf_search_files: Lists files/folders and returns the absolute path
function __fzf_search_files() {
    local search_dir="${1:-$PWD}"
    ( cd "$search_dir" && \
        if [ "$HAS_FD" = "true" ]; then
            fd -u --type f --type d --exclude .git
        else
            find . -name .git -prune -o -print
        fi
    ) | awk '{
        path=$0; display=path;
        if (substr(path,1,2)=="./") display=substr(path,3); # Beautiful display
        gsub(/\\/, "/", display);                          # Universal slashes
        base=display; sub(/^.*\//, "", base);              # Extract name only
        if (base=="") base=display;
        printf "%s\t%s\n", base, path                      # Syntax: [Display Name \t Real Path]
    }' | fzf --height 60% --reverse --extended --cycle \
             --border=rounded --info=inline \
             --with-nth 1 --delimiter $'\t' \
             --preview 'echo {2} | fold -w "${FZF_PREVIEW_COLUMNS:-80}"' \
             --preview-window=down:30%:wrap \
       | cut -f2
}

# __fzf_search_history: Returns a single command from your history
function __fzf_search_history() {
    if [ -n "$ZSH_VERSION" ]; then
        fc -l -n 1 | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' | awk '!seen[$0]++' | fzf --height 40% --reverse --cycle --border=rounded
    else
        history | sed -E 's/^[[:space:]]*[0-9*]+[[:space:]]+//; s/[[:space:]]+$//' | awk '!seen[$0]++' | fzf --height 40% --reverse --cycle --border=rounded --tac
    fi
}

# ============================================================================
# 🛠️ SECTION 2: UTILITIES (The Mechanic)
# ============================================================================

# __fzf_escape_path: Wraps path in quotes and escapes shell-breaking characters
function __fzf_escape_path() {
    local p="$1" tick='`'
    p="${p//\\/\\\\}"  # Escape backslashes
    p="${p//\"/\\\"}"  # Escape quotes
    p="${p//\$/\\\$}"  # Escape dollars
    p="${p//${tick}/\\${tick}}" # Escape backticks
    printf '"%s"' "$p"
}

# ============================================================================
# 🐚 SECTION 3: SHELL INTERFACE (The Courier)
# ============================================================================

if [ -n "$ZSH_VERSION" ]; then
    # --- ZSH (ZLE) INTERFACE ---
    
    # Internal: Safely get a path from FZF (handles TTY for widgets)
    function __fzf_safe_pick() {
        if [ -t 0 ]; then
            __fzf_search_files "$1"
        else
            __fzf_search_files "$1" < /dev/tty 2>/dev/null || __fzf_search_files "$1"
        fi
    }

    # f — Search current directory and insert at cursor
    function f() {
        local picked=$( __fzf_safe_pick "$PWD" )
        [ -n "$picked" ] || { zle && zle reset-prompt; return; }
        LBUFFER+="$(__fzf_escape_path "$picked")"
        zle reset-prompt
    }

    # ff — Search home/configured directory and insert at cursor
    function ff() {
        local picked=$( __fzf_safe_pick "${FF_SEARCH_DIR:-$HOME}" )
        [ -n "$picked" ] || { zle && zle reset-prompt; return; }
        LBUFFER+="$(__fzf_escape_path "$picked")"
        zle reset-prompt
    }

    # Internal history widget
    function __fzf_zsh_history_widget() {
        local cmd=$( __fzf_search_history )
        [ -n "$cmd" ] && LBUFFER="${cmd%%[[:space:]]##}"
        zle reset-prompt
    }

    # Register and Bind
    zle -N f
    zle -N ff
    zle -N __fzf_zsh_history_widget
    bindkey '^[f' f                      # Alt+f
    bindkey '^[F' ff                     # Alt+Shift+f
    bindkey '^H'  __fzf_zsh_history_widget # Ctrl+h
else
    # --- BASH (READLINE) INTERFACE ---

    # Internal: Safely get a path from FZF (handles TTY for bindings)
    function __fzf_safe_pick() {
        if [ -t 0 ]; then
            __fzf_search_files "$1"
        else
            __fzf_search_files "$1" < /dev/tty 2>/dev/null || __fzf_search_files "$1"
        fi
    }

    # f — Search current directory and insert at cursor
    function f() {
        local picked=$( __fzf_safe_pick "$PWD" )
        [ -n "$picked" ] || return
        local esc=$(__fzf_escape_path "$picked")
        READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}${esc}${READLINE_LINE:$READLINE_POINT}"
        READLINE_POINT=$(( READLINE_POINT + ${#esc} ))
    }

    # ff — Search home/configured directory and insert at cursor
    function ff() {
        local picked=$( __fzf_safe_pick "${FF_SEARCH_DIR:-$HOME}" )
        [ -n "$picked" ] || return
        local esc=$(__fzf_escape_path "$picked")
        READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}${esc}${READLINE_LINE:$READLINE_POINT}"
        READLINE_POINT=$(( READLINE_POINT + ${#esc} ))
    }

    # Internal history widget
    function __fzf_bash_history_widget() {
        local cmd=$( __fzf_search_history )
        if [ -n "$cmd" ]; then
            cmd=$(echo "$cmd" | sed -E 's/[[:space:]]+$//')
            READLINE_LINE="$cmd"; READLINE_POINT=${#cmd}
        fi
    }
    
    # Register Bindings
    bind -x '"\ef": f'         2>/dev/null
    bind -x '"\eF": ff'        2>/dev/null
    bind -x '"\C-h": __fzf_bash_history_widget' 2>/dev/null
fi

# ============================================================================
# 🕒 SECTION 4: USER ALIASES (The Dashboard)
# ============================================================================

# h — Search history and load it into the current prompt
unalias h 2>/dev/null || true
function h() {
    local cmd=$( __fzf_search_history )
    [ -n "$cmd" ] || return
    
    [ -n "$ZSH_VERSION" ] && cmd="${cmd%%[[:space:]]##}"
    [ -z "$ZSH_VERSION" ] && cmd=$(echo "$cmd" | sed -E 's/[[:space:]]+$//')

    if [ -n "$ZSH_VERSION" ]; then print -z "$cmd"; else history -s "$cmd"; echo "$cmd"; fi
}

# hh — Search history and COPY it to system clipboard
unalias hh 2>/dev/null || true
function hh() {
    local cmd=$( __fzf_search_history )
    [ -n "$cmd" ] || return
    [ -n "$ZSH_VERSION" ] && cmd="${cmd%%[[:space:]]##}"
    [ -z "$ZSH_VERSION" ] && cmd=$(echo "$cmd" | sed -E 's/[[:space:]]+$//')
    echo -n "$cmd" | copy 2>/dev/null || true
    echo "✅ Copied to clipboard: $cmd"
}
