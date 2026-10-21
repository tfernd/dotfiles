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

# --- Agent / non-interactive shells ---
# True for shells no human types into: non-interactive, TERM=dumb (most AI
# terminals), Claude Code (CLAUDECODE=1), or forced with DOTFILES_AGENT=1.
# Modules use it to keep output plain and behaviour predictable.
if [[ ! -o interactive || "$TERM" == "dumb" || -n "$CLAUDECODE" || -n "$DOTFILES_AGENT" ]]; then
    export IS_AGENT=true
else
    export IS_AGENT=false
fi
