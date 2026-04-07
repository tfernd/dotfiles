#!/usr/bin/env bash
# ============================================================================
# SAFETY & DELETION ALIASES
# ============================================================================

# --- File Deletion (rm / del) -> Trash Mapping ---
if [ "$HAS_TRASH" = "true" ]; then
    # Prefer trash-put (Linux/Python), fallback to trash (Windows/Node)
    if [ "$HAS_TRASH_PUT" = "true" ]; then
        alias rm='trash-put'
        alias del='trash-put'
        alias rl='trash-list'
        
        # Interactive Trash Restore (FZF)
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
