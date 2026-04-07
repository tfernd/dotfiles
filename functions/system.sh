#!/usr/bin/env bash
# ============================================================================
# SYSTEM MONITORING & UTILITIES
# ============================================================================

# memhog — show top 15 memory-consuming processes
unalias memhog 2>/dev/null || true
function memhog() {
    if [ "$IS_MAC" = "true" ]; then
        ps -m -o user,pid,%cpu,%mem,vsz,rss,stat,comm | head -n 15
    elif [ "$IS_LINUX" = "true" ]; then
        ps axo user,pid,%cpu,%mem,vsz,rss,stat,comm --sort=-%mem | head -n 15
    else
        # Windows/Git Bash fallback
        ps | head -n 15
    fi
}

# top — smart wrapper for bottom (btm) or system top
unalias top 2>/dev/null || true
function top() {
    if command -v btm >/dev/null 2>&1; then
        command btm "$@"
    elif command -v top >/dev/null 2>&1; then
        command top "$@"
    else
        echo "❌ btm (bottom) and top not found. Install bottom or use memhog." >&2
        return 127
    fi
}

# sleep — cross-platform sleep with Python/Ping fallbacks
unalias sleep 2>/dev/null || true
function sleep() {
    local seconds="$1"
    if command -v sleep >/dev/null 2>&1; then
        command sleep "$seconds"
    elif command -v uv >/dev/null 2>&1; then
        uv run --no-project python -c "import time; time.sleep(float('$seconds'))"
    elif [ "$IS_WIN" = "true" ]; then
        ping -n $((${seconds%.*} + 1)) 127.0.0.1 > /dev/null
    fi
}

