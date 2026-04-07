#!/usr/bin/env bash
# ============================================================================
# LINUX SPECIFIC OVERRIDES & TWEAKS
# ============================================================================

# Ensure GPG TTY is set for commit signing
export GPG_TTY=$(tty)

# Linux-specific LS colors (if not using eza)
if [ "$HAS_EZA" != "true" ]; then
    alias ls='ls --color=auto --group-directories-first'
fi

