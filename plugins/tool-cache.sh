#!/usr/bin/env bash
# ============================================================================
# TOOL DETECTION (cached for fast startup)
# ============================================================================

# Check if a specific command is available in the shell path
unalias has_tool 2>/dev/null || true
function has_tool() {
    local tool_name="$1"
    if command -v "$tool_name" >/dev/null 2>&1; then
        echo true
    else
        echo false
    fi
}

# Check if any of a list of commands is available (returns true on first match)
unalias has_any 2>/dev/null || true
function has_any() {
    local tool
    for tool in "$@"; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo true
            return
        fi
    done
    echo false
}

TOOL_CACHE="$HOME/.cache/bashrc_tools"

# Resolve actual file path to track changes (for cache invalidation)
if [ -n "$ZSH_VERSION" ]; then
    BASHRC_SRC="${(%):-%x}"
else
    BASHRC_SRC="${BASH_SOURCE[0]:-$HOME/.bashrc}"
fi

# stat mtime+size: GNU (Linux/Win) uses -c, macOS uses -f
BASHRC_HASH=$(stat -c '%Y-%s' "$BASHRC_SRC" 2>/dev/null || stat -f '%m%z' "$BASHRC_SRC" 2>/dev/null)
# Include OSTYPE so a synced cache is not reused across platforms
TOOL_CACHE_KEY="${BASHRC_HASH}:${OSTYPE:-unknown}"

if [ ! -f "$TOOL_CACHE" ] || ! grep -q "#hash:$TOOL_CACHE_KEY" "$TOOL_CACHE" 2>/dev/null; then
    mkdir -p "$(dirname "$TOOL_CACHE")"
    # SECURITY: Restrict cache file permissions (sourced on every shell startup)
    umask 077
    cat > "$TOOL_CACHE" <<EOF
export HAS_ZOXIDE=$(has_tool zoxide)
export HAS_EZA=$(has_tool eza)
export HAS_TRASH_PUT=$(has_tool trash-put)
export HAS_TRASH=$(has_any trash-put trash)
export HAS_RG=$(has_tool rg)
export HAS_TLDR=$(has_tool tldr)
export HAS_FZF=$(has_tool fzf)
export HAS_LAZYGIT=$(has_tool lazygit)
export HAS_GH=$(has_tool gh)
export HAS_JQ=$(has_tool jq)
export HAS_XH=$(has_tool xh)
export HAS_YAZI=$(has_tool yazi)
export HAS_BTM=$(has_tool btm)
export HAS_DELTA=$(has_tool delta)
export HAS_STARSHIP=$(has_tool starship)
export HAS_BAT=$(has_any bat batcat)
export HAS_BATCAT=$(has_tool batcat)
export HAS_YQ=$(has_tool yq)
export HAS_UV=$(has_tool uv)
export HAS_BUN=$(has_tool bun)
export HAS_FD=$(has_tool fd)
#hash:$TOOL_CACHE_KEY
EOF
    umask 022
fi

source "$TOOL_CACHE"

# Rebuild tool-detection cache and restart shell
alias refresh='rm -f "$TOOL_CACHE" && exec $SHELL --login'
