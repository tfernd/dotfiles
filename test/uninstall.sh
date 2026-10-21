#!/usr/bin/env bash
# ============================================================================
# 🧪 TEST UNINSTALL — Removes all dotfiles-managed tools for clean testing
# ============================================================================
# Usage:
#   bash test/uninstall.sh
#
# This is NOT part of the dotfiles — it's a test helper to simulate a
# bare system so you can verify install.sh works from scratch.
#
# ⚠️  DESTRUCTIVE — removes tools, configs, and caches!
# ============================================================================
set -euo pipefail

echo -e "\n\033[1;31m=================================================================\033[0m"
echo -e "\033[1;31m  ⚠️  DOTFILES TEST UNINSTALL (destructive!)\033[0m"
echo -e "\033[1;31m=================================================================\033[0m\n"

echo -e "\033[1;33mThis will remove:\033[0m"
echo "  • All pinned binaries from ~/.local/bin"
echo "  • Oh My Zsh (~/.oh-my-zsh)"
echo "  • Dotfiles deployment (~/.dotfiles)"
echo "  • Tool caches (~/.cache/dotfiles_tools, starship, zoxide, atuin, gh)"
echo "  • Starship / Atuin / Zellij configs"
echo "  • Dotfiles loader from ~/.zshrc"
echo ""
echo -e "\033[1;33mIt will NOT remove:\033[0m"
echo "  • APT system packages (zsh, git, curl, etc.)"
echo "  • Homebrew or brew-installed packages"
echo "  • Your ~/.zshrc (only removes the loader line)"
echo "  • Your git config"
echo "  • Your SSH keys"
echo ""
echo -n "Are you sure? (type 'yes' to confirm): "
read -r confirm
if [[ "$confirm" != "yes" ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""

# --- Remove pinned binaries ---
echo "🗑️  Removing pinned binaries from ~/.local/bin..."
TOOLS=(starship rg uv zoxide delta eza bat xh yq bun atuin zellij)
for tool in "${TOOLS[@]}"; do
    if [[ -f "$HOME/.local/bin/$tool" ]]; then
        rm -f "$HOME/.local/bin/$tool"
        echo "   removed: $tool"
    fi
done

# --- Remove Oh My Zsh ---
if [[ -d "$HOME/.oh-my-zsh" ]]; then
    echo "🗑️  Removing Oh My Zsh..."
    rm -rf "$HOME/.oh-my-zsh"
fi

# --- Remove dotfiles deployment ---
if [[ -d "$HOME/.dotfiles" ]]; then
    echo "🗑️  Removing ~/.dotfiles..."
    rm -rf "$HOME/.dotfiles"
fi

# --- Remove caches ---
echo "🗑️  Removing caches..."
rm -f "$HOME/.cache/dotfiles_tools"
rm -f "$HOME/.cache/starship_init.zsh"
rm -f "$HOME/.cache/zoxide_init.zsh"
rm -f "$HOME/.cache/atuin_init.zsh"
rm -f "$HOME/.cache/gh_completion.zsh"

# --- Remove deployed configs ---
rm -f "$HOME/.config/starship.toml"
rm -f "$HOME/.config/atuin/config.toml"
rm -f "$HOME/.config/zellij/config.kdl"
rmdir "$HOME/.config/atuin" 2>/dev/null || true
rmdir "$HOME/.config/zellij" 2>/dev/null || true

# --- Remove dotfiles loader from .zshrc ---
if [[ -f "$HOME/.zshrc" ]]; then
    echo "🗑️  Removing dotfiles loader from ~/.zshrc..."
    sed -i '/dotfiles\/core\/init.zsh/d' "$HOME/.zshrc"
    sed -i '/Dotfiles loader/d' "$HOME/.zshrc"
fi

# --- Remove fonts ---
if [[ -d "$HOME/.local/share/fonts" ]]; then
    echo "🗑️  Removing Nerd Fonts..."
    rm -rf "$HOME/.local/share/fonts/FiraCode"*
    rm -rf "$HOME/.local/share/fonts/Fira Code"*
    fc-cache -f 2>/dev/null || true
fi

echo ""
echo -e "\033[1;32m✅ Uninstall complete.\033[0m"
echo ""
echo "To test a fresh install:"
echo "  bash install.sh"
echo ""
echo "To also remove APT packages (full bare-metal test):"
echo "  sudo apt remove -y trash-cli xclip cmatrix p7zip-full tealdeer"
echo "  sudo apt autoremove -y"
