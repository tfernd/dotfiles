#!/usr/bin/env bash
# ============================================================================
# FILE & WORKSPACE MANAGEMENT FUNCTIONS
# ============================================================================

# cw — switch the current editor window (Antigravity, Cursor, or Code) to this folder
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

# backup — create a dated copy of a file or folder
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

# symlink — cross-platform symlink creator (handles junctions on Windows)
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
