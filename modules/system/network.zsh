# ============================================================================
# NETWORK UTILITIES
# ============================================================================

function myip() {
    echo -e "\033[1;36m🌐 Public IP Addresses:\033[0m"
    echo -e "  \033[1;32mIPv4\033[0m : $(curl -s -4 ifconfig.me || echo 'Not available')"
    echo -e "  \033[1;32mIPv6\033[0m : $(curl -s -6 ifconfig.me || echo 'Not available')"
}

function localip() {
    if [[ "$IS_LINUX" == "true" ]]; then
        ip route get 1.2.3.4 2>/dev/null | awk '{print $7}' | head -n 1
    elif [[ "$IS_MAC" == "true" ]]; then
        ipconfig getifaddr en0
    fi
}
