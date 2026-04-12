#!/usr/bin/env bash
# ============================================================================
# INTERACTIVE SHELL INTERFACE (UI/UX)
# ============================================================================

# --- Shell Interface Guard ---
# Prevents re-initializing expensive prompt engines when re-sourcing the shell.
if [ "$_PROMPT_LOADED" = "true" ]; then
    return
fi
_PROMPT_LOADED=true

# --- Zsh (Oh My Zsh) Integration ---
# Bootstraps the Zsh framework and its core plugin ecosystem.
if [ "$CURRENT_SHELL" = "zsh" ] && [ -d "$HOME/.oh-my-zsh" ]; then
    export ZSH="$HOME/.oh-my-zsh"
    plugins=(git python pip)
    source "$ZSH/oh-my-zsh.sh"

    # OMZ already runs compinit; configure completion style
    zstyle ':completion:*' menu select

    # Optimized Zsh plugin discovery (first match wins)
    for _p in zsh-autosuggestions zsh-syntax-highlighting; do
        for _d in /usr/share /opt/homebrew/share /usr/local/share; do
            if [ -f "$_d/$_p/$_p.zsh" ]; then
                source "$_d/$_p/$_p.zsh"
                break
            fi
        done
    done

    # --- Cache GitHub CLI completions ---
    if [ "$HAS_GH" = "true" ]; then
        _GH_CACHE="$HOME/.cache/gh_completion.zsh"
        # Regenerate only if cache missing or gh binary is newer
        if [ ! -f "$_GH_CACHE" ] || [ "$(command -v gh)" -nt "$_GH_CACHE" ]; then
            gh completion -s zsh > "$_GH_CACHE" 2>/dev/null
        fi
        [ -f "$_GH_CACHE" ] && source "$_GH_CACHE"
    fi
fi

# --- Starship Prompt ---
if [ "$HAS_STARSHIP" = "true" ]; then
    _STAR_CACHE="$HOME/.cache/starship_init.$CURRENT_SHELL"
    # Use global hash if available, else derive from source
    _S_HASH="${BASHRC_HASH:-$(stat -c '%Y-%s' "${(%):-%x}" 2>/dev/null || stat -f '%m%z' "${BASH_SOURCE[0]}" 2>/dev/null)}"

    if [ ! -f "$_STAR_CACHE" ] || ! grep -q "#hash:$_S_HASH" "$_STAR_CACHE" 2>/dev/null; then
        starship init "$CURRENT_SHELL" > "$_STAR_CACHE"
        echo "#hash:$_S_HASH" >> "$_STAR_CACHE"
    fi
    [ -n "$ZSH_VERSION" ] && setopt prompt_subst
    source "$_STAR_CACHE"
fi

# Cleanup
unset _p _d _GH_CACHE _STAR_CACHE _S_HASH
