# ============================================================================
# WSL2 SPECIFIC
# ============================================================================
[[ -t 0 ]] && export GPG_TTY=$(tty)

# Windows interop paths go LAST: lookups on /mnt/c are slow, and Linux tools must win
[[ -d "/mnt/c/Windows/System32" ]] && path+=("/mnt/c/Windows/System32")
