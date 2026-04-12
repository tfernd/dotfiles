#!/usr/bin/env bash
# ============================================================================
# 🚀 THE DOTFILES MASTER INSTALLER
# ============================================================================
# This script bootstraps the directory (~/.dotfiles), hooks into your shells
# (bash/zsh), and installs all required professional tools.
# 
# One-liner:
# rm -rf /tmp/dotfiles && gh repo clone tfernd/dotfiles /tmp/dotfiles && bash /tmp/dotfiles/install.sh
# ============================================================================

# Resolve directory of this script
if [ -n "$ZSH_VERSION" ]; then
    SCRIPT_DIR="${${(%):-%x}:A:h}"
else
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
fi

# Detect platform
IS_MAC=false; IS_LINUX=false; IS_WIN=false
case "$OSTYPE" in
    darwin*) IS_MAC=true ;;
    linux*) IS_LINUX=true ;;
    msys*|cygwin*) IS_WIN=true ;;
esac

function has_tool() {
    command -v "$1" >/dev/null 2>&1 && echo "true" || echo "false"
}

function bootstrap() {
    local target_dir="$HOME/.dotfiles"
    local repo_url="https://github.com/tfernd/dotfiles.git"

    echo -e "\n\033[1;34m🛠️  BOOTSTRAPPING DOTFILES...\033[0m"

    # 1. Force Sync to ~/.dotfiles (as a copy, per user request)
    if [ "$SCRIPT_DIR" != "$target_dir" ] && [[ "$SCRIPT_DIR" != /tmp/* ]]; then
        echo "🚚 Syncing dotfiles copy to $target_dir..."
        mkdir -p "$target_dir"
        cp -rf "$SCRIPT_DIR"/. "$target_dir"/
    elif [ ! -d "$target_dir" ]; then
        echo "📥 Downloading dotfiles to $target_dir..."
        if [ "$(has_tool git)" != "true" ]; then
            echo "📦 Git not found. Attempting install..."
            if [ "$IS_MAC" = "true" ]; then xcode-select --install || brew install git
            elif [ "$IS_LINUX" = "true" ]; then sudo apt update && sudo apt install -y git; fi
        fi
        git clone "$repo_url" "$target_dir"
        SCRIPT_DIR="$target_dir"
    fi

    # 2. Inject into Shell Configs (Safe & Persistent)
    local source_line="[ -f \$HOME/.dotfiles/init.sh ] && source \$HOME/.dotfiles/init.sh"
    for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
        # Create if missing
        [ ! -f "$rc" ] && touch "$rc" && echo "🆕 Created missing $(basename "$rc")"
        
        if ! grep -q "dotfiles/init.sh" "$rc"; then
            echo "📝 Adding loader to $(basename "$rc")..."
            echo -e "\n# THE DOTFILES MASTER LOADER\n$source_line" >> "$rc"
        fi
    done

    # 3. Deploy Starship Config (Pills design)
    echo "🎨 Deploying Starship configuration..."
    mkdir -p "$HOME/.config"
    ln -sfn "$target_dir/starship.toml" "$HOME/.config/starship.toml"
}

function setup_terminal() {
    echo -e "\n\033[1;36m=================================================================\033[0m"
    echo -e "\033[1;35m  🚀 STARTING ULTIMATE TERMINAL SETUP\033[0m"
    echo -e "\033[1;36m=================================================================\033[0m\n"

    # --- Tool Installation (macOS & Linux) ---
    if [ "$IS_MAC" = "true" ]; then
        echo "🍎 macOS Detected. Installing via Homebrew..."
        [ "$(has_tool brew)" = "false" ] && /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        brew install starship zoxide bat eza ripgrep fd fzf trash-cli gh lazygit yazi bottom yq xh p7zip zip unzip xz zstd
    elif [ "$IS_LINUX" = "true" ]; then
        echo "🐧 Linux Detected. Updating and installing via APT..."
        sudo apt update
        sudo apt install -y git build-essential zsh tldr trash-cli xclip zsh-autosuggestions zsh-syntax-highlighting \
            curl jq procps wget bat fd-find fzf ripgrep unzip zip p7zip-full unrar-free xz-utils zstd bzip2

        # Install modern tools if missing (brew is usually best for these on linux)
        if [ "$(has_tool brew)" = "false" ] && [ "$(has_tool eza)" = "false" ]; then
            echo "🍺 Installing Homebrew for Linux to get modern tools..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        fi
        
        # Prefer brew's version of these for updated features
        if [ "$(has_tool brew)" = "true" ]; then
            brew install eza lazygit xh yazi bottom yq
        fi
    elif [ "$IS_WIN" = "true" ]; then
        echo "🪟 Windows Detected. Attempting installation via Scoop..."
        if [ "$(has_tool scoop)" = "false" ]; then
            echo "🍦 Scoop not found. Please install it first: https://scoop.sh"
        else
            scoop install starship zoxide bat eza ripgrep fd fzf gh lazygit yazi-nightly bottom yq xh 7zip zip unzip xz zstd
        fi
    fi

    # --- UV Standalone Installation (Astral) ---
    if [ "$(has_tool uv)" = "false" ]; then
        echo "🐍 Installing UV via official standalone installer (astral.sh)..."
        if [ "$IS_WIN" = "true" ]; then
            powershell.exe -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
        else
            curl -LsSf https://astral.sh/uv/install.sh | sh
        fi
    else
        echo "🐍 UV already installed, skipping."
    fi

    # --- Post-Install: Git Config (Delta) ---
    if [ "$(has_tool delta)" = "true" ]; then
        echo -e "\n🔧 Configuring git to use delta..."
        git config --global core.pager "delta"
        git config --global interactive.diffFilter "delta --color-only"
        git config --global delta.navigate true
        git config --global delta.light false
        git config --global merge.conflictstyle zdiff3
    fi

    echo -e "\n\033[1;32m🎉 Setup complete! Reloading your shell...\033[0m"
    exec $SHELL --login
}

REQUIRED_TOOLS=("starship" "zoxide" "eza" "bat" "rg" "fd" "fzf" "trash" "gh" "lazygit" "yazi" "btm" "yq" "uv" "xh" "delta")

function check_all_tools() {
    for tool in "${REQUIRED_TOOLS[@]}"; do
        if [ "$(has_tool $tool)" = "false" ]; then
            return 1
        fi
    done
    return 0
}

# --- Execution ---
FORCE_SETUP=false
[[ "$*" == *"--force" ]] && FORCE_SETUP=true

bootstrap

# Trigger setup if tools are missing OR --force is specified
if [ "$FORCE_SETUP" = "true" ] || ! check_all_tools; then
    setup_terminal
else
    echo -e "\n\033[1;32m🎉 Everything is wired up! Open a new tab to see your new prompt.\033[0m"
    echo -e "💡 TIP: Run \033[1;36msetup-terminal\033[0m anytime to fix your environment or reinstall tools.\n"
fi
