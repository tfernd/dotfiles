#!/usr/bin/env bash
# ============================================================================
# FILE & WORKSPACE MANAGEMENT FUNCTIONS
# ============================================================================

# --- Editor Re-attachment ---
# Switches the current editor window to focus on the current directory.
unalias cw 2>/dev/null || true
function cw() {
    local node=$(echo "$VSCODE_GIT_ASKPASS_NODE" | tr '[:upper:]' '[:lower:]')
    case "$node" in
        *code*)        code -r . ;;
        *cursor*)      cursor -r . ;;
        *antigravity*) antigravity -r . ;;
        *) echo "❌ Not inside a supported editor terminal." ;;
    esac
}

# --- Point-in-time Backup ---
# Creates a timestamped duplicate of a file or directory for safe editing.
unalias backup 2>/dev/null || true
function backup() {
    if [ -z "$1" ]; then
        echo -e "📝 \033[1;33mUsage:\033[0m backup <file_or_dir>"
        return 1
    fi
    local dest="${1}.$(date +%Y%m%d_%H%M%S).bak"
    cp -r "$1" "$dest"
    echo "✅ Backed up $1 -> $dest"
}

# --- Cross-Platform Symlinking ---
# Creates directory links compatible with both Unix and Windows (Junctions).
unalias symlink 2>/dev/null || true
function symlink() {
    if [ $# -ne 2 ]; then
        echo -e "📝 \033[1;33mUsage:\033[0m symlink <link_name> <target_path>"
        return 1
    fi
    
    local link="$1" target="$2"
    if [ "$IS_WIN" = "true" ]; then
        cmd.exe /c mklink /J "$(cygpath -w "$link")" "$(cygpath -w "$target")"
    else
        ln -s "$target" "$link"
    fi
}

# --- Navigation & File Reading Aliases ---

# --- File Listing (ls/eza) ---
if [ "$HAS_EZA" = "true" ]; then
    alias ls='eza --icons --group-directories-first --color=always'
    alias ll='eza -l --icons --group-directories-first --color=always --time-style=long-iso --git'
    alias lt='eza --tree --icons --group-directories-first -L 2 --color=always'

    alias lsh='eza -a --icons --group-directories-first --color=always'
    alias llh='eza -la --icons --group-directories-first --color=always --time-style=long-iso --git'
    alias lth='eza -a --tree --icons --group-directories-first -L 2 --color=always'
fi

# --- File Reading (cat/bat) ---
if [ "$HAS_BAT" = "true" ]; then
    [ "$HAS_BATCAT" = "true" ] && alias bat='batcat'
    alias cat='bat --style=plain --paging=never'
    alias ccat='bat'
fi

[ "$HAS_FD" = "true" ]   && alias fd='fd --color=auto'
[ "$HAS_YAZI" = "true" ] && alias y='yazi'

# --- Shortcut Aliases ---
alias ..='cd ..'
alias ~='cd ~'
alias -- -='cd -'

# up — Move up a specified number of directories. (Usage: up 3)
unalias up 2>/dev/null || true
function up() {
    local limit="${1:-1}"
    local d=""
    for ((i=1 ; i <= limit ; i++)); do
        d="../$d"
    done
    cd "$d" || return
}
