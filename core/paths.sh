#!/usr/bin/env bash
# ============================================================================
# SYSTEM PATHS & BINARY DISCOVERY
# ============================================================================

# --- Path Guard ---
# Prevents expensive path reconstruction when re-sourcing the shell.
if [ "$_PATHS_LOADED" = "true" ]; then
    return
fi
_PATHS_LOADED=true

# 1. Tool Specific Environments
export BUN_INSTALL="$HOME/.bun"
_path_add "$BUN_INSTALL/bin"
_path_add "$HOME/.local/bin"

# 2. Homebrew (macOS or Linux)
if [ -f "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
    # Homebrew's shellenv might re-add things; we'll wrap it if needed elsewhere, 
    # but for now, simple check is fine as it usually handles itself.
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi
