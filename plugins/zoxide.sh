# --- Guard against multiple sourcing ---
if [ "$_ZOXIDE_LOADED" = "true" ]; then
    return
fi
_ZOXIDE_LOADED=true

if [ "$HAS_ZOXIDE" = "true" ]; then
    ZOXIDE_CACHE="$HOME/.cache/zoxide_init.$CURRENT_SHELL"
    
    # Re-calculate hash if not present in environment
    if [ -z "$BASHRC_HASH" ]; then
        if [ -n "$ZSH_VERSION" ]; then
            ZOXIDE_SRC="${(%):-%x}"
        else
            ZOXIDE_SRC="${BASH_SOURCE[0]}"
        fi
        ZOXIDE_HASH=$(stat -c '%Y-%s' "$ZOXIDE_SRC" 2>/dev/null || stat -f '%m%z' "$ZOXIDE_SRC" 2>/dev/null)
    else
        ZOXIDE_HASH="$BASHRC_HASH"
    fi

    if [ ! -f "$ZOXIDE_CACHE" ] || ! grep -q "#hash:$ZOXIDE_HASH" "$ZOXIDE_CACHE" 2>/dev/null; then
        zoxide init "$CURRENT_SHELL" > "$ZOXIDE_CACHE"
        echo "#hash:$ZOXIDE_HASH" >> "$ZOXIDE_CACHE"
    fi
    source "$ZOXIDE_CACHE"
    
    # Alias cd to z for smart jumping
    cd() { z "$@" 2>/dev/null || builtin cd "$@"; }
fi
