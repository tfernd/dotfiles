#!/usr/bin/env bash
# ============================================================================
# THE DOTFILES MASTER INSTALLER
# ============================================================================
# Copies dotfiles to ~/.dotfiles, hooks into your shells (bash/zsh),
# and installs all required professional tools.
#
# Usage:
#   git clone https://github.com/tfernd/dotfiles.git /tmp/dotfiles
#   bash /tmp/dotfiles/install.sh
#
# Options:
#   (none)      Install missing tools only
#   --upgrade   Also upgrade already-installed tools
#   --force     Force full reinstall
# ============================================================================

# Resolve directory of this script
if [ -n "$ZSH_VERSION" ]; then
    SCRIPT_DIR="${${(%):-%x}:A:h}"
else
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
fi

# Detect platform
IS_MAC=false; IS_LINUX=false; IS_WSL=false
case "$OSTYPE" in
    darwin*) IS_MAC=true ;;
    linux*) IS_LINUX=true ;;
esac
if [ "$IS_LINUX" = "true" ] && grep -qi microsoft /proc/version 2>/dev/null; then
    IS_WSL=true
fi

function has_tool() {
    command -v "$1" >/dev/null 2>&1 && echo "true" || echo "false"
}

function bootstrap() {
    local target_dir="$HOME/.dotfiles"
    echo -e "\n\033[1;34m🛠️  BOOTSTRAPPING DOTFILES...\033[0m"

    # 1. Copy files to ~/.dotfiles (no .git needed in target)
    if [ "$SCRIPT_DIR" != "$target_dir" ]; then
        echo "🚚 Copying dotfiles to $target_dir..."
        mkdir -p "$target_dir"
        # Copy all files except .git directory
        rsync -a --exclude='.git' "$SCRIPT_DIR/" "$target_dir/" 2>/dev/null \
            || (cd "$SCRIPT_DIR" && find . -path ./.git -prune -o -print | while read f; do
                if [ -d "$f" ]; then mkdir -p "$target_dir/$f"
                else cp -f "$f" "$target_dir/$f" 2>/dev/null; fi
            done)
        echo "✅ Dotfiles installed to $target_dir"
    fi

    # 2. Replace Shell Configs with clean loader (backup old ones first)
    local source_line='[ -f $HOME/.dotfiles/init.sh ] && source $HOME/.dotfiles/init.sh'
    local custom_line='[ -f "$HOME/.custom.zsh" ] && source "$HOME/.custom.zsh"'

    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ -f "$rc" ]; then
            # Always backup the existing file
            local backup="${rc}.$(date +%Y%m%d_%H%M%S).bak"
            cp "$rc" "$backup"
            echo -e "💾 Backed up \033[1;33m$(basename "$rc")\033[0m -> \033[1;36m$backup\033[0m"
        fi

        # Write a clean shell config
        if [[ "$rc" == *".zshrc" ]]; then
            cat > "$rc" << EOF
# ============================================================================
# 🚀 DOTFILES LOADER (managed by ~/.dotfiles/install.sh)
# ============================================================================
# Your old config was backed up. Personal aliases go in ~/.custom.zsh
# Template: cp ~/.dotfiles/custom.example.sh ~/.custom.zsh
# ============================================================================

# Load the modular dotfiles
$source_line

# Load your personal overrides (if the file exists)
$custom_line
EOF
        else
            cat > "$rc" << EOF
# ============================================================================
# 🚀 DOTFILES LOADER (managed by ~/.dotfiles/install.sh)
# ============================================================================
# Your old config was backed up. Personal aliases go in ~/.custom.zsh
# Template: cp ~/.dotfiles/custom.example.sh ~/.custom.zsh
# ============================================================================

# Load the modular dotfiles
$source_line

# Load your personal overrides (if the file exists)
$custom_line
EOF
        fi
        echo -e "✅ Wrote clean \033[1;32m$(basename "$rc")\033[0m"
    done

    # 3. Deploy Starship Config (Pills design)
    echo "🎨 Deploying Starship configuration..."
    mkdir -p "$HOME/.config"
    rm -f "$HOME/.config/starship.toml" 2>/dev/null
    cp -f "$target_dir/starship.toml" "$HOME/.config/starship.toml"

}

