# ============================================================================
# ZOXIDE SMART JUMP (CD) INTEGRATION
# ============================================================================

if [[ "$HAS_ZOXIDE" == "true" ]]; then
    local _ZOX_CACHE="$HOME/.cache/zoxide_init.zsh"
    local _ZOX_HASH=$(stat -c '%Y-%s' "${(%):-%x}" 2>/dev/null || stat -f '%m%z' "${(%):-%x}" 2>/dev/null)

    if [[ ! -f "$_ZOX_CACHE" ]] || ! grep -q "#hash:$_ZOX_HASH" "$_ZOX_CACHE" 2>/dev/null; then
        (umask 077; zoxide init zsh > "$_ZOX_CACHE"; echo "#hash:$_ZOX_HASH" >> "$_ZOX_CACHE")
    fi
    source "$_ZOX_CACHE"

    if (( $+functions[z] )); then
        cd() {
            if (( $# == 0 )) || [[ "$1" == "-" || "$1" == ".." || -d "$1" ]]; then
                builtin cd "$@"
            else
                z "$@" || builtin cd "$@"
            fi
        }
    fi

    unset _ZOX_CACHE _ZOX_HASH
fi
