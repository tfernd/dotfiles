#!/usr/bin/env bash
# ============================================================================
# CORE VARIABLES & SYSTEM DETECTION
# ============================================================================

# --- OS & Shell Intelligence ---
if [ -n "$ZSH_VERSION" ]; then
    export CURRENT_SHELL="zsh"
elif [ -n "$BASH_VERSION" ]; then
    export CURRENT_SHELL="bash"
else
    export CURRENT_SHELL=$(basename "$SHELL" 2>/dev/null || echo "bash")
fi

export IS_MAC=false
export IS_LINUX=false
case "$OSTYPE" in
    darwin*) IS_MAC=true  ;;
    linux*)  IS_LINUX=true ;;
esac

# --- WSL Detection ---
export IS_WSL=false
if [ "$IS_LINUX" = "true" ] && grep -qi microsoft /proc/version 2>/dev/null; then
    IS_WSL=true
fi
