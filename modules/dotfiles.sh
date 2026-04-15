#!/usr/bin/env bash

# ============================================================================
# DOTFILES MANAGEMENT
# ============================================================================

# setup-terminal — Re-run the installation script to fix tools or git config
function setup-terminal() {
    local dot_dir="$HOME/.dotfiles"
    if [ -f "$dot_dir/install.sh" ]; then
        echo "🚀 Running dotfiles installer..."
        bash "$dot_dir/install.sh" --force
    else
        echo "❌ Error: $dot_dir/install.sh not found."
        return 1
    fi
}

# update-dotfiles — Pull latest changes and refresh
function update-dotfiles() {
    local dot_dir="$HOME/.dotfiles"
    if [ -d "$dot_dir/.git" ]; then
        echo "📥 Pulling latest dotfiles..."
        (cd "$dot_dir" && git pull && bash install.sh)
    else
        echo "❌ Error: $dot_dir is not a git repository."
        return 1
    fi
}

# note — Jot down a quick note with timestamp and configurable storage.
# Usage: note "Call the bank at 3PM"
# Config: set DOTFILES_NOTES_FILE to override default (~/.notes.txt)
unalias note 2>/dev/null || true
function note() {
    if [ -z "$1" ]; then
        echo -e "📝 \033[1;33mUsage:\033[0m note \"your note content\""
        return 1
    fi
    local notes_file="${DOTFILES_NOTES_FILE:-$HOME/.notes.txt}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$notes_file"
    echo -e "✅ \033[1;32mNote saved to:\033[0m $notes_file"
}
