#!/usr/bin/env zsh
# ============================================================================
# 🚀 DOTFILES MASTER LOADER (zsh-only)
# ============================================================================
# Sourced from ~/.zshrc. install.sh appends this line; the repo loads in place:
#   [ -f "<repo>/core/init.zsh" ] && source "<repo>/core/init.zsh"
# ============================================================================

DOTFILES_DIR="${${(%):-%x}:A:h:h}"

# --- Profiling ---
if [[ "$PROFILE_DOTFILES" == "true" ]]; then
    zmodload zsh/datetime
    _DOT_START=$EPOCHREALTIME
fi

function _dot_source() {
    local file="$1"
    if [[ "$PROFILE_DOTFILES" == "true" ]]; then
        local start=$EPOCHREALTIME
        source "$file"
        local elapsed=$(printf "%.2f" $(( (EPOCHREALTIME - start) * 1000 )))
        printf "  \033[38;5;244m%-30s\033[0m \033[1;32m%7s ms\033[0m\n" "${file:t}" "$elapsed"
    else
        source "$file"
    fi
}

[[ "$PROFILE_DOTFILES" == "true" ]] && echo -e "\n\033[1;35m🚀 Profiling Dotfiles Startup...\033[0m"

# --- Prevent duplicate entries ---
typeset -gU path fpath cdpath

# 1. Core (order matters)
for _f in platform.zsh paths.zsh history.zsh tool-cache.zsh; do
    [[ -f "$DOTFILES_DIR/core/$_f" ]] && _dot_source "$DOTFILES_DIR/core/$_f"
done

# 2. Plugins
for _f in shell.zsh zoxide.zsh atuin.zsh zellij.zsh; do
    [[ -f "$DOTFILES_DIR/plugins/$_f" ]] && _dot_source "$DOTFILES_DIR/plugins/$_f"
done

# 3. Modules (recursive glob)
for _f in "$DOTFILES_DIR"/modules/**/*.zsh(N); do
    _dot_source "$_f"
done

# 4. Platform overrides
[[ -n "$DOTFILES_PLATFORM" && -f "$DOTFILES_DIR/platform/${DOTFILES_PLATFORM}.zsh" ]] \
    && _dot_source "$DOTFILES_DIR/platform/${DOTFILES_PLATFORM}.zsh"

# 5. Autoloaded functions (lazy-loaded, zero startup cost)
fpath=("$DOTFILES_DIR/functions" $fpath)
autoload -Uz "$DOTFILES_DIR"/functions/*(N.:t)

# --- Profiling Summary ---
if [[ "$PROFILE_DOTFILES" == "true" ]]; then
    _total=$(printf "%.2f" $(( (EPOCHREALTIME - _DOT_START) * 1000 )))
    echo -e "\033[1;35m✨ Total: \033[1;36m${_total} ms\033[0m\n"
fi

# --- Cleanup ---
unset _f _DOT_START
unfunction _dot_source _path_add 2>/dev/null
