#!/usr/bin/env bash
# ============================================================================
# EDITOR CONFIGURATION HELPER
# ============================================================================
# Prints recommended VS Code / Kiro / Cursor settings for the current platform.
# Run 'editor-config' and paste the output into your settings.json.

unalias editor-config 2>/dev/null || true
function editor-config() {
    echo -e "\033[1;36m=================================================================\033[0m"
    echo -e "\033[1;35m  Recommended Editor Settings\033[0m"
    echo -e "\033[1;36m=================================================================\033[0m"
    echo ""
    echo "Copy the settings below into your VS Code / Kiro / Cursor settings.json"
    echo ""
    echo -e "\033[1;33m// === EDITOR ===\033[0m"
    cat << 'EDITOR'
"editor.fontFamily": "FiraCode Nerd Font, Consolas, 'Courier New', monospace",
"editor.fontLigatures": true,
"editor.cursorBlinking": "phase",
"editor.smoothScrolling": true,
"editor.bracketPairColorization.enabled": true,
"editor.renderControlCharacters": true,
"editor.formatOnSave": true,
"editor.stickyScroll.enabled": true,
"files.autoSave": "onFocusChange",
EDITOR

    echo ""
    echo -e "\033[1;33m// === TERMINAL ===\033[0m"
    cat << 'TERM_COMMON'
"terminal.integrated.fontFamily": "FiraCode Nerd Font",
"terminal.integrated.enableMultiLinePasteWarning": "never",
"terminal.integrated.suggest.quickSuggestions": {
    "arguments": "on",
    "unknown": "on"
},
TERM_COMMON

    # Platform-specific terminal profile
    if [ "$IS_MAC" = "true" ]; then
        echo -e "\033[1;33m// === TERMINAL PROFILE (macOS) ===\033[0m"
        cat << 'MAC_TERM'
"terminal.integrated.defaultProfile.osx": "zsh",
"terminal.integrated.profiles.osx": {
    "zsh": {
        "path": "/bin/zsh",
        "args": ["-l"],
        "icon": "terminal"
    }
},
MAC_TERM
    elif [ "$IS_LINUX" = "true" ]; then
        local shell_path="/usr/bin/zsh"
        [ ! -f "$shell_path" ] && shell_path="/bin/bash"
        local shell_name=$(basename "$shell_path")
        local profile_label="Linux"
        [ "$IS_WSL" = "true" ] && profile_label="WSL"
        echo -e "\033[1;33m// === TERMINAL PROFILE ($profile_label) ===\033[0m"
        cat << LINUX_TERM
"terminal.integrated.defaultProfile.linux": "$shell_name",
"terminal.integrated.profiles.linux": {
    "$shell_name": {
        "path": "$shell_path",
        "args": ["-l"],
        "icon": "terminal"
    }
},
LINUX_TERM
    fi

    echo ""
    echo -e "\033[1;33m// === EXPLORER ===\033[0m"
    cat << 'EXPLORER'
"explorer.sortOrder": "type",
"explorer.confirmDelete": false,
"explorer.confirmDragAndDrop": false,
"explorer.fileNesting.patterns": {
    "*.ts": "${capture}.js",
    "*.js": "${capture}.js.map, ${capture}.min.js, ${capture}.d.ts",
    "tsconfig.json": "tsconfig.*.json",
    "package.json": "package-lock.json, yarn.lock, pnpm-lock.yaml, bun.lockb",
    "Cargo.toml": "Cargo.lock"
},
"files.exclude": {
    "**/__pycache__": true,
    "**/*.pyc": true,
    "**/.git": true,
    "**/.DS_Store": true,
    "**/venv": true,
    "**/.venv": true,
    ".ruff_cache": true,
    ".mypy_cache": true,
    ".pytest_cache": true
},
"files.watcherExclude": {
    "**/.git/**": true,
    "**/node_modules/**": true,
    "**/.venv/**": true,
    "**/__pycache__/**": true
},
EXPLORER

    echo ""
    echo -e "\033[1;33m// === GIT ===\033[0m"
    cat << 'GIT'
"git.autofetch": true,
"git.confirmSync": false,
"git.ignoreRebaseWarning": true,
"git.openRepositoryInParentFolders": "never"
GIT

    echo ""
    echo -e "\033[1;36m=================================================================\033[0m"
    echo -e "💡 Paste these into your editor's \033[1;32msettings.json\033[0m"
    echo -e "   (Ctrl+Shift+P → 'Open User Settings (JSON)')"
    echo -e "\033[1;36m=================================================================\033[0m"
}
