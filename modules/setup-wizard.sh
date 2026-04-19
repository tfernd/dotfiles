#!/usr/bin/env bash
# ============================================================================
# GIT & SSH SETUP WIZARD
# ============================================================================
# Interactive commands to configure git identity and SSH keys on new machines.
#
#   git-setup   — Set git user.name + user.email globally
#   ssh-setup   — Generate ed25519 key, add to agent, test connection
#   ssh-login   — Start ssh-agent + add default key (daily use)
#   ssh-test    — Test SSH connection to GitHub (+ enterprise if detected)
# ============================================================================

# --- Detect Enterprise GitHub Host ---
# Checks both url insteadOf rewrites AND credential helper entries.
_detect_gh_enterprise() {
    local host=""

    # Method 1: Credential helper entries (most reliable)
    # git config flattens [credential "https://HOST"] helper = ... into
    # credential.https://HOST.helper — extract HOST before .helper
    host=$(git config --global --get-regexp '^credential\.https://.*\.helper$' 2>/dev/null \
        | while read -r key _value; do
            local h
            h=$(echo "$key" | sed -E 's|^credential\.https://([^/]+)\.helper$|\1|')
            if [ -n "$h" ] && [ "$h" != "github.com" ] && [ "$h" != "gist.github.com" ] \
               && echo "$h" | grep -qi 'github'; then
                echo "$h"
                break
            fi
        done)

    # Method 2: URL rewrite rules — extract host from the insteadOf value
    # (the value side is a clean URL, unlike the key which gets mangled)
    if [ -z "$host" ]; then
        host=$(git config --global --get-regexp '^url\..*\.insteadof$' 2>/dev/null \
            | while read -r _key value; do
                local h
                h=$(echo "$value" | sed -E 's|^https?://([^/]+)/?.*|\1|')
                if [ -n "$h" ] && [ "$h" != "github.com" ] && echo "$h" | grep -qi 'github'; then
                    echo "$h"
                    break
                fi
            done)
    fi

    # Method 3: Infer from git user.email domain (e.g. user@disney.com -> github.disney.com)
    if [ -z "$host" ]; then
        local email_domain
        email_domain=$(git config --global user.email 2>/dev/null | sed -E 's|.*@||')
        if [ -n "$email_domain" ] && [ "$email_domain" != "gmail.com" ] \
           && [ "$email_domain" != "outlook.com" ] && [ "$email_domain" != "hotmail.com" ]; then
            local candidate="github.${email_domain}"
            # Only return if we can resolve it (quick DNS check)
            if command -v host >/dev/null 2>&1 && host "$candidate" >/dev/null 2>&1; then
                host="$candidate"
            elif command -v nslookup >/dev/null 2>&1 && nslookup "$candidate" >/dev/null 2>&1; then
                host="$candidate"
            fi
        fi
    fi

    # Return only if it's not plain github.com
    if [ -n "$host" ] && [ "$host" != "github.com" ]; then
        echo "$host"
    fi
}

# --- SSH Config Helper ---
# Adds a Host entry to ~/.ssh/config if not already present.
_ssh_configure_host() {
    local host="$1"
    local key_path="$2"
    local ssh_config="$HOME/.ssh/config"

    # Create config if it doesn't exist
    if [ ! -f "$ssh_config" ]; then
        touch "$ssh_config"
        chmod 600 "$ssh_config" 2>/dev/null
    fi

    # Skip if host already configured
    if grep -qi "^Host.*${host}" "$ssh_config" 2>/dev/null; then
        return 0
    fi

    echo -e "\n🔧 Adding \033[1;33m$host\033[0m to SSH config..."
    cat >> "$ssh_config" <<EOF

Host $host
    HostName $host
    User git
    IdentityFile $key_path
    IdentitiesOnly yes
    AddKeysToAgent yes
    LogLevel ERROR
EOF

    echo -e "   ✅ Added to $ssh_config"
}

