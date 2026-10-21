# ============================================================================
# GITHUB CLI ALIASES (requires gh)
# ============================================================================

if [[ "$HAS_GH" == "true" ]]; then
    alias pr='gh pr create --web'
    alias prs='gh pr list'
    alias ghv='gh repo view --web'
fi
