#!/usr/bin/env bash
# ============================================================================
# PATH MANIPULATION UTILITIES
# ============================================================================

# --- Path Injector ---
# Safely prepends or appends a directory to PATH only if it exists and is unique.
function _path_add() {
    local dir="$1"
    local mode="${2:-prepend}"

    # Only add if directory exists and is not already in PATH
    if [ -d "$dir" ] && [[ ":$PATH:" != *":$dir:"* ]]; then
        if [ "$mode" = "append" ]; then
            export PATH="$PATH:$dir"
        else
            export PATH="$dir:$PATH"
        fi
    fi
}

# --- Path Deduplicator ---
# Prunes redundant entries from PATH to keep command lookups fast and clean.
function _path_clean() {
    if [ -n "$ZSH_VERSION" ]; then
        typeset -gU path
    else
        export PATH=$(echo -n "$PATH" | tr ':' '\n' | awk '!seen[$0]++' | paste -sd ":" -)
    fi
}

# Auto-clean on load to fix any inherited bloat
_path_clean
