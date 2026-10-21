#!/usr/bin/env bash
# ============================================================================
# DEVELOPMENT UTILITY FUNCTIONS
# ============================================================================

# pyclean — remove Python cache and temporary files
unalias pyclean 2>/dev/null || true
function pyclean() {
    # Skip VCS/env/vendor trees; remove whole cache dirs (find -delete can't remove non-empty dirs)
    find . \( -name .git -o -name .venv -o -name venv -o -name node_modules \) -prune -o \
        -type d \( \
            -name "__pycache__"   -o \
            -name ".pytest_cache" -o \
            -name ".mypy_cache"   -o \
            -name ".ruff_cache"   -o \
            -name ".ipynb_checkpoints" -o \
            -name "*.egg-info"    -o \
            -name ".eggs"         -o \
            -name ".tox"          -o \
            -name ".nox"          -o \
            -name "htmlcov" \
        \) -prune -exec rm -rf {} + -o \
        -type f \( -name "*.pyc" -o -name "*.pyo" -o -name ".coverage" \) -exec rm -f {} + 2>/dev/null

    # build/ and dist/ are generic names: only remove them at the root of a Python project
    if [ -f pyproject.toml ] || [ -f setup.py ] || [ -f setup.cfg ]; then
        command rm -rf ./build ./dist
    fi
    echo "🧹 Cleaned Python cache and temp files."
}

# envup — load variables from .env file into current session
# SECURITY: Parses KEY=VALUE lines only. Does NOT source the file as shell code.
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
    local count=0
    local line key val
    # Plain parameter expansion (no regex captures): BASH_REMATCH doesn't exist in zsh
    while IFS= read -r line || [ -n "$line" ]; do
        # Trim leading whitespace; skip empty lines, comments and non-assignments
        line="${line#"${line%%[![:space:]]*}"}"
        [[ -z "$line" || "$line" == \#* || "$line" != *=* ]] && continue
        key="${line%%=*}"
        key="${key%"${key##*[![:space:]]}"}"
        val="${line#*=}"
        val="${val#"${val%%[![:space:]]*}"}"
        # Key must be a valid identifier
        [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
        # Strip surrounding quotes (single or double)
        if [[ ${#val} -ge 2 && ( ( "$val" == \"*\" ) || ( "$val" == \'*\' ) ) ]]; then
            val="${val#?}"
            val="${val%?}"
        fi
        export "$key=$val"
        count=$((count + 1))
    done < "$envfile"
    echo "✅ Loaded $count variables from $envfile"
}

# --- Development & Data Aliases ---

# --- HTTP Client ---
[ "$HAS_XH" = "true" ]  && alias 'http'='xh'

# --- Aliases & Functions ---
alias grep='grep --color=auto'

# json — Pretty-print JSON from stdin or file.
if [ "$HAS_JQ" = "true" ]; then
    alias json='jq'
elif [ "$HAS_UV" = "true" ]; then
    alias json='uv run --no-project python -m json.tool'
else
    function json() {
        echo "❌ 'jq' or 'uv' required for JSON processing. Run 'setup-terminal' to install."
        return 1
    }
fi

# server — Start a fast Python HTTP server.
unalias server 2>/dev/null || true
function server() {
    local port="${1:-8000}"
    if [ "$HAS_UV" = "true" ]; then
        echo "🌍 Starting server on http://localhost:$port"
        uv run --no-project python -m http.server "$port"
    else
        echo "❌ 'uv' or 'python3' required for server. Run 'setup-terminal' to install."
        return 1
    fi
}

# calc — Command line calculator (bc with awk fallback)
# SECURITY: Input is validated to prevent code injection via awk.
unalias calc 2>/dev/null || true
function calc() {
    local expr="$*"
    # Validate: only allow numbers, math operators, whitespace, decimal points, parens
    if [[ "$expr" =~ [^0-9\ +\-\*/\.\(\)%\^] ]]; then
        echo "❌ Invalid characters in expression. Only numbers and math operators allowed." >&2
        return 1
    fi
    if command -v bc >/dev/null 2>&1; then
        echo "$expr" | bc -l
    else
        awk "BEGIN { print $expr }"
    fi
}
[ -n "$ZSH_VERSION" ] && alias calc='noglob calc'

# uv-upgrade — Upgrade all UV-managed global tools
unalias uv-upgrade 2>/dev/null || true
function uv-upgrade() {
    ssh-add -l &>/dev/null || ssh-login
    uv run --no-project "$DOTFILES_DIR/scripts/uv-upgrade.py"
}