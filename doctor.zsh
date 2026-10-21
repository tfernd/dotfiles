#!/usr/bin/env zsh
# ============================================================================
# 🩺 DOTFILES DOCTOR — post-install health check
# ============================================================================
# Verifies that every tool the dotfiles promise is actually installed AND
# wired into the shell (PATH + HAS_* flags + aliases/functions).
#
# Usage:
#   zsh doctor.zsh          # human report, exits non-zero if anything required is missing
#   zsh doctor.zsh --quiet  # only print failures + summary
#
# Exit codes:
#   0  all required checks passed
#   1  one or more required checks failed
# ============================================================================

# Load the actual dotfiles environment (PATH, HAS_* flags, aliases, functions)
SCRIPT_DIR="${${(%):-%x}:A:h}"
if [[ -f "$SCRIPT_DIR/core/init.zsh" ]]; then
    source "$SCRIPT_DIR/core/init.zsh"
else
    echo "❌ Could not find core/init.zsh next to doctor.zsh ($SCRIPT_DIR)"
    exit 1
fi

QUIET=false
[[ "${1:-}" == "--quiet" ]] && QUIET=true

# --- Colors ---
C_RED=$'\033[1;31m'; C_GRN=$'\033[1;32m'; C_YEL=$'\033[1;33m'
C_CYN=$'\033[1;36m'; C_DIM=$'\033[38;5;244m'; C_RST=$'\033[0m'

FAILS=0
WARNS=0

_ok()   { [[ "$QUIET" == true ]] || printf "  ${C_GRN}✓${C_RST} %-14s ${C_DIM}%s${C_RST}\n" "$1" "$2"; }
_fail() { printf "  ${C_RED}✗${C_RST} %-14s ${C_RED}%s${C_RST}\n" "$1" "$2"; (( FAILS++ )); }
_warn() { [[ "$QUIET" == true ]] || printf "  ${C_YEL}!${C_RST} %-14s ${C_YEL}%s${C_RST}\n" "$1" "$2"; (( WARNS++ )); }

# Require a command on PATH.
require_cmd() {
    local name="$1"
    if (( $+commands[$name] )); then
        _ok "$name" "$commands[$name]"
    else
        _fail "$name" "MISSING (not on PATH)"
    fi
}

# Require at least one of several commands (e.g. bat vs batcat).
require_any() {
    local label="$1"; shift
    local t
    for t in "$@"; do
        if (( $+commands[$t] )); then _ok "$label" "$commands[$t]"; return; fi
    done
    _fail "$label" "MISSING (none of: $*)"
}

# Optional command — warn only.
optional_cmd() {
    local name="$1"
    if (( $+commands[$name] )); then _ok "$name" "$commands[$name]"; else _warn "$name" "not installed (optional)"; fi
}

# Require a shell integration to exist (alias, function, or command).
require_shell() {
    local name="$1" desc="$2"
    local kind="${$(whence -w "$name" 2>/dev/null)##*: }"
    if [[ -n "$kind" && "$kind" != "none" ]]; then
        _ok "$name" "$kind${desc:+  ($desc)}"
    else
        _fail "$name" "NOT DEFINED${desc:+  ($desc)}"
    fi
}

# Require a HAS_* flag to be true.
require_flag() {
    local var="$1"
    if [[ "${(P)var}" == "true" ]]; then
        _ok "$var" "true"
    else
        _fail "$var" "is '${(P)var}' (expected true)"
    fi
}

echo -e "\n${C_CYN}=================================================================${C_RST}"
echo -e "${C_CYN}  🩺 DOTFILES DOCTOR${C_RST}   platform: ${C_YEL}${DOTFILES_PLATFORM:-unknown}${C_RST}"
echo -e "${C_CYN}=================================================================${C_RST}"

# ---------------------------------------------------------------------------
echo -e "\n${C_CYN}▸ Core CLI tools${C_RST}"
for t in git gh uv starship zoxide atuin zellij eza rg yq xh jq bun; do
    require_cmd "$t"
done
require_any "bat"   bat batcat
require_any "delta" delta git-delta
require_cmd fzf

# ---------------------------------------------------------------------------
echo -e "\n${C_CYN}▸ Trash (safe rm)${C_RST}"
for t in trash-put trash-list trash-restore trash-empty; do
    require_cmd "$t"
done

# ---------------------------------------------------------------------------
echo -e "\n${C_CYN}▸ Archive tools${C_RST}"
require_any "7z" 7z 7za 7zz
for t in zip unzip tar xz zstd; do
    require_cmd "$t"
done
require_any "rar-extract" unar unrar

# ---------------------------------------------------------------------------
echo -e "\n${C_CYN}▸ Clipboard${C_RST}"
case "$DOTFILES_PLATFORM" in
    macos) require_cmd pbcopy ;;
    wsl)   require_any "clipboard" clip.exe xclip ;;
    *)     require_any "clipboard" xclip wl-copy xsel ;;
esac

# ---------------------------------------------------------------------------
echo -e "\n${C_CYN}▸ Feature flags (tool-cache)${C_RST}"
for f in HAS_ZOXIDE HAS_EZA HAS_BAT HAS_RG HAS_GH HAS_JQ HAS_XH HAS_DELTA \
         HAS_STARSHIP HAS_YQ HAS_UV HAS_BUN HAS_ATUIN HAS_FZF HAS_ZELLIJ \
         HAS_TRASH HAS_TRASH_PUT; do
    require_flag "$f"
done

# ---------------------------------------------------------------------------
echo -e "\n${C_CYN}▸ Shell integration${C_RST}"
require_shell ls          "eza listing"
require_shell cat         "bat viewer"
require_shell rl          "trash list"
require_shell rt          "trash restore"
require_shell empty-trash "empty trash"
require_shell copy        "clipboard"
require_shell http        "xh client"
require_shell zj          "zellij"
require_shell pr          "gh pr create"

# ---------------------------------------------------------------------------
echo -e "\n${C_CYN}=================================================================${C_RST}"
if (( FAILS == 0 )); then
    echo -e "${C_GRN}  ✅ All required checks passed${C_RST}${WARNS:+  ${C_YEL}(${WARNS} warning(s))${C_RST}}"
    echo -e "${C_CYN}=================================================================${C_RST}\n"
    exit 0
else
    echo -e "${C_RED}  ❌ ${FAILS} required check(s) FAILED${C_RST}${WARNS:+  ${C_YEL}(${WARNS} warning(s))${C_RST}}"
    echo -e "${C_DIM}  Fix: install the missing tool(s) or re-run install.sh, then reload with 'refresh'.${C_RST}"
    echo -e "${C_CYN}=================================================================${C_RST}\n"
    exit 1
fi
