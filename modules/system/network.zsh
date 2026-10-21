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

function port() {
    if [[ -z "$1" ]]; then
        echo -e "🔍 \033[1;36mListing all listening ports:\033[0m"
        if (( $+commands[lsof] )); then
            lsof -i -P -n | grep LISTEN
        elif (( $+commands[ss] )); then
            ss -tlnp
        else
            netstat -tlnp 2>/dev/null || echo "❌ No port scanner found."
        fi
        return 0
    fi

    if (( $+commands[lsof] )); then
        lsof -i :"$1"
    elif (( $+commands[ss] )); then
        ss -tlnp "sport = :$1"
    else
        netstat -tlnp 2>/dev/null | grep ":$1 " || echo "❌ No port scanner found."
    fi
}

function kill-port() {
    if [[ -z "$1" ]]; then
        echo -e "📝 \033[1;33mUsage:\033[0m kill-port <number>"
        return 1
    fi

    local port="$1"
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        echo "❌ Invalid port number: $port"
        return 1
    fi

    local pids=""
    if (( $+commands[lsof] )); then
        pids=$(lsof -t -i:"$port" 2>/dev/null)
    elif (( $+commands[ss] )) && [[ "$IS_LINUX" == "true" ]]; then
        pids=$(ss -lptn "sport = :$port" | grep -oP '(?<=pid=)\d+' | sort -u)
    elif (( $+commands[fuser] )); then
        pids=$(fuser "$port/tcp" 2>/dev/null | awk '{print $NF}')
    fi

    if [[ -n "$pids" ]]; then
        echo -e "⚠️  Will kill process(es) on port $port:\n$pids"
        echo -n "Proceed? (y/N): "
        read -r confirm
        if [[ "$confirm" =~ ^[yY] ]]; then
            echo "$pids" | xargs kill -9 2>/dev/null
            echo -e "✅ Terminated process(es) on port $port"
        else
            echo "Cancelled."
        fi
    else
        echo "🔍 Nothing found on port $port"
    fi
}
