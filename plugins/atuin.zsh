# ============================================================================
# ATUIN SHELL HISTORY INTEGRATION (cached for instant startup)
# ============================================================================

# Skip interactive history hooks in non-interactive or dumb/AI terminals
if [[ ! -o interactive ]] || [[ "$TERM" == "dumb" ]]; then
    return 0 2>/dev/null || exit 0
fi

if [[ "$HAS_ATUIN" == "true" ]]; then
    if [[ -f "$DOTFILES_DIR/config/atuin.toml" ]]; then
        mkdir -p "$HOME/.config/atuin"
        if [[ ! -r "$HOME/.config/atuin/config.toml" ]] || ! cmp -s "$DOTFILES_DIR/config/atuin.toml" "$HOME/.config/atuin/config.toml"; then
            cp -f "$DOTFILES_DIR/config/atuin.toml" "$HOME/.config/atuin/config.toml" 2>/dev/null
        fi
    fi

    local _ATUIN_CACHE="$HOME/.cache/atuin_init.zsh"
    local _ATUIN_HASH=$(stat -c '%Y-%s' "${(%):-%x}" 2>/dev/null || stat -f '%m%z' "${(%):-%x}" 2>/dev/null)

    if [[ ! -f "$_ATUIN_CACHE" ]] || ! grep -q "#hash:$_ATUIN_HASH" "$_ATUIN_CACHE" 2>/dev/null; then
        (umask 077; atuin init zsh > "$_ATUIN_CACHE"; echo "#hash:$_ATUIN_HASH" >> "$_ATUIN_CACHE")
    fi
    source "$_ATUIN_CACHE"

    unset _ATUIN_CACHE _ATUIN_HASH
fi
