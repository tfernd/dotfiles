#!/usr/bin/env bash
# ============================================================================
# DEVELOPMENT & DATA ALIASES
# ============================================================================

# --- JSON/YAML Processing ---
if [ "$IS_WIN" = "true" ]; then
    [ "$HAS_JQ" = "true" ] && alias jq='MSYS2_ARG_CONV_EXCL="*" jq'
    [ "$HAS_YQ" = "true" ] && alias yq='MSYS2_ARG_CONV_EXCL="*" yq'
fi

# --- HTTP Client ---
[ "$HAS_XH" = "true" ]  && alias 'http'='xh'


# --- AI Bun/UV Enforcement Guards ---
unalias node npm npx python python3 pip pip3 2>/dev/null || true
function _ai_warn() { echo -e "\033[1;33m🤖 AI: Use '$1' instead of '$2'.\033[0m" >&2; }

function node()   { _ai_warn "bun run" "node"; }
function npm()    { _ai_warn "bun" "npm"; }
function npx()    { _ai_warn "bun x" "npx"; }
function python() { _ai_warn "uv run" "python"; }
function pip()    { _ai_warn "uv" "pip"; }

alias python3='python'
alias pip3='pip'
