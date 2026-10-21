# ============================================================================
# LINUX (DEBIAN) SPECIFIC
# ============================================================================
[[ -t 0 ]] && export GPG_TTY=$(tty)

# Do not sync mouse selection into CLIPBOARD. Leftover autocutsel from older
# dotfiles made every desktop/Chrome selection overwrite the clipboard.
if [[ -o interactive ]]; then
    if pgrep -u "$USER" -x autocutsel &>/dev/null; then
        pkill -u "$USER" -x autocutsel 2>/dev/null || true
    fi
fi
