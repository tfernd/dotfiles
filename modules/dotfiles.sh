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

# note — Jot down a quick note with timestamp and configurable storage.
# Usage: note "Call the bank at 3PM"
# Config: run 'note-config' to set a persistent notes path,
#         or export DOTFILES_NOTES_FILE in ~/.custom.zsh.
#         If unset, notes are saved to ./notes.txt in the current directory.
unalias note 2>/dev/null || true
function note() {
    if [ -z "$1" ]; then
        local target="${DOTFILES_NOTES_FILE:-./notes.txt}"
        echo -e "📝 \033[1;33mUsage:\033[0m note \"your note content\""
        echo -e "   \033[0;90mCurrently saving to:\033[0m \033[1;36m$target\033[0m"
        if [ -n "$DOTFILES_NOTES_FILE" ]; then
            echo -e "   \033[0;90m(configured via DOTFILES_NOTES_FILE)\033[0m"
        else
            echo -e "   \033[0;90m(default: current directory)\033[0m"
        fi
        echo -e "   \033[0;90mRun 'note-config' to set a permanent notes path.\033[0m"
        return 1
    fi
    local notes_file="${DOTFILES_NOTES_FILE:-./notes.txt}"

    # Auto-create parent directory if using a configured path
    if [ -n "$DOTFILES_NOTES_FILE" ]; then
        local notes_dir=$(dirname "$notes_file")
        [ ! -d "$notes_dir" ] && mkdir -p "$notes_dir"
    fi

    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$notes_file"
    echo -e "✅ \033[1;32mNote saved to:\033[0m $notes_file"
}

# note-config — Interactively configure where notes are saved.
# Persists the setting in ~/.custom.zsh so it survives shell restarts.
unalias note-config 2>/dev/null || true
function note-config() {
    local custom_file="$HOME/.custom.zsh"
    local current="${DOTFILES_NOTES_FILE:-}"

    echo -e "\n\033[1;36m=== Note Configuration ===\033[0m\n"

    if [ -n "$current" ]; then
        echo -e "  Current path: \033[1;33m$current\033[0m"
    else
        echo -e "  Current path: \033[0;90m./notes.txt (default, saves in current directory)\033[0m"
    fi

    echo ""
    echo -n "Enter notes file path (blank to reset to default): "
    read -r new_path

    # Expand ~ to $HOME
    new_path="${new_path/#\~/$HOME}"

    # Remove any existing DOTFILES_NOTES_FILE line from custom file
    if [ -f "$custom_file" ]; then
        # Use a temp file to avoid sed -i portability issues
        grep -v '^export DOTFILES_NOTES_FILE=' "$custom_file" > "${custom_file}.tmp" 2>/dev/null
        mv "${custom_file}.tmp" "$custom_file"
    fi

    if [ -z "$new_path" ]; then
        # Reset to default
        unset DOTFILES_NOTES_FILE
        echo -e "\n✅ Reset to default (notes save to \033[1;32m./notes.txt\033[0m in current directory)"
    else
        # Validate the directory is writable (or can be created)
        local new_dir=$(dirname "$new_path")
        if [ ! -d "$new_dir" ]; then
            echo -n "Directory '$new_dir' doesn't exist. Create it? (Y/n): "
            read -r create_dir
            if [[ ! "$create_dir" =~ ^[nN] ]]; then
                mkdir -p "$new_dir" || { echo "❌ Failed to create directory."; return 1; }
            else
                echo "Cancelled."
                return 1
            fi
        fi

        # Persist in custom file (sanitize path to prevent injection)
        local safe_path="${new_path//\\/\\\\}"   # escape backslashes
        safe_path="${safe_path//\"/\\\"}"         # escape double quotes
        safe_path="${safe_path//\$/\\\$}"         # escape dollar signs
        safe_path="${safe_path//\`/\\\`}"         # escape backticks
        [ ! -f "$custom_file" ] && touch "$custom_file"
        echo "export DOTFILES_NOTES_FILE=\"$safe_path\"" >> "$custom_file"

        # Apply immediately
        export DOTFILES_NOTES_FILE="$new_path"
        echo -e "\n✅ Notes will now save to: \033[1;32m$new_path\033[0m"
        echo -e "   \033[0;90m(saved to $custom_file)\033[0m"
    fi
}
# dotfiles-share-root — Safely share this dotfiles suite with the root user.
# This symlinks the configuration and injects the loader into /root/.bashrc
function dotfiles-share-root() {
    local source_dir="$HOME/.dotfiles"
    
    if [ ! -d "$source_dir" ]; then
        echo "❌ Error: $source_dir not found. Run installer first."
        return 1
    fi

    echo -e "⚠️  This will copy dotfiles to /root/ and modify root's .bashrc/.zshrc."
    echo -n "Proceed? (y/N): "
    read -r confirm
    if [[ ! "$confirm" =~ ^[yY] ]]; then
        echo "Cancelled."
        return 0
    fi

    echo -e "🛡️  \033[1;36mSharing dotfiles with ROOT user...\033[0m"

    # 1. Copy dotfiles to /root/
    sudo rm -rf /root/.dotfiles 2>/dev/null
    sudo cp -r "$source_dir" /root/.dotfiles
    echo "📂 Copied $source_dir -> /root/.dotfiles"

    # 2. Inject loader into root's shells
    local loader="[ -f /root/.dotfiles/init.sh ] && source /root/.dotfiles/init.sh"
    sudo bash -c "grep -q 'dotfiles/init.sh' /root/.bashrc || (echo -e '\n# SHARED DOTFILES LOADER\n$loader' >> /root/.bashrc)"
    sudo bash -c "grep -q 'dotfiles/init.sh' /root/.zshrc 2>/dev/null || ([ -f /root/.zshrc ] && echo -e '\n# SHARED DOTFILES LOADER\n$loader' >> /root/.zshrc)"
    echo "📝 Injected loader into /root/.bashrc"

    # 3. Setup Starship for root
    sudo mkdir -p /root/.config
    sudo cp -f "$source_dir/starship.toml" /root/.config/starship.toml
    echo "🎨 Synced Starship config for root"

    echo -e "\n✅ \033[1;32mDone! Run 'sudo -i' to enter your new root environment.\033[0m"
}
