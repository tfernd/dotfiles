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
