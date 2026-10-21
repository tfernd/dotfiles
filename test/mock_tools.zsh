# ============================================================================
# 🧪 INTELLIGENT MOCK TOOLS FOR TESTING (zsh)
# ============================================================================

MOCK_BIN_DIR="/tmp/dotfiles_mock_bin"
mkdir -p "$MOCK_BIN_DIR"

TOOLS=(
    zoxide starship bat eza gh jq xh delta yq uv bun atuin zellij fzf
    7z zip unzip tar rar unrar curl ip ipconfig lsof ss fuser xclip wl-copy xsel
    pbcopy ps brew trash-put trash-list trash-restore
    trash-empty trash bunzip2 uncompress gunzip bzip2 gzip compress xz unxz zstd unzstd
    bc python3 df free
)

for tool in "${TOOLS[@]}"; do
    cat > "$MOCK_BIN_DIR/$tool" <<'MOCKEOF'
#!/usr/bin/env bash
case "$0" in
    *trash-put|*/trash)
        for arg in "$@"; do [ "$arg" != "--" ] && [ -f "$arg" ] && rm -f -- "$arg"; done
        exit 0 ;;
esac
if [ $# -eq 0 ]; then exit 0; fi
if [[ "$*" == *"init"* ]]; then echo "# Mocked init"; exit 0; fi
echo "# Mocked output for $0"
case "$0" in
    *tar|*zip|*7z|*rar|*gzip|*bzip2|*compress|*unzip|*unrar|*gunzip|*bunzip2|*uncompress|*xz|*zstd|*unxz|*unzstd)
        for arg in "$@"; do [[ "$arg" == *.* ]] && touch "$arg" 2>/dev/null || true; done ;;
esac
exit 0
MOCKEOF
    chmod +x "$MOCK_BIN_DIR/$tool"
done

cp "$MOCK_BIN_DIR/bat" "$MOCK_BIN_DIR/batcat"
export PATH="$MOCK_BIN_DIR:$PATH"
echo "✅ Mock binaries created in $MOCK_BIN_DIR."
