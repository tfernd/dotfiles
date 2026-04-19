#!/usr/bin/env bash
# ============================================================================
# MACOS SPECIFIC OVERRIDES & TWEAKS
# ============================================================================
# Apple Silicon specific path if not in standard shellenv
_path_add "/opt/homebrew/bin"

# macOS-specific LS colors (BSD ls uses CLICOLOR)
if [ "$HAS_EZA" != "true" ]; then
    export CLICOLOR=1
    export LSCOLORS='Gxfxcxdxbxegedabagacad'
    alias ls='ls -G'
fi
