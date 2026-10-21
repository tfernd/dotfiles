# ============================================================================
# PLATFORM DETECTION (WSL2 Debian, Linux Debian, macOS)
# ============================================================================

export DOTFILES_PLATFORM=""

case "$OSTYPE" in
    darwin*)
        DOTFILES_PLATFORM="macos"
        ;;
    linux*)
        if grep -qi microsoft /proc/version 2>/dev/null; then
            DOTFILES_PLATFORM="wsl"
        else
            DOTFILES_PLATFORM="debian"
        fi
        ;;
    *)
        echo "⚠️  Unsupported platform: $OSTYPE" >&2
        ;;
esac

export IS_MAC=$([[ "$DOTFILES_PLATFORM" == "macos" ]] && echo true || echo false)
export IS_LINUX=$([[ "$DOTFILES_PLATFORM" == "debian" || "$DOTFILES_PLATFORM" == "wsl" ]] && echo true || echo false)
export IS_WSL=$([[ "$DOTFILES_PLATFORM" == "wsl" ]] && echo true || echo false)