function setup_terminal() {
    echo -e "\n\033[1;36m=================================================================\033[0m"
    echo -e "\033[1;35m  🚀 STARTING ULTIMATE TERMINAL SETUP\033[0m"
    echo -e "\033[1;36m=================================================================\033[0m\n"

    # --- Enterprise Git: SSH for enterprise only ---
    # If an enterprise GitHub host is detected (e.g. github.disney.com), ensure
    # SSH is used for that host. Public github.com stays on HTTPS (no auth needed).
    # This replaces the old approach of whitelisting every public org individually.
    if command -v git >/dev/null 2>&1; then
        local _gh_enterprise=""
        _gh_enterprise=$(git config --global --get-regexp 'credential\.https://.*\.helper' 2>/dev/null \
            | grep -iv 'credential\.https://github\.com[^.]' \
            | head -1 \
            | sed -E 's|^credential\.https://([^/]+).*|\1|')

        if [ -z "$_gh_enterprise" ]; then
            _gh_enterprise=$(git config --global --get-regexp 'url\..*\.insteadof' 2>/dev/null \
                | grep -iv 'github\.com/' \
                | head -1 \
                | sed -E 's|^url\.[^/]*//([^/]+)/.*|\1|')
        fi

        if [ -n "$_gh_enterprise" ] && [ "$_gh_enterprise" != "github.com" ]; then
            # Only add if not already set
            if ! git config --global --get "url.ssh://git@${_gh_enterprise}/.insteadOf" >/dev/null 2>&1; then
                git config --global url."ssh://git@${_gh_enterprise}/".insteadOf "https://${_gh_enterprise}/"
                echo "🔧 Enterprise SSH rewrite: https://${_gh_enterprise}/ → ssh://git@${_gh_enterprise}/"
            fi
        fi
        unset _gh_enterprise
    fi

    # --- Tool Installation (macOS & Linux) ---
    if [ "$IS_MAC" = "true" ]; then
        echo -e "\033[1;34m🍎 macOS Detected. Installing via Homebrew...\033[0m"
        if [ "$(has_tool brew)" = "false" ]; then
            echo "🍺 Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null
        fi

        if [ "$UPGRADE_MODE" = "true" ]; then
            echo "📦 Upgrading all Homebrew packages..."
            brew update && brew upgrade
        fi

        # Install only missing packages (brew install is a no-op for already installed)
        echo "📦 Installing missing tools via Homebrew..."
        brew install starship zoxide bat eza ripgrep fd fzf trash-cli gh lazygit yazi bottom yq xh \
            git-delta jq tealdeer bc cmatrix telnet \
            p7zip zip unzip xz zstd \
            zsh-autosuggestions zsh-syntax-highlighting 2>/dev/null

        echo "🔡 Installing FiraCode Nerd Font..."
        brew install --cask font-fira-code-nerd-font 2>/dev/null || true
    elif [ "$IS_LINUX" = "true" ]; then
        echo -e "\033[1;34m🐧 Linux Detected. Installing via APT...\033[0m"
        sudo apt update

        if [ "$UPGRADE_MODE" = "true" ]; then
            echo "📦 Upgrading all APT packages..."
            sudo apt upgrade -y
        fi

        sudo apt install -y git build-essential zsh tealdeer trash-cli xclip fontconfig bc \
            cmatrix telnet \
            zsh-autosuggestions zsh-syntax-highlighting \
            curl jq procps lsof wget bat fd-find fzf ripgrep \
            unzip zip p7zip-full unrar-free xz-utils zstd bzip2 \
            xdg-utils

        # WSL: ensure a browser opener is available (wslview or shim)
        if [ "$IS_WSL" = "true" ] && [ "$(has_tool wslview)" = "false" ]; then
            echo -e "\033[1;33m📦 Installing wslview (WSL browser integration)...\033[0m"
            if sudo apt install -y wslu 2>/dev/null; then
                echo "✅ wslu installed via apt"
            else
                echo "📦 wslu not in apt repos, installing wslview shim..."
                cat > "$HOME/.local/bin/wslview" << 'SHIM'
#!/bin/bash
# Minimal wslview shim — opens URLs/files in the Windows default browser
powershell.exe -NoProfile -Command "Start-Process '$1'" 2>/dev/null
SHIM
                chmod +x "$HOME/.local/bin/wslview"
                echo "✅ wslview shim installed to ~/.local/bin/wslview"
            fi
        fi

        # GitHub CLI (gh) via official apt repository
        if [ "$(has_tool gh)" = "false" ]; then
            echo -e "\033[1;33m📦 Installing GitHub CLI (gh)...\033[0m"
            sudo mkdir -p -m 755 /etc/apt/keyrings
            curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
            sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
            sudo apt update && sudo apt install -y gh
        fi

        # Starship prompt
        if [ "$(has_tool starship)" = "false" ]; then
            echo -e "\033[1;33m📦 Installing Starship...\033[0m"
            curl -sS https://starship.rs/install.sh | sh -s -- -y
        fi

        # Zoxide
        if [ "$(has_tool zoxide)" = "false" ]; then
            echo -e "\033[1;33m📦 Installing Zoxide...\033[0m"
            curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
        fi

        # git-delta
        if [ "$(has_tool delta)" = "false" ]; then
            echo -e "\033[1;33m📦 Installing git-delta...\033[0m"
            local DELTA_VER=$(curl -s "https://api.github.com/repos/dandavison/delta/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
            curl -Lo /tmp/git-delta.deb "https://github.com/dandavison/delta/releases/download/${DELTA_VER}/git-delta_${DELTA_VER}_$(dpkg --print-architecture).deb"
            sudo dpkg -i /tmp/git-delta.deb && rm -f /tmp/git-delta.deb
        fi

        # Fix Debian/Ubuntu binary naming
        mkdir -p ~/.local/bin
        [ -f "$(command -v fdfind)" ] && ln -sf "$(command -v fdfind)" ~/.local/bin/fd 2>/dev/null
        [ -f "$(command -v batcat)" ] && ln -sf "$(command -v batcat)" ~/.local/bin/bat 2>/dev/null

        # FiraCode Nerd Font
        if ! fc-list 2>/dev/null | grep -qi "FiraCode Nerd"; then
            echo -e "\033[1;33m🔡 Installing FiraCode Nerd Font...\033[0m"
            mkdir -p ~/.local/share/fonts
            curl -Lo /tmp/FiraCode.zip "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"
            unzip -o /tmp/FiraCode.zip -d ~/.local/share/fonts/
            fc-cache -fv ~/.local/share/fonts/
            rm -f /tmp/FiraCode.zip
        fi

        # Linuxbrew for tools not available via APT
        if [ "$(has_tool brew)" = "false" ]; then
            echo -e "\033[1;33m📦 Installing Linuxbrew...\033[0m"
            NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" 2>/dev/null
        fi

        if [ "$(has_tool brew)" = "true" ]; then
            if [ "$UPGRADE_MODE" = "true" ]; then
                echo "📦 Upgrading Linuxbrew packages..."
                brew update && brew upgrade
            fi
            echo "📦 Installing missing tools via Linuxbrew..."
            brew install eza lazygit xh yazi bottom yq 2>/dev/null
        fi
    fi

    # --- Bun Runtime ---
    if [ "$(has_tool bun)" = "false" ]; then
        echo "🍞 Installing Bun..."
        curl -fsSL https://bun.sh/install | bash
    fi

    # --- Oh My Zsh ---
    if [ "$CURRENT_SHELL" = "zsh" ] || [ "$(has_tool zsh)" = "true" ]; then
        if [ ! -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then
            # Remove stale/broken OMZ directory if it exists
            [ -d "$HOME/.oh-my-zsh" ] && rm -rf "$HOME/.oh-my-zsh"
            echo "🐚 Installing Oh My Zsh..."
            RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || true

            # Verify installation succeeded
            if [ ! -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then
                echo -e "\033[1;33m⚠️  Oh My Zsh installation failed. Zsh will work without it.\033[0m"
            fi
        fi

        # Set zsh as default shell if it isn't already
        local zsh_path=$(command -v zsh 2>/dev/null)
        if [ -n "$zsh_path" ] && [ "$SHELL" != "$zsh_path" ]; then
            echo "🐚 Setting zsh as default shell..."
            if grep -q "$zsh_path" /etc/shells 2>/dev/null; then
                chsh -s "$zsh_path" 2>/dev/null || sudo chsh -s "$zsh_path" "$USER" 2>/dev/null || true
            else
                echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null 2>&1
                chsh -s "$zsh_path" 2>/dev/null || sudo chsh -s "$zsh_path" "$USER" 2>/dev/null || true
            fi
        fi
    fi

    # --- UV Standalone Installation (Astral) ---
    if [ "$(has_tool uv)" = "false" ]; then
        echo "🐍 Installing UV via official standalone installer (astral.sh)..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
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

    # --- Re-deploy configs (OMZ installer may have overwritten .zshrc) ---
    bootstrap

    echo -e "\n💡 Run \033[1;36meditor-config\033[0m to get recommended VS Code / Kiro settings for your terminal."
    echo -e "\n\033[1;32m🎉 Setup complete! Reloading your shell...\033[0m"
    exec $SHELL --login
}

REQUIRED_TOOLS=("starship" "zoxide" "eza" "bat" "rg" "fd" "fzf" "trash" "gh" "lazygit" "yazi" "btm" "yq" "uv" "xh" "delta")

function check_all_tools() {
    for tool in "${REQUIRED_TOOLS[@]}"; do
        if [ "$tool" = "trash" ]; then
            # On Linux, trash-cli provides "trash-put" instead of "trash"
            if [ "$(has_tool trash-put)" = "false" ] && [ "$(has_tool trash)" = "false" ]; then
                return 1
            fi
        elif [ "$(has_tool $tool)" = "false" ]; then
            return 1
        fi
    done
    return 0
}

# --- Execution ---
FORCE_SETUP=false
UPGRADE_MODE=false
[[ "$*" == *"--help"* ]] && {
    echo "Usage: bash install.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  (none)      Install missing tools only"
    echo "  --upgrade   Also upgrade already-installed tools"
    echo "  --force     Force full reinstall of everything"
    echo "  --help      Show this help message and exit"
    exit 0
}
[[ "$*" == *"--force"* ]]   && FORCE_SETUP=true
[[ "$*" == *"--upgrade"* ]] && UPGRADE_MODE=true

export UPGRADE_MODE

bootstrap

# Trigger setup if tools are missing, --force, or --upgrade
if [ "$FORCE_SETUP" = "true" ] || [ "$UPGRADE_MODE" = "true" ] || ! check_all_tools; then
    setup_terminal
else
    echo -e "\n\033[1;32m🎉 Everything is wired up! Open a new tab to see your new prompt.\033[0m"
    echo -e "💡 TIP: Run \033[1;36msetup-terminal\033[0m anytime to fix your environment or reinstall tools.\n"
fi
