#!/usr/bin/env bash
# ============================================================================
# DEVELOPMENT UTILITY FUNCTIONS
# ============================================================================

# pyclean — remove Python cache and temporary files
unalias pyclean 2>/dev/null || true
function pyclean() {
    find . -depth \( \
        -type f -name "*.py[co]"      -o \
        -type f -name ".coverage"     -o \
        -type d -name "__pycache__"   -o \
        -type d -name ".pytest_cache" -o \
        -type d -name ".mypy_cache"   -o \
        -type d -name ".ruff_cache"   -o \
        -type d -name "*.egg-info"    -o \
        -type d -name "htmlcov" \
    \) -delete 2>/dev/null
    echo "🧹 Cleaned Python cache and temp files."
}

# envup — load variables from .env file into current session
unalias envup 2>/dev/null || true
function envup() {
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        echo -e "📝 \033[1;33mUsage:\033[0m envup [file (default: .env)]"
        return 0
    fi
    local envfile="${1:-.env}"
    if [ ! -f "$envfile" ]; then
        echo "❌ No $envfile file found."
        return 1
    fi
    # set -a auto-exports every variable; source handles quoting and comments.
    set -a
    source "$envfile"
    set +a
    echo "✅ Loaded $envfile variables into current session."
}
