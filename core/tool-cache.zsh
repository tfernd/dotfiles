# ============================================================================
# TOOL DETECTION (cached for fast startup)
# ============================================================================

function has_tool() { (( $+commands[$1] )) && echo true || echo false }
function has_any() {
    for t in "$@"; do (( $+commands[$t] )) && { echo true; return }; done
    echo false
}

local _cache="$HOME/.cache/dotfiles_tools"
local _cache_src="${(%):-%x}"
local _cache_hash="$(stat -c '%Y-%s' "$_cache_src" 2>/dev/null || stat -f '%m%z' "$_cache_src" 2>/dev/null):${OSTYPE}"

if [[ ! -f "$_cache" ]] || ! grep -q "#hash:$_cache_hash" "$_cache" 2>/dev/null; then
    mkdir -p "${_cache:h}"
    (umask 077; cat > "$_cache" <<EOF
export HAS_ZOXIDE=$(has_tool zoxide)
export HAS_EZA=$(has_tool eza)
export HAS_TRASH_PUT=$(has_tool trash-put)
export HAS_TRASH=$(has_any trash-put trash)
export HAS_RG=$(has_tool rg)
export HAS_GH=$(has_tool gh)
export HAS_JQ=$(has_tool jq)
export HAS_XH=$(has_tool xh)
export HAS_DELTA=$(has_tool delta)
export HAS_STARSHIP=$(has_tool starship)
export HAS_BAT=$(has_any bat batcat)
export HAS_BATCAT=$(has_tool batcat)
export HAS_YQ=$(has_tool yq)
export HAS_UV=$(has_tool uv)
export HAS_BUN=$(has_tool bun)
export HAS_ATUIN=$(has_tool atuin)
export HAS_FZF=$(has_tool fzf)
export HAS_ZELLIJ=$(has_tool zellij)
#hash:$_cache_hash
EOF
)
fi

source "$_cache"

# Rebuild cache and restart
alias refresh='rm -f "$HOME/.cache/dotfiles_tools" "$HOME/.cache/starship_init.zsh" "$HOME/.cache/atuin_init.zsh" "$HOME/.cache/zoxide_init.zsh" "$HOME/.cache/gh_completion.zsh" && exec zsh --login'
