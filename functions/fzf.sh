#!/usr/bin/env bash
# ============================================================================
# 🔍 FUZZY FINDER (FZF) WORKFLOWS
# ============================================================================
# f / ff   : Find file/folder in CWD/HOME floor -> inject path into prompt
# h / hh   : Search history -> inject into prompt / copy to clipboard
# ============================================================================

if [ "$HAS_FZF" != "true" ]; then return; fi

# --- 1. CORE ENGINE (INTERNAL) ----------------------------------------------

function _fzf_pick_path() {
    local search_dir="$1"
    ( cd "$search_dir" && \
        if [ "$HAS_FD" = "true" ]; then
            fd -u --type f --type d --exclude .git
        else
            find . -name .git -prune -o -print
        fi
    ) | awk '{
        path=$0; disp=path;
        if (substr(path,1,2)=="./") disp=substr(path,3);
        gsub(/\\/, "/", disp);
        base=disp; sub(/^.*\//, "", base);
        if (base=="") base=disp;
        printf "%s\t%s\n", base, path
    }' | fzf --height 60% --reverse --extended \
             --with-nth 1 --delimiter $'\t' \
             --preview 'echo {2} | fold -w "${FZF_PREVIEW_COLUMNS:-80}"' \
             --preview-window=down:30%:wrap \
       | cut -f2
}

function _fzf_quote_path() {
    local path_str="$1" tick='`'
    path_str="${path_str//\\/\\\\}"
    path_str="${path_str//\"/\\\"}"
    path_str="${path_str//\$/\\\$}"
    path_str="${path_str//${tick}/\\${tick}}"
    printf '"%s"' "$path_str"
}

# --- 2. FILE SEARCH & PICKING (f, ff) ----------------------------------------

if [ -n "$ZSH_VERSION" ]; then
    function _fzf_zle_cwd() {
        local picked=$( _fzf_pick_path "$PWD" < /dev/tty )
        [ -z "$picked" ] && { zle && zle reset-prompt; return; }
        if [ -n "$WIDGET" ]; then
            LBUFFER="${LBUFFER}$(_fzf_quote_path "$picked")"
            zle reset-prompt
        else
            echo "$picked"
        fi
    }

    function _fzf_zle_home() {
        local picked=$( _fzf_pick_path "${FF_SEARCH_DIR:-$HOME}" < /dev/tty )
        [ -z "$picked" ] && { zle && zle reset-prompt; return; }
        if [ -n "$WIDGET" ]; then
            LBUFFER="${LBUFFER}$(_fzf_quote_path "$picked")"
            zle reset-prompt
        else
            echo "$picked"
        fi
    }

    zle -N _fzf_zle_cwd
    zle -N _fzf_zle_home
    bindkey '^[f' _fzf_zle_cwd
    bindkey '^[F' _fzf_zle_home
    alias f='_fzf_zle_cwd'
    alias ff='_fzf_zle_home'
else
    function _fzf_bash_inject() {
        local target_dir="${1:-$PWD}"
        local picked=$( _fzf_pick_path "$target_dir" < /dev/tty )
        [ -z "$picked" ] && return
        
        # If READLINE_LINE is not set or we are not in a bind context, just echo
        if [ -z "$READLINE_LINE" ]; then
            echo "$picked"
        else
            local quoted=$(_fzf_quote_path "$picked")
            READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}${quoted}${READLINE_LINE:$READLINE_POINT}"
            READLINE_POINT=$(( READLINE_POINT + ${#quoted} ))
        fi
    }

    function _fzf_bash_cwd()  { _fzf_bash_inject "$PWD"; }
    function _fzf_bash_home() { _fzf_bash_inject "${FF_SEARCH_DIR:-$HOME}"; }
    
    bind -x '"\ef": _fzf_bash_cwd'  2>/dev/null
    bind -x '"\eF": _fzf_bash_home' 2>/dev/null
    
    alias f='_fzf_bash_cwd'
    alias ff='_fzf_bash_home'
fi

# --- 3. HISTORY POWER (h, hh) -----------------------------------------------

function _fzf_history_source() {
    if [ -n "$ZSH_VERSION" ]; then
        # Zsh: fc -l -n 1 returns history. We trim leading/trailing whitespace.
        fc -l -n 1 | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' | awk '!seen[$0]++' | fzf --height 40% --reverse
    else
        # Bash: history usually has leading numbers.
        history | sed -E 's/^[[:space:]]*[0-9*]+[[:space:]]+//; s/[[:space:]]+$//' | awk '!seen[$0]++' | fzf --height 40% --reverse --tac
    fi
}

if [ -n "$ZSH_VERSION" ]; then
    function _fzf_history_widget() {
        local cmd=$( _fzf_history_source )
        # Aggressive Zsh-native trailing whitespace trim
        cmd="${cmd%%[[:space:]]##}"
        if [ -n "$cmd" ]; then
            LBUFFER="$cmd"
            zle reset-prompt
        fi
    }

    zle -N _fzf_history_widget
    bindkey '^H' _fzf_history_widget

    unalias h 2>/dev/null || true
    function h() {
        local cmd=$( _fzf_history_source )
        # Aggressive Zsh-native trailing whitespace trim
        cmd="${cmd%%[[:space:]]##}"
        [ -n "$cmd" ] && print -z "$cmd"
    }
else
    function _fzf_bash_history() {
        local cmd=$( _fzf_history_source )
        if [ -n "$cmd" ]; then
            # Portable trim
            cmd=$(echo "$cmd" | sed -E 's/[[:space:]]+$//')
            READLINE_LINE="$cmd"
            READLINE_POINT=${#cmd}
        fi
    }
    bind -x '"\C-h": _fzf_bash_history' 2>/dev/null
    unalias h 2>/dev/null || true
    function h() {
        local cmd=$( _fzf_history_source ); 
        [ -n "$cmd" ] && cmd=$(echo "$cmd" | sed -E 's/[[:space:]]+$//') && history -s "$cmd" && echo "$cmd"
    }
fi

unalias hh 2>/dev/null || true
function hh() {
    local cmd=$( _fzf_history_source )
    if [ -n "$cmd" ]; then
        # Trim before copying
        [ -n "$ZSH_VERSION" ] && cmd="${cmd%%[[:space:]]##}"
        [ -z "$ZSH_VERSION" ] && cmd=$(echo "$cmd" | sed -E 's/[[:space:]]+$//')
        echo -n "$cmd" | copy
        echo "✅ Copied to clipboard: $cmd"
    fi
}
