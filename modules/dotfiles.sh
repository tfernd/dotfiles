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
# dotfiles-share-root — Safely share this dotfiles suite with the root user.
# This symlinks the configuration and injects the loader into /root/.bashrc
function dotfiles-share-root() {
    local source_dir="$HOME/.dotfiles"
    
    if [ ! -d "$source_dir" ]; then
        echo "❌ Error: $source_dir not found. Run installer first."
        return 1
    fi

    echo -e "🛡️  \033[1;36mSharing dotfiles with ROOT user...\033[0m"

    # 1. Symlink dotfiles to /root/
    sudo ln -sfn "$source_dir" /root/.dotfiles
    echo "🔗 Symlinked $source_dir -> /root/.dotfiles"

    # 2. Inject loader into root's shells
    local loader="[ -f /root/.dotfiles/init.sh ] && source /root/.dotfiles/init.sh"
    sudo bash -c "grep -q 'dotfiles/init.sh' /root/.bashrc || (echo -e '\n# SHARED DOTFILES LOADER\n$loader' >> /root/.bashrc)"
    sudo bash -c "grep -q 'dotfiles/init.sh' /root/.zshrc 2>/dev/null || ([ -f /root/.zshrc ] && echo -e '\n# SHARED DOTFILES LOADER\n$loader' >> /root/.zshrc)"
    echo "📝 Injected loader into /root/.bashrc"

    # 3. Setup Starship for root
    sudo mkdir -p /root/.config
    sudo ln -sfn "$source_dir/starship.toml" /root/.config/starship.toml
    echo "🎨 Synced Starship config for root"

    echo -e "\n✅ \033[1;32mDone! Run 'sudo -i' to enter your new root environment.\033[0m"
}
