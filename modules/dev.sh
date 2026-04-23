#!/usr/bin/env bash
# ============================================================================
# DEVELOPMENT UTILITY FUNCTIONS
# ============================================================================

# --- AI Bun/UV Enforcement Guards (loaded in ALL modes) ---
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

# ============================================================================
# INTERACTIVE-ONLY BELOW
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
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        # Only process lines matching KEY=VALUE (key must be valid identifier)
        if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*(.*) ]]; then
            local key="${BASH_REMATCH[1]}"
            local val="${BASH_REMATCH[2]}"
            # Strip surrounding quotes (single or double)
            if [[ "$val" =~ ^\"(.*)\"$ ]] || [[ "$val" =~ ^\'(.*)\'$ ]]; then
                val="${BASH_REMATCH[1]}"
            fi
            export "$key=$val"
            ((count++))
        fi
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