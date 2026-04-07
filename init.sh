#!/usr/bin/env bash
# ============================================================================
# 🚀 THE DOTFILES MASTER LOADER
# ============================================================================
# Symlink this to ~/.dotfiles and source it from your ~/.zshrc or ~/.bashrc:
# [ -f ~/.dotfiles/init.sh ] && source ~/.dotfiles/init.sh
# ============================================================================

# Detect directory where this script resides
if [ -n "$ZSH_VERSION" ]; then
    DOTFILES_DIR="${${(%):-%x}:A:h}"
    [ "$PROFILE_DOTFILES" = "true" ] && zmodload zsh/datetime
else
    # Fallback for Bash
    DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
fi

# --- Shell Optimization & Deduplication ---
# Purge inherited include guards from environment (breaks inheritance cycle)
unset _PATHS_LOADED _ZOXIDE_LOADED _PROMPT_LOADED 2>/dev/null

if [ -n "$ZSH_VERSION" ]; then
    # Prevent duplicate entries in hook arrays
    typeset -gU path fpath cdpath
    
    # Deduplicate hook arrays if they exist
    [ -n "${precmd_functions+1}" ] && precmd_functions=(${(u)precmd_functions})
    [ -n "${chpwd_functions+1}" ] && chpwd_functions=(${(u)chpwd_functions})
    [ -n "${preexec_functions+1}" ] && preexec_functions=(${(u)preexec_functions})
fi

# --- Profiling Helper ---
_DOT_START_TIME=0
[ -n "$ZSH_VERSION" ] && _DOT_START_TIME=$EPOCHREALTIME || _DOT_START_TIME=$(date +%s%3N)

function source_timed() {
    local file="$1"
    local start=0
    local end=0
    local elapsed=0

    if [ "$PROFILE_DOTFILES" = "true" ]; then
        [ -n "$ZSH_VERSION" ] && start=$EPOCHREALTIME || start=$(date +%s%3N)
        source "$file"
        [ -n "$ZSH_VERSION" ] && end=$EPOCHREALTIME || end=$(date +%s%3N)
        
        if [ -n "$ZSH_VERSION" ]; then
            elapsed=$(printf "%.2f" $(( (end - start) * 1000 )))
        else
            elapsed=$(( end - start ))
        fi
        printf "  \033[38;5;244m- %-25s\033[0m \033[1;32m%7s ms\033[0m\n" "$(basename "$file")" "$elapsed"
    else
        source "$file"
    fi
}

[ "$PROFILE_DOTFILES" = "true" ] && echo -e "\n\033[1;35m🚀 Profiling Dotfiles Startup...\033[0m"

# 1. Load Base Environment
for module in path-utils.sh os-detect.sh history.sh paths.sh; do
    [ -f "$DOTFILES_DIR/env/$module" ] && source_timed "$DOTFILES_DIR/env/$module"
done

# 2. Load Tool Cache & Core Plugins
for module in tool-cache.sh zoxide.sh prompt.sh; do
    [ -f "$DOTFILES_DIR/plugins/$module" ] && source_timed "$DOTFILES_DIR/plugins/$module"
done

# 3. Load Functions & Aliases
if [ -n "$ZSH_VERSION" ]; then setopt local_options NULL_GLOB; else shopt -s nullglob; fi

for file in "$DOTFILES_DIR/functions/"*.sh; do 
    source_timed "$file"
done
for file in "$DOTFILES_DIR/aliases/"*.sh; do 
    source_timed "$file"
done

[ -z "$ZSH_VERSION" ] && shopt -u nullglob

# 4. Load OS-Specific Quirks Overrides
[ "$IS_MAC" = "true" ] && [ -f "$DOTFILES_DIR/platform/macos.sh" ] && source_timed "$DOTFILES_DIR/platform/macos.sh"
[ "$IS_LINUX" = "true" ] && [ -f "$DOTFILES_DIR/platform/linux.sh" ] && source_timed "$DOTFILES_DIR/platform/linux.sh"
[ "$IS_WIN" = "true" ] && [ -f "$DOTFILES_DIR/platform/windows.sh" ] && source_timed "$DOTFILES_DIR/platform/windows.sh"

if [ "$PROFILE_DOTFILES" = "true" ]; then
    _DOT_END_TIME=0
    [ -n "$ZSH_VERSION" ] && _DOT_END_TIME=$EPOCHREALTIME || _DOT_END_TIME=$(date +%s%3N)
    
    if [ -n "$ZSH_VERSION" ]; then
        _TOTAL_MS=$(printf "%.2f" $(( (_DOT_END_TIME - _DOT_START_TIME) * 1000 )))
    else
        _TOTAL_MS=$(( _DOT_END_TIME - _DOT_START_TIME ))
    fi
    echo -e "\033[1;35m✨ Total Dotfiles Load Time: \033[1;36m$_TOTAL_MS ms\033[0m\n"
fi
