# ============================================================================
# PROCESS MONITORING
# ============================================================================

function sleep() {
    local seconds="$1"
    if (( $+commands[sleep] )); then
        command sleep "$seconds"
    elif [[ "$HAS_UV" == "true" ]]; then
        uv run --no-project python -c "import time; time.sleep(float('$seconds'))"
    fi
}

# Revoke / drop cached sudo credentials immediately
alias sudok='sudo -k && echo "🔒 Sudo credentials revoked."'
