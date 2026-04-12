#!/usr/bin/env bash
# ============================================================================
# CLOUD & INFRASTRUCTURE UTILITIES (AWS, Terraform)
# ============================================================================

# --- AWS Related ---

# aws-who — Check current AWS identity (Account, Role, Profile)
unalias aws-who 2>/dev/null || true
function aws-who() {
    if [ "$HAS_AWS" != "true" ]; then
        echo "❌ AWS CLI not installed."
        return 1
    fi
    echo -e "\033[1;34m🔍 Checking AWS Identity...\033[0m"
    aws sts get-caller-identity
    echo -e "\033[1;33mProfile:\033[0m ${AWS_PROFILE:-default}"
    echo -e "\033[1;33mRegion: \033[0m $(aws configure get region 2>/dev/null || echo 'not set')"
}

# Add shorter alias for help menu compatibility
alias 'aws who'='aws-who'

# sso-login alias for convenience
alias 'aws login'='aws login' # This is already a command, but we mention it for help menu visibility

# --- Terraform Related ---
if [ "$HAS_TERRAFORM" = "true" ]; then
    alias tf='terraform'
fi
