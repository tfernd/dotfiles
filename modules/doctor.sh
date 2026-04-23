#!/usr/bin/env bash
# ============================================================================
# 🩺 THE DOT DOCTOR (Health Check)
# ============================================================================
unalias dotdoctor 2>/dev/null || true
function dotdoctor() {
    echo -e "\n\033[1;35m=================================================================\033[0m"
    echo -e "\033[1;36m  🩺 DOTFILES HEALTH CHECK\033[0m"
    echo -e "\033[1;35m=================================================================\033[0m\n"

    local missing_tools=()
    local critical_tools=(zoxide starship fzf rg fd lazygit gh jq xh uv)
    
    # OS-Specific Additions
    critical_tools+=(brew)
    [ "$IS_LINUX" = "true" ] && critical_tools+=(trash-put)

    echo -e "\033[1;33m🔍 Checking Critical Tools...\033[0m"
    for tool in "${critical_tools[@]}"; do
        # Special case for 'bat' which might be 'batcat' on some systems
        if [ "$tool" = "bat" ]; then
            if command -v bat >/dev/null 2>&1 || command -v batcat >/dev/null 2>&1; then
                printf "  ✅ \033[1;32m%-15s\033[0m : Found (bat/batcat)\n" "bat"
                continue
            fi
        fi

        if command -v "$tool" >/dev/null 2>&1; then
            printf "  ✅ \033[1;32m%-15s\033[0m : Found\n" "$tool"
        else
            printf "  ❌ \033[1;31m%-15s\033[0m : MISSING\n" "$tool"
            missing_tools+=("$tool")
        fi
    done

    echo -e "\n\033[1;33m📦 Checking Cache Integrity...\033[0m"
    local caches=("$HOME/.cache/bashrc_tools" "$HOME/.cache/zoxide_init.$CURRENT_SHELL" "$HOME/.cache/starship_init.$CURRENT_SHELL")
    for cache in "${caches[@]}"; do
        local cache_name=$(basename "$cache")
        if [ -f "$cache" ]; then
            printf "  ✅ \033[1;32m%-18s\033[0m : Up-to-date\n" "$cache_name"
        else
            printf "  ⚠️ \033[1;33m%-18s\033[0m : MISSING (Will regenerate)\n" "$cache_name"
        fi
    done

    echo -e "\n\033[1;33m🌐 Checking Browser Opener...\033[0m"
    if [ "$IS_MAC" = "true" ]; then
        # macOS always has 'open'
        printf "  ✅ \033[1;32m%-15s\033[0m : Found (macOS built-in)\n" "open"
    elif [ "$IS_WSL" = "true" ]; then
        if command -v wslview >/dev/null 2>&1; then
            printf "  ✅ \033[1;32m%-15s\033[0m : Found\n" "wslview"
        else
            printf "  ❌ \033[1;31m%-15s\033[0m : MISSING (install wslu)\n" "wslview"
            missing_tools+=("wslview")
        fi
    elif [ "$IS_LINUX" = "true" ]; then
        if command -v xdg-open >/dev/null 2>&1; then
            printf "  ✅ \033[1;32m%-15s\033[0m : Found\n" "xdg-open"
        else
            printf "  ❌ \033[1;31m%-15s\033[0m : MISSING (install xdg-utils)\n" "xdg-open"
            missing_tools+=("xdg-open")
        fi
    fi

    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo -e "\n\033[1;31m🛑 DOCTOR'S ORDERS:\033[0m"
        echo -e "Some tools are missing. Run \033[1;32msetup-terminal\033[0m to install them automatically."
        echo -e "Missing: ${missing_tools[*]}"
    else
        echo -e "\n\033[1;32m🎉 DOCTOR'S ORDERS:\033[0m"
        echo -e "Your environment is healthy and optimized for production. Clean bill of health!"
    fi

    echo -e "\n\033[1;35m=================================================================\033[0m\n"
}
