# ============================================================================
# WSL2 SPECIFIC
# ============================================================================
export GPG_TTY=$(tty)

# Ensure Windows interop paths are available
_path_add "/mnt/c/Windows/System32"
