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
if [ "$CURRENT_SHELL" = "zsh" ] && [ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then
    export ZSH="$HOME/.oh-my-zsh"
    # Suppress "insecure directories" warning on WSL mounted filesystems
    export ZSH_DISABLE_COMPFIX=true
    plugins=(git)
    source "$ZSH/oh-my-zsh.sh"

    # OMZ already runs compinit; configure completion style
    zstyle ':completion:*' menu select
elif [ "$CURRENT_SHELL" = "zsh" ]; then
    # No OMZ — run compinit manually so completions still work
    autoload -Uz compinit && compinit -C
    zstyle ':completion:*' menu select
fi

# --- Zsh Plugins (work with or without OMZ) ---
if [ "$CURRENT_SHELL" = "zsh" ]; then
    # Optimized Zsh plugin discovery (first match wins)
    for _p in zsh-autosuggestions zsh-syntax-highlighting; do
        for _d in /usr/share /opt/homebrew/share /usr/local/share /home/linuxbrew/.linuxbrew/share; do
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
    # Self-heal: if starship config is missing or broken (e.g. stale symlink),
    # re-deploy it from the dotfiles source.
    if [ ! -r "$HOME/.config/starship.toml" ] && [ -f "$DOTFILES_DIR/starship.toml" ]; then
        mkdir -p "$HOME/.config"
        rm -f "$HOME/.config/starship.toml" 2>/dev/null
        cp -f "$DOTFILES_DIR/starship.toml" "$HOME/.config/starship.toml" 2>/dev/null
    fi

    _STAR_CACHE="$HOME/.cache/starship_init.$CURRENT_SHELL"
    # Use global hash if available, else derive from source
    _STAR_TOML_HASH=$(stat -c '%Y-%s' "$HOME/.config/starship.toml" 2>/dev/null || stat -f '%m%z' "$HOME/.config/starship.toml" 2>/dev/null || echo "none")
    _S_HASH="${BASHRC_HASH:-$(stat -c '%Y-%s' "${(%):-%x}" 2>/dev/null || stat -f '%m%z' "${BASH_SOURCE[0]}" 2>/dev/null)}:${_STAR_TOML_HASH}"

    if [ ! -f "$_STAR_CACHE" ] || ! grep -q "#hash:$_S_HASH" "$_STAR_CACHE" 2>/dev/null; then
        starship init "$CURRENT_SHELL" > "$_STAR_CACHE"
        echo "#hash:$_S_HASH" >> "$_STAR_CACHE"
    fi
    [ -n "$ZSH_VERSION" ] && setopt prompt_subst
    source "$_STAR_CACHE"
fi

# Cleanup
unset _p _d _GH_CACHE _STAR_CACHE _S_HASH _STAR_TOML_HASH
