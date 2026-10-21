# ============================================================================
# PATH CONSTRUCTION
# ============================================================================

# --- Path Helper (prepend if exists and not already in PATH) ---
function _path_add() {
    local dir="$1"
    [[ -d "$dir" ]] && path=("$dir" $path)
}

# Deduplicate (zsh native)
typeset -gU path

# --- Homebrew (direct assignments, no eval) ---
# Added FIRST so our local paths can override brew-installed tools
if [[ -f "/opt/homebrew/bin/brew" ]]; then
    export HOMEBREW_PREFIX="/opt/homebrew"
    export HOMEBREW_CELLAR="/opt/homebrew/Cellar"
    export HOMEBREW_REPOSITORY="/opt/homebrew"
    path=("/opt/homebrew/bin" "/opt/homebrew/sbin" $path)
    export MANPATH="/opt/homebrew/share/man:${MANPATH:-}"
    export INFOPATH="/opt/homebrew/share/info:${INFOPATH:-}"
elif [[ -f "/usr/local/bin/brew" ]]; then
    export HOMEBREW_PREFIX="/usr/local"
    export HOMEBREW_CELLAR="/usr/local/Cellar"
    export HOMEBREW_REPOSITORY="/usr/local/Homebrew"
    path=("/usr/local/bin" "/usr/local/sbin" $path)
    export MANPATH="/usr/local/share/man:${MANPATH:-}"
    export INFOPATH="/usr/local/share/info:${INFOPATH:-}"
elif [[ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
    export HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
    export HOMEBREW_CELLAR="/home/linuxbrew/.linuxbrew/Cellar"
    export HOMEBREW_REPOSITORY="/home/linuxbrew/.linuxbrew/Homebrew"
    path=("/home/linuxbrew/.linuxbrew/bin" "/home/linuxbrew/.linuxbrew/sbin" $path)
    export MANPATH="/home/linuxbrew/.linuxbrew/share/man:${MANPATH:-}"
    export INFOPATH="/home/linuxbrew/.linuxbrew/share/info:${INFOPATH:-}"
fi

# --- Keg-only Homebrew formulae we depend on ---
# trash-cli is keg-only on macOS (Homebrew won't symlink trash-put/list/restore
# into the prefix because macOS ships its own `trash`). Add its bin dir here,
# BEFORE tool-cache.zsh runs, so HAS_TRASH_PUT is detected correctly and the
# trash module's rl/rt/empty-trash commands are defined.
[[ -n "$HOMEBREW_PREFIX" ]] && _path_add "$HOMEBREW_PREFIX/opt/trash-cli/bin"

# --- Local tool paths (AFTER brew so they take priority) ---
export BUN_INSTALL="$HOME/.bun"
_path_add "$BUN_INSTALL/bin"
_path_add "$HOME/.cargo/bin"
_path_add "$HOME/.local/bin"
