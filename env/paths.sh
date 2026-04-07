#!/usr/bin/env bash
# --- Guard against multiple sourcing ---
if [ "$_PATHS_LOADED" = "true" ]; then
    return
fi
_PATHS_LOADED=true

# Windows user profile HOME detection
if [ -n "$USERPROFILE" ] && [ -z "$HOME" -o "$HOME" = "/" ]; then
    export HOME=$(cygpath -u "$USERPROFILE")
fi

# 1. Windows System Paths
if [ "$IS_WIN" = "true" ]; then
    _path_add "$HOME/AppData/Local/Microsoft/WinGet/Links"
    _path_add "$HOME/AppData/Local/Programs/Microsoft VS Code/bin"
    _path_add "$HOME/AppData/Local/Programs/cursor/resources/app/bin"
    _path_add "$HOME/AppData/Local/Programs/Git/cmd"
    _path_add "/c/Program Files/starship/bin"
    _path_add "/c/Program Files/bottom/bin"
    _path_add "/c/Program Files/GitHub CLI"
fi

# 2. Tool Specific Environments
export BUN_INSTALL="$HOME/.bun"
_path_add "$BUN_INSTALL/bin"
_path_add "$HOME/.local/bin"

# 3. Homebrew (macOS or Linux)
if [ -f "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
    # Homebrew's shellenv might re-add things; we'll wrap it if needed elsewhere, 
    # but for now, simple check is fine as it usually handles itself.
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi
