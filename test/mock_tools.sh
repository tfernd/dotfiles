#!/usr/bin/env bash
# ============================================================================
# 🧪 INTELLIGENT MOCK TOOLS FOR TESTING
# ============================================================================

MOCK_BIN_DIR="/tmp/dotfiles_mock_bin"
mkdir -p "$MOCK_BIN_DIR"

# List of tools to mock
TOOLS=(zoxide starship bat eza fzf rg fd tldr lazygit gh jq xh yazi btm delta yq uv)

for tool in "${TOOLS[@]}"; do
    cat > "$MOCK_BIN_DIR/$tool" <<EOF
#!/usr/bin/env bash
# If called without arguments (like command -v), just exit 0
if [ \$# -eq 0 ]; then exit 0; fi

# If called as 'init', return a valid empty bash script
if [[ "\$*" == *"init"* ]]; then
    echo "# Mocked init"
    exit 0
fi

# Default mock output
echo "# Mocked output for \$0"
EOF
    chmod +x "$MOCK_BIN_DIR/$tool"
done

# Special case for batcat
cp "$MOCK_BIN_DIR/bat" "$MOCK_BIN_DIR/batcat"

export PATH="$MOCK_BIN_DIR:$PATH"
echo "✅ Intelligent mock binaries created in $MOCK_BIN_DIR."
