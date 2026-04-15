#!/usr/bin/env bash
# ============================================================================
# DEVELOPMENT UTILITY FUNCTIONS
# ============================================================================

# pyclean — remove Python cache and temporary files
unalias pyclean 2>/dev/null || true
function pyclean() {
    find . -depth \( \
        -type f -name "*.pyc"         -o \
        -type f -name "*.pyo"         -o \
        -type f -name ".coverage"     -o \
        -type d -name "__pycache__"   -o \
        -type d -name ".pytest_cache" -o \
        -type d -name ".mypy_cache"   -o \
        -type d -name ".ruff_cache"   -o \
        -type d -name ".ipynb_checkpoints" -o \
        -type d -name "*.egg-info"    -o \
        -type d -name ".eggs"         -o \
        -type d -name ".tox"          -o \
        -type d -name ".nox"          -o \
        -type d -name "build"         -o \
        -type d -name "dist"          -o \
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

# --- Development & Data Aliases ---

# --- JSON/YAML Processing ---
if [ "$IS_WIN" = "true" ]; then
    [ "$HAS_JQ" = "true" ] && alias jq='MSYS2_ARG_CONV_EXCL="*" jq'
    [ "$HAS_YQ" = "true" ] && alias yq='MSYS2_ARG_CONV_EXCL="*" yq'
fi

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

# calc — Command line calculator using bc.
unalias calc 2>/dev/null || true
function calc() {
    if ! command -v bc >/dev/null 2>&1; then
        echo "❌ 'bc' calculator not found. Please install it."
        return 1
    fi
    echo "$*" | bc -l
}

# --- AI Bun/UV Enforcement Guards ---
function _ai_warn() { echo -e "\033[1;33m🤖 AI: Use '$1' instead of '$2'.\033[0m" >&2; }

# --- JS/TS Enforcement Guards (Pro-Bun) ---
if [ "$HAS_BUN" = "true" ]; then
    unalias node npm npx yarn pnpm nodemon ts-node tsx 2>/dev/null || true
    alias node='_ai_warn "bun run" "node"'
    alias npm='_ai_warn "bun" "npm"'
    alias npx='_ai_warn "bun x" "npx"'
    alias yarn='_ai_warn "bun" "yarn"'
    alias pnpm='_ai_warn "bun" "pnpm"'
    alias nodemon='_ai_warn "bun --watch" "nodemon"'
    alias ts-node='_ai_warn "bun" "ts-node"'
    alias tsx='_ai_warn "bun" "tsx"'
fi

# --- Python Enforcement Guards (Pro-UV) ---
if [ "$HAS_UV" = "true" ]; then
    unalias python python3 pip pip3 venv poetry 2>/dev/null || true
    alias python='_ai_warn "uv run" "python"'
    alias pip='_ai_warn "uv" "pip"'
    alias venv='_ai_warn "uv venv" "venv"'
    alias poetry='_ai_warn "uv" "poetry"'
    alias python3='python'
    alias pip3='pip'
fi