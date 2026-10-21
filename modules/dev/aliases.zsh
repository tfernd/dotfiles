# ============================================================================
# DEVELOPMENT ALIASES
# ============================================================================

# --- HTTP Client ---
[[ "$HAS_XH" == "true" ]] && alias http='xh'

# --- JSON Pretty-Printer ---
if [[ "$HAS_JQ" == "true" ]]; then
    alias json='jq'
elif [[ "$HAS_UV" == "true" ]]; then
    alias json='uv run --no-project python -m json.tool'
else
    function json() {
        echo "❌ 'jq' or 'uv' required for JSON processing."
        return 1
    }
fi
