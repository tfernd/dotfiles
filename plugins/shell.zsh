# ============================================================================
# OH MY ZSH + STARSHIP PROMPT
# ============================================================================

# Fast-path: bypass prompts, colors, and UI plugins in agent / non-interactive shells
if [[ "$IS_AGENT" == "true" ]]; then
    PROMPT='%# '
    return 0 2>/dev/null || exit 0
fi

# --- Oh My Zsh ---
if [[ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]]; then
    export ZSH="$HOME/.oh-my-zsh"
    export ZSH_DISABLE_COMPFIX=true
    export DISABLE_MAGIC_FUNCTIONS=true

    # Plugins — add what you use
    plugins=(
        zsh-autosuggestions
        zsh-syntax-highlighting
    )

    source "$ZSH/oh-my-zsh.sh"
else
    # Fallback: standalone completions + plugins if OMZ not installed
    autoload -Uz compinit && compinit -C
    zstyle ':completion:*' menu select

    for _p in zsh-autosuggestions zsh-syntax-highlighting; do
        for _d in /usr/share /opt/homebrew/share /usr/local/share /home/linuxbrew/.linuxbrew/share; do
            if [[ -f "$_d/$_p/$_p.zsh" ]]; then
                source "$_d/$_p/$_p.zsh"
                break
            fi
        done
    done
    unset _p _d
fi

# --- GitHub CLI completions (cached) ---
if [[ "$HAS_GH" == "true" ]]; then
    local _GH_CACHE="$HOME/.cache/gh_completion.zsh"
    if [[ ! -f "$_GH_CACHE" ]] || [[ "$(command -v gh)" -nt "$_GH_CACHE" ]]; then
        (umask 077; gh completion -s zsh > "$_GH_CACHE" 2>/dev/null)
    fi
    [[ -f "$_GH_CACHE" ]] && source "$_GH_CACHE"
fi

# --- Starship Prompt (overrides OMZ theme) ---
if [[ "$HAS_STARSHIP" == "true" ]]; then
    if [[ -f "$DOTFILES_DIR/config/starship.toml" ]]; then
        mkdir -p "$HOME/.config"
        if [[ ! -r "$HOME/.config/starship.toml" ]] || ! cmp -s "$DOTFILES_DIR/config/starship.toml" "$HOME/.config/starship.toml"; then
            if [[ -r "$HOME/.config/starship.toml" ]]; then
                cp -f "$HOME/.config/starship.toml" "$HOME/.config/starship.toml.bak" 2>/dev/null &&
                    print -r -- "⚠️  ~/.config/starship.toml differed from the repo copy: replaced it, old one kept as starship.toml.bak"
            fi
            cp -f "$DOTFILES_DIR/config/starship.toml" "$HOME/.config/starship.toml" 2>/dev/null
        fi
    fi

    local _STAR_CACHE="$HOME/.cache/starship_init.zsh"
    local _STAR_TOML_HASH=$(stat -c '%Y-%s' "$HOME/.config/starship.toml" 2>/dev/null || stat -f '%m%z' "$HOME/.config/starship.toml" 2>/dev/null || echo "none")
    local _S_HASH="${_STAR_TOML_HASH}"

    if [[ ! -f "$_STAR_CACHE" ]] || ! grep -q "#hash:$_S_HASH" "$_STAR_CACHE" 2>/dev/null; then
        (umask 077; starship init zsh > "$_STAR_CACHE"; echo "#hash:$_S_HASH" >> "$_STAR_CACHE")
    fi
    setopt prompt_subst
    source "$_STAR_CACHE"
fi

unset _GH_CACHE _STAR_CACHE _S_HASH _STAR_TOML_HASH