# --- Git Identity Setup ---
unalias git-setup 2>/dev/null || true
function git-setup() {
    echo -e "\n\033[1;36m=== Git Identity Setup ===\033[0m\n"

    # Show current config if set
    local current_name=$(git config --global user.name 2>/dev/null)
    local current_email=$(git config --global user.email 2>/dev/null)

    if [ -n "$current_name" ] || [ -n "$current_email" ]; then
        echo -e "Current config:"
        [ -n "$current_name" ]  && echo -e "  Name  : \033[1;33m$current_name\033[0m"
        [ -n "$current_email" ] && echo -e "  Email : \033[1;33m$current_email\033[0m"
        echo ""
    fi

    # Prompt for name
    echo -n "Enter your name [${current_name:-Your Name}]: "
    read -r name
    name="${name:-$current_name}"

    if [ -z "$name" ]; then
        echo "❌ Name is required."
        return 1
    fi

    # Prompt for email
    echo -n "Enter your email [${current_email:-you@example.com}]: "
    read -r email
    email="${email:-$current_email}"

    if [ -z "$email" ]; then
        echo "❌ Email is required."
        return 1
    fi

    # Apply
    git config --global user.name "$name"
    git config --global user.email "$email"

    echo ""
    echo -e "✅ Git configured:"
    echo -e "  Name  : \033[1;32m$name\033[0m"
    echo -e "  Email : \033[1;32m$email\033[0m"

    # Offer to set up SSH key next
    echo ""
    echo -n "Set up SSH key now? (y/N): "
    read -r do_ssh
    if [[ "$do_ssh" =~ ^[yY] ]]; then
        ssh-setup "$email"
    fi
}

