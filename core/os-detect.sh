#!/usr/bin/env bash
# ============================================================================
# CORE VARIABLES & SYSTEM DETECTION
# ============================================================================

# --- OS & Shell Intelligence ---
# Enables cross-platform behavior by detecting the environment at startup.
if [ -n "$ZSH_VERSION" ]; then
    export CURRENT_SHELL="zsh"
elif [ -n "$BASH_VERSION" ]; then
    export CURRENT_SHELL="bash"
else
    export CURRENT_SHELL=$(basename "$SHELL" 2>/dev/null || echo "bash")
fi

export IS_MAC=false
export IS_LINUX=false
export IS_WIN=false
case "$OSTYPE" in
    darwin*)         IS_MAC=true   ;;
    linux*)          IS_LINUX=true ;;
    msys* | cygwin*) IS_WIN=true   ;;
esac
