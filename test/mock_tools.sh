#!/usr/bin/env bash
# ============================================================================
# 🧪 INTELLIGENT MOCK TOOLS FOR TESTING
# ============================================================================

MOCK_BIN_DIR="/tmp/dotfiles_mock_bin"
mkdir -p "$MOCK_BIN_DIR"

# List of tools to mock
TOOLS=(
    zoxide starship bat eza fzf rg fd tldr lazygit gh jq xh yazi btm delta yq uv bun
    7z zip unzip tar rar unrar curl ip ipconfig lsof ss fuser xclip wl-copy xsel 
    pbcopy ps brew trash-put trash-list trash-restore 
    trash-empty trash bunzip2 uncompress gunzip bzip2 gzip compress xz unxz zstd unzstd
    bc python3 aws df free code cursor antigravity cmatrix telnet
)

for tool in "${TOOLS[@]}"; do
    cat > "$MOCK_BIN_DIR/$tool" <<'MOCKEOF'
#!/usr/bin/env bash

# --- Specialized mocks (run BEFORE generic handlers) ---
case "$0" in
    *fzf)
        # FZF: return first line of stdin if piped, else return dummy path
        if [ ! -t 0 ]; then
            head -n 1
        else
            echo "dummy_file.txt"
        fi
        exit 0
        ;;
    *trash-put|*/trash)
        # For functional tests, trash should actually remove the file
        for arg in "$@"; do
            [ -f "$arg" ] && rm -f "$arg"
        done
        exit 0
        ;;
esac

# --- Generic mock behavior ---

# If called without arguments (like command -v), just exit 0
if [ $# -eq 0 ]; then exit 0; fi

# If called as 'init', return a valid empty bash script
if [[ "$*" == *"init"* ]]; then
    echo "# Mocked init"
    exit 0
fi

# Default mock output
echo "# Mocked output for $0"

# Support for 'compress' tests: create archive files
case "$0" in
    *tar|*zip|*7z|*rar|*gzip|*bzip2|*compress|*unzip|*unrar|*gunzip|*bunzip2|*uncompress|*xz|*zstd|*unxz|*unzstd)
        for arg in "$@"; do
            if [[ "$arg" == *.* ]]; then
                touch "$arg" 2>/dev/null || true
            fi
        done
        ;;
esac
exit 0
MOCKEOF
    chmod +x "$MOCK_BIN_DIR/$tool"
done

# Special case for batcat/bat mapping
cp "$MOCK_BIN_DIR/bat" "$MOCK_BIN_DIR/batcat"

export PATH="$MOCK_BIN_DIR:$PATH"
echo "✅ Intelligent mock binaries created in $MOCK_BIN_DIR."