# --- SSH Key Setup ---
unalias ssh-setup 2>/dev/null || true
function ssh-setup() {
    echo -e "\n\033[1;36m=== SSH Key Setup ===\033[0m\n"

    # Pull identity from git config
    local git_name=$(git config --global user.name 2>/dev/null)
    local git_email=$(git config --global user.email 2>/dev/null)

    # Allow override via argument, fall back to git config
    local email="${1:-$git_email}"

    if [ -z "$email" ]; then
        echo -n "Enter your email for the SSH key: "
        read -r email
        if [ -z "$email" ]; then
            echo "❌ Email is required. Run 'git-setup' first."
            return 1
        fi
    fi

    # Build key comment: "username <email>" or just email
    local key_comment="$email"
    if [ -n "$git_name" ]; then
        key_comment="$git_name <$email>"
    fi

    echo -e "  Name  : \033[1;33m${git_name:-not set}\033[0m"
    echo -e "  Email : \033[1;33m$email\033[0m"
    echo -e "  Comment: \033[1;33m$key_comment\033[0m"
    echo ""

    local key_path="$HOME/.ssh/id_ed25519"

    # Check for existing key
    if [ -f "$key_path" ]; then
        echo -e "⚠️  Key already exists: \033[1;33m$key_path\033[0m"
        echo -n "Overwrite? (y/N): "
        read -r overwrite
        if [[ ! "$overwrite" =~ ^[yY] ]]; then
            echo "Keeping existing key."
            ssh-login
            return 0
        fi
    fi

    # Generate key — passphrase is REQUIRED (no -N flag, interactive prompt)
    echo -e "🔑 Generating ed25519 key for \033[1;32m$key_comment\033[0m..."
    echo -e "⚠️  \033[1;31mA passphrase is REQUIRED.\033[0m You will be prompted to enter one.\n"
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh" 2>/dev/null

    # Loop until user provides a non-empty passphrase
    while true; do
        ssh-keygen -t ed25519 -C "$key_comment" -f "$key_path"

        if [ $? -ne 0 ]; then
            echo "❌ Key generation failed."
            return 1
        fi

        # Verify the key actually has a passphrase by checking with empty string
        # ssh-keygen -y -P "" reads the private key with an empty passphrase;
        # if it succeeds, the key has NO passphrase → reject it
        if ssh-keygen -y -P "" -f "$key_path" &>/dev/null; then
            echo -e "\n❌ \033[1;31mEmpty passphrase detected!\033[0m A passphrase is required for security."
            echo -e "   Let's try again...\n"
            rm -f "$key_path" "${key_path}.pub"
            continue
        fi

        # Key has a passphrase — we're good
        break
    done

    # Start agent and add key
    echo ""
    ssh-login

    # Show public key
    echo ""
    echo -e "\033[1;33m=== Your Public Key (copy this to GitHub) ===\033[0m"
    echo ""
    cat "${key_path}.pub"
    echo ""

    # Copy to clipboard if possible
    if command -v copy >/dev/null 2>&1; then
        cat "${key_path}.pub" | copy 2>/dev/null && echo -e "📋 \033[1;32mCopied to clipboard!\033[0m"
    fi

    # Detect enterprise GitHub
    local gh_host=""
    gh_host=$(_detect_gh_enterprise)

    # Configure ~/.ssh/config for all hosts
    _ssh_configure_host "github.com" "$key_path"
    if [ -n "$gh_host" ]; then
        _ssh_configure_host "$gh_host" "$key_path"
    fi

    echo ""
    echo -e "📝 Add this key at:"
    echo -e "   \033[1;36mhttps://github.com/settings/ssh/new\033[0m"

    if [ -n "$gh_host" ]; then
        echo -e "   \033[1;36mhttps://${gh_host}/settings/ssh/new\033[0m (enterprise)"
    fi

    # Set up SSH URL rewrite for enterprise if not already configured
    if [ -n "$gh_host" ]; then
        local existing_rewrite=$(git config --global --get "url.ssh://git@${gh_host}/.insteadOf" 2>/dev/null)
        if [ -z "$existing_rewrite" ]; then
            echo ""
            echo -e "🔧 Adding SSH URL rewrite for \033[1;33m$gh_host\033[0m..."
            git config --global url."ssh://git@${gh_host}/".insteadOf "https://${gh_host}/"
            echo -e "   ✅ https://${gh_host}/ → ssh://git@${gh_host}/"
        fi
    fi

    echo ""
    echo -n "Test SSH connection now? (y/N): "
    read -r do_test
    if [[ "$do_test" =~ ^[yY] ]]; then
        ssh-test
    fi
}

# --- SSH Login (Daily Use) ---
unalias ssh-login 2>/dev/null || true
function ssh-login() {
    local key_path="$HOME/.ssh/id_ed25519"

    if [ ! -f "$key_path" ]; then
        echo "❌ No SSH key found at $key_path. Run 'ssh-setup' first."
        return 1
    fi

    eval "$(ssh-agent -s)" &>/dev/null
    ssh-add "$key_path" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo "✅ SSH agent ready (key loaded)"
    else
        echo "❌ Failed to add key to agent."
        return 1
    fi
}

# --- SSH Test ---
unalias ssh-test 2>/dev/null || true
function ssh-test() {
    echo -e "\n\033[1;36m=== Testing SSH Connections ===\033[0m\n"

    # Test github.com
    echo -n "Testing github.com... "
    ssh -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 | head -1
    echo ""

    # Detect enterprise GitHub (URL rewrites + credential helpers)
    local gh_host=""
    gh_host=$(_detect_gh_enterprise)

    if [ -n "$gh_host" ]; then
        echo -n "Testing $gh_host... "
        ssh -o StrictHostKeyChecking=accept-new -T "git@$gh_host" 2>&1 | head -1
        echo ""
    fi

    # Also test any host passed as argument
    if [ -n "$1" ] && [ "$1" != "$gh_host" ] && [ "$1" != "github.com" ]; then
        echo -n "Testing $1... "
        ssh -o StrictHostKeyChecking=accept-new -T "git@$1" 2>&1 | head -1
        echo ""
    fi
}
