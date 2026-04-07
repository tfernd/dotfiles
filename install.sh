#!/usr/bin/env bash
# ============================================================================
# 🛠️ DOTFILES INSTALLER / BOOTSTRAPPER
# ============================================================================
# This script bootstraps the dotfiles to ~/.dotfiles, configures your shell 
# (bash/zsh), and installs all required professional tools.
# 
# One-liner:
# bash -c "$(curl -fsSL https://raw.githubusercontent.com/tfernd/dotfiles/main/install.sh)"
# ============================================================================

# Resolve directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source core variables for system detection
if [ -f "$SCRIPT_DIR/env/os-detect.sh" ]; then
    source "$SCRIPT_DIR/env/os-detect.sh"
else
    [ -z "$IS_LINUX" ] && IS_LINUX=$(uname -s | grep -qi Linux && echo true || echo false)
    [ -z "$IS_MAC" ]   && IS_MAC=$(uname -s | grep -qi Darwin && echo true || echo false)
    [ -z "$IS_WIN" ]   && IS_WIN=$(expr substr $(uname -s) 1 5 | grep -qi MSYS && echo true || echo false)
fi

DRY_RUN="${DRY_RUN:-false}"

function has_tool() { command -v "$1" >/dev/null 2>&1 && echo true || echo false; }

function bootstrap() {
    local target_dir="$HOME/.dotfiles"
    local repo_url="https://github.com/tfernd/dotfiles.git"
    
    echo -e "\n\033[1;34m🛠️  BOOTSTRAPPING DOTFILES...\033[0m"

    # 1. Clone or Move to ~/.dotfiles
    if [ ! -d "$target_dir" ]; then
        if [ -d "$SCRIPT_DIR/.git" ] && [ "$SCRIPT_DIR" != "$target_dir" ]; then
            echo "🔗 Linking current directory to $target_dir..."
            ln -sfn "$SCRIPT_DIR" "$target_dir"
        else
            echo "📥 Cloning repository to $target_dir..."
            if [ "$(has_tool git)" != "true" ]; then
                echo "📦 Git not found. Installing git first..."
                if [ "$IS_MAC" = "true" ]; then xcode-select --install || brew install git
                elif [ "$IS_LINUX" = "true" ]; then sudo apt update && sudo apt install -y git; fi
            fi
            git clone "$repo_url" "$target_dir"
        fi
    else
        echo "✅ $target_dir already exists."
    fi

    # 2. Inject into Shell Configs
    local source_line="[ -f \$HOME/.dotfiles/init.sh ] && source \$HOME/.dotfiles/init.sh"
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ -f "$rc" ]; then
            if ! grep -q "dotfiles/init.sh" "$rc"; then
                echo "📝 Adding loader to $(basename "$rc")..."
                echo -e "\n# THE DOTFILES MASTER LOADER\n$source_line" >> "$rc"
            else
                echo "✅ Loader already present in $(basename "$rc")."
            fi
        fi
    done

    # 3. Deploy Starship Config
    mkdir -p "$HOME/.config"
    if [ -f "$target_dir/starship.toml" ]; then
        echo "🎨 Deploying Starship configuration..."
        if [ "$IS_WIN" = "true" ]; then
            cp "$target_dir/starship.toml" "$HOME/.config/starship.toml"
        else
            ln -sfn "$target_dir/starship.toml" "$HOME/.config/starship.toml"
        fi
    fi
}

function setup-terminal() {
    # Bootstrap first
    bootstrap

    echo -e "\n\033[1;35m=================================================================\033[0m"
    echo -e "\033[1;36m  🚀 STARTING ULTIMATE TERMINAL SETUP\033[0m"
    echo -e "\033[1;35m=================================================================\033[0m\n"

    if [ "$DRY_RUN" = "true" ]; then
        echo -e "\033[1;33m⚠️ DRY RUN MODE ENABLED. No changes will be made.\033[0m"
    fi

    # Pre-cache Sudo privileges
    if [ "$IS_WIN" != "true" ] && [ "$DRY_RUN" != "true" ]; then
        if ! sudo -v 2>/dev/null; then
            echo -e "\n🛑 Sudo access was cancelled. Setup aborted!"
            return 1
        fi
    fi

    if [ "$IS_MAC" = "true" ]; then
        echo -e "\033[1;34m🍎 macOS Detected. Updating and installing via Homebrew...\033[0m"
        if [ "$DRY_RUN" != "true" ]; then
            brew update && brew upgrade
            brew install starship zoxide bat eza ripgrep fd tealdeer lazygit gh fzf trash-cli git-delta jq xh yazi bottom zsh-autosuggestions zsh-syntax-highlighting yq uv
            brew install --cask font-fira-code-nerd-font
        else
            echo "[DRY RUN] Would brew install starship, zoxide, bat, eza, ripgrep, fd, tealdeer, etc."
        fi

    elif [ "$IS_LINUX" = "true" ]; then
        echo -e "\033[1;34m🐧 Linux Detected. Updating and installing via APT...\033[0m"
        if [ "$DRY_RUN" != "true" ]; then
            sudo apt update && sudo apt upgrade -y
            sudo apt install -y curl wget unzip git zsh bat ripgrep fd-find tldr fzf xclip zsh-autosuggestions zsh-syntax-highlighting trash-cli jq build-essential procps
        else
            echo "[DRY RUN] Would apt install curl, wget, unzip, git, zsh, bat, ripgrep, etc."
        fi
        
        # Install gh, starship, zoxide if missing
        if [ "$DRY_RUN" != "true" ]; then
            [ "$(has_tool gh)" != "true" ] && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null && sudo apt update && sudo apt install -y gh
            [ "$(has_tool starship)" != "true" ] && curl -sS https://starship.rs/install.sh | sh -s -- -y
            [ "$(has_tool zoxide)" != "true" ]   && curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash

            # Advanced tools via Homebrew (recommended for Linux)
            if [ "$(has_tool brew)" != "true" ]; then
                 NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                 eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
            fi
            brew install eza lazygit xh yazi bottom yq uv
        else
            echo "[DRY RUN] Would install specialized tools (gh, starship, zoxide, brew)."
        fi
    fi

    # Configure Git Delta
    if command -v delta >/dev/null 2>&1; then
        echo -e "\n\033[1;33m🔧 Configuring git to use delta...\033[0m"
        if [ "$DRY_RUN" != "true" ]; then
            git config --global core.pager "delta"
            git config --global interactive.diffFilter "delta --color-only"
            git config --global delta.navigate "true"
            git config --global delta.line-numbers "true"
            git config --global merge.conflictStyle "zdiff3"
        else
            echo "[DRY RUN] Would configure git delta settings."
        fi
    fi

    echo -e "\n\033[1;32m🎉 Setup complete! Reloading your shell...\033[0m"
    exec $SHELL --login
}

# Run the setup if script is executed directly
if [[ "$0" == "$BASH_SOURCE" ]]; then
    setup-terminal
fi
