#!/usr/bin/env bash
# ============================================================================
# 🚀 DOTFILES BOOTSTRAP (bare-metal entry point)
# ============================================================================
# Usage:
#   git clone https://github.com/username/dotfiles.git ~/.dotfiles
#   bash ~/.dotfiles/install.sh
# ============================================================================
set -euo pipefail

echo -e "\n\033[1;36m=================================================================\033[0m"
echo -e "\033[1;35m  🚀 DOTFILES BARE-METAL BOOTSTRAP\033[0m"
echo -e "\033[1;36m=================================================================\033[0m\n"

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="${HOME}/.dotfiles"

# ============================================================================
# STEP 0: Detect platform
# ============================================================================
PLATFORM=""
case "$OSTYPE" in
    darwin*)
        PLATFORM="macos"
        ;;
    linux*)
        if grep -qi microsoft /proc/version 2>/dev/null; then
            PLATFORM="wsl"
        else
            PLATFORM="debian"
        fi
        ;;
    *)
        echo "❌ Unsupported platform: $OSTYPE"
        exit 1
        ;;
esac
echo -e "🖥️  Platform detected: \033[1;33m${PLATFORM}\033[0m\n"

# ============================================================================
# STEP 1: Install ALL system packages (assumes user has NOTHING)
# ============================================================================
echo -e "\033[1;34m📦 STEP 1: Installing system packages...\033[0m\n"

if [[ "$PLATFORM" == "macos" ]]; then
    if ! xcode-select -p &>/dev/null; then
        echo "🔧 Installing Xcode Command Line Tools..."
        xcode-select --install 2>/dev/null || true
        echo "   ⏳ Waiting for Xcode CLI tools (press any key when done)..."
        read -r -n 1
    fi

    if ! command -v brew &>/dev/null; then
        echo "🍺 Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    else
        echo "❌ FATAL: Homebrew not found after install (/opt/homebrew or /usr/local)."
        exit 1
    fi

    echo "📦 Installing tools via Homebrew..."
    brew install \
        zsh curl wget coreutils \
        starship zoxide atuin zellij bat eza ripgrep trash-cli yq xh fzf \
        git git-delta jq bun \
        p7zip zip unzip xz zstd unar \
        zsh-autosuggestions zsh-syntax-highlighting
    brew install --cask font-fira-code-nerd-font 2>/dev/null || true

else
    echo "📦 Updating APT package lists..."
    sudo apt update -y

    if command -v add-apt-repository &>/dev/null; then
        if ! grep -qr "^deb.*universe" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
            echo "  Enabling universe repository..."
            sudo add-apt-repository -y universe 2>/dev/null || true
            sudo apt update -y
        fi
    fi

    echo ""
    echo "📦 Installing required system packages..."
    sudo apt install -y \
        zsh \
        git \
        curl \
        wget \
        build-essential \
        ca-certificates \
        gnupg \
        lsb-release \
        procps \
        lsof \
        bc \
        jq \
        fontconfig \
        xdg-utils \
        trash-cli \
        fzf \
        xclip \
        p7zip-full \
        unzip \
        zip \
        gzip \
        tar \
        unrar-free \
        xz-utils \
        zstd \
        bzip2 \
        libssl-dev \
        libcurl4-openssl-dev \
        libexpat1-dev \
        zlib1g-dev \
        gettext
    sudo apt install -y \
        zsh-autosuggestions \
        zsh-syntax-highlighting \
        2>/dev/null || true

    # WSL-specific packages
    if [[ "$PLATFORM" == "wsl" ]]; then
        sudo apt install -y wslu 2>/dev/null || true
    fi
fi

echo -e "\n✅ System packages installed.\n"

# ============================================================================
# STEP 2: Set zsh as default shell
# ============================================================================
echo -e "\033[1;34m🐚 STEP 2: Setting zsh as default shell...\033[0m\n"

ZSH_PATH="$(command -v zsh 2>/dev/null || true)"
if [[ -z "$ZSH_PATH" ]]; then
    echo "❌ FATAL: zsh not found after installation. Cannot continue."
    exit 1
fi

if [[ "${SHELL:-}" != "$ZSH_PATH" ]]; then
    if ! grep -qx "$ZSH_PATH" /etc/shells 2>/dev/null; then
        echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null 2>&1
    fi
    echo "  Setting $ZSH_PATH as default shell..."
    sudo chsh -s "$ZSH_PATH" "$USER" 2>/dev/null || chsh -s "$ZSH_PATH" 2>/dev/null || true
    echo "  ✅ Default shell: zsh"
else
    echo "  ✅ zsh is already the default shell"
fi
echo ""

# ============================================================================
# STEP 3: Install Oh My Zsh + plugins
# ============================================================================
echo -e "\033[1;34m🐚 STEP 3: Installing Oh My Zsh...\033[0m\n"

if [[ ! -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]]; then
    echo "  Installing Oh My Zsh (pinned commit)..."
    OMZ_COMMIT="4b657407c98bbc8830ae66c2ac7ff3d737c55a83"  # 2026-08-29
    git clone --filter=blob:none https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
    # Full clone already fetched history; only fetch the pinned commit if it isn't present.
    (cd "$HOME/.oh-my-zsh" \
        && { git cat-file -e "${OMZ_COMMIT}^{commit}" 2>/dev/null || git fetch --depth=1 origin "$OMZ_COMMIT"; } \
        && git checkout --detach "$OMZ_COMMIT")
    OMZ_HEAD="$(git -C "$HOME/.oh-my-zsh" rev-parse HEAD)"
    if [[ "$OMZ_HEAD" != "$OMZ_COMMIT" ]]; then
        echo "❌ FATAL: Oh My Zsh HEAD is ${OMZ_HEAD}, expected ${OMZ_COMMIT}"
        exit 1
    fi
    echo "  ✅ Oh My Zsh installed (commit: ${OMZ_COMMIT:0:12})"
else
    echo "  ✅ Oh My Zsh already installed"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
    echo "  Cloning zsh-autosuggestions..."
    git clone --depth=1 --branch v0.7.1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" 2>/dev/null || true
fi
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
    echo "  Cloning zsh-syntax-highlighting..."
    git clone --depth=1 --branch 0.8.0 https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" 2>/dev/null || true
fi
echo ""

# ============================================================================
# STEP 4: Install Nerd Fonts
# ============================================================================
echo -e "\033[1;34m🔡 STEP 4: Installing FiraCode Nerd Font...\033[0m\n"

FONT_VER=$(grep 'firacode-nerd' "$DOTFILES_DIR/versions.toml" | sed -E 's/.*version = "([^"]+)".*/\1/')
if [[ -z "$FONT_VER" ]]; then FONT_VER="3.3.0"; fi

if [[ "$PLATFORM" == "macos" ]]; then
    brew install --cask font-fira-code-nerd-font 2>/dev/null || true
    echo "  ✅ FiraCode Nerd Font installed"
else
    if fc-list : family 2>/dev/null | grep -qi "FiraCode" || [[ -d "$HOME/.local/share/fonts" && $(find "$HOME/.local/share/fonts" -name "*FiraCode*" | head -1) ]]; then
        echo "  ✅ FiraCode Nerd Font already installed"
    else
        echo "  Downloading FiraCode Nerd Font v${FONT_VER}..."
        mkdir -p "$HOME/.local/share/fonts"
        curl -fsSL -o /tmp/FiraCode.zip \
            "https://github.com/ryanoasis/nerd-fonts/releases/download/v${FONT_VER}/FiraCode.zip"
        unzip -qo /tmp/FiraCode.zip -d "$HOME/.local/share/fonts/"
        fc-cache -f "$HOME/.local/share/fonts/" 2>/dev/null || true
        rm -f /tmp/FiraCode.zip
        echo "  ✅ FiraCode Nerd Font v${FONT_VER} installed"
    fi
fi
echo ""

# ============================================================================
# STEP 5: Install pinned CLI tools (quarantine + checksum verified)
# git, uv, gh: Debian / WSL / macOS. Other tools: Linux binaries.
# ============================================================================
echo -e "\033[1;34m🔧 STEP 5: Installing pinned CLI tools...\033[0m\n"

mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

ARCH="" YQ_ARCH="" BUN_ARCH="" DELTA_TRIPLE="" UV_TRIPLE="" GH_OS="" GH_ARCH=""
case "$(uname -m)" in
    x86_64|amd64)
        ARCH="x86_64"
        YQ_ARCH="amd64"
        BUN_ARCH="x64"
        DELTA_TRIPLE="x86_64-unknown-linux-musl"
        GH_ARCH="amd64"
        ;;
    aarch64|arm64)
        ARCH="aarch64"
        YQ_ARCH="arm64"
        BUN_ARCH="aarch64"
        DELTA_TRIPLE="aarch64-unknown-linux-gnu"
        GH_ARCH="arm64"
        ;;
    *)
        echo "❌ FATAL: unsupported arch $(uname -m) (need x86_64 or aarch64)"
        exit 1
        ;;
esac
if [[ "$PLATFORM" == "macos" ]]; then
    UV_TRIPLE="${ARCH}-apple-darwin"
    GH_OS="macOS"
else
    UV_TRIPLE="${ARCH}-unknown-linux-musl"
    GH_OS="linux"
fi

    _ver() { grep "^$1" "$DOTFILES_DIR/versions.toml" | sed -E 's/.*version = "([^"]+)".*/\1/'; }
    _released() { grep "^$1" "$DOTFILES_DIR/versions.toml" | sed -E 's/.*released = "([^"]+)".*/\1/'; }

    _github_digest() {
        local url="$1"
        local repo tag asset
        repo=$(echo "$url" | sed -E 's|https://github.com/([^/]+/[^/]+)/releases/download/.*|\1|')
        tag=$(echo "$url" | sed -E 's|https://github.com/[^/]+/[^/]+/releases/download/([^/]+)/.*|\1|')
        asset="${url##*/}"
        curl -fsSL "https://api.github.com/repos/${repo}/releases/tags/${tag}" \
            | jq -r --arg n "$asset" '.assets[] | select(.name == $n) | .digest // empty'
    }

    _install_bin() {
        local name="$1" url="$2" checksum_url="$3" extract_cmd="$4" binary_path="$5"
        local tmpfile=$(mktemp "/tmp/${name}-XXXXXX")
        curl -fsSL -o "$tmpfile" "$url" || { echo "    ❌ Download failed for $name"; rm -f "$tmpfile"; return 1; }

        local expected=""
        if [[ -n "$checksum_url" ]]; then
            local sums
            sums=$(curl -fsSL "$checksum_url") || { echo "    ❌ Checksum download failed for $name"; rm -f "$tmpfile"; return 1; }
            expected=$(echo "$sums" | awk -v n="${url##*/}" 'index($0, n) {print $1; exit}')
            [[ -z "$expected" ]] && expected=$(echo "$sums" | awk '{print $1; exit}')
        else
            local digest
            digest=$(_github_digest "$url")
            [[ "$digest" == sha256:* ]] && expected="${digest#sha256:}"
        fi
        if [[ -z "$expected" ]]; then
            echo "    ❌ No SHA256 available for $name"
            rm -f "$tmpfile"
            return 1
        fi
        local actual
        actual=$(sha256sum "$tmpfile" 2>/dev/null | awk '{print $1}')
        [[ -z "$actual" ]] && actual=$(shasum -a 256 "$tmpfile" | awk '{print $1}')
        if [[ "$expected" != "$actual" ]]; then
            echo "    ❌ CHECKSUM MISMATCH for $name!"
            rm -f "$tmpfile"
            return 1
        fi

        case "$extract_cmd" in
            tar)
                local extract_dir="/tmp/${name}-extract"
                rm -rf "$extract_dir" && mkdir -p "$extract_dir"
                tar xzf "$tmpfile" -C "$extract_dir" 2>/dev/null
                cp -f "$extract_dir/${binary_path}" "$HOME/.local/bin/"
                rm -rf "$extract_dir"
                ;;
            zip)
                local tmpdir=$(mktemp -d "/tmp/${name}-zip-XXXXXX")
                unzip -qo "$tmpfile" -d "$tmpdir" 2>/dev/null
                local bin_found=$(find "$tmpdir" -name "$name" -type f | head -1)
                [[ -z "$bin_found" ]] && bin_found=$(find "$tmpdir" -name "${binary_path##*/}" -type f | head -1)
                cp -f "$bin_found" "$HOME/.local/bin/$name"
                rm -rf "$tmpdir"
                ;;
            binary)
                cp -f "$tmpfile" "$HOME/.local/bin/$name"
                ;;
        esac
        chmod +x "$HOME/.local/bin/$name" 2>/dev/null || true
        rm -f "$tmpfile"
        echo "    ✅ $name installed"
    }

    _ensure() {
        local name="$1" cmd="$2" pinned_ver="$3" released_date="$4"
        shift 4
        if [[ -n "$released_date" ]]; then
            local release_epoch=$(date -d "$released_date" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$released_date" +%s 2>/dev/null || echo 0)
            local now_epoch=$(date +%s)
            local age_days=$(( (now_epoch - release_epoch) / 86400 ))
            if (( age_days < 14 )); then
                echo "  ⏳ $name v$pinned_ver: in quarantine (${age_days}d old) — SKIPPING"
                return 0
            fi
        fi

        local cmd_path=""
        if [[ -x "$HOME/.local/bin/$cmd" ]]; then
            cmd_path="$HOME/.local/bin/$cmd"
        elif command -v "$cmd" &>/dev/null; then
            cmd_path=$(command -v "$cmd")
        fi

        if [[ -n "$cmd_path" ]]; then
            local installed_ver=$("$cmd_path" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+[0-9.]*' | head -1)
            if [[ "$installed_ver" == "$pinned_ver" ]]; then
                printf "  ✅ %-12s v%-10s (up to date)\n" "$name" "$installed_ver"
                return 0
            fi
        fi

        printf "  📦 %-12s installing v%s\n" "$name" "$pinned_ver"
        _install_bin "$name" "$@"
    }

    _quarantined() {
        local name="$1" pinned_ver="$2" released_date="$3"
        if [[ -z "$released_date" ]]; then
            return 0
        fi
        local release_epoch now_epoch age_days
        release_epoch=$(date -d "$released_date" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$released_date" +%s 2>/dev/null || echo 0)
        now_epoch=$(date +%s)
        age_days=$(( (now_epoch - release_epoch) / 86400 ))
        if (( age_days < 14 )); then
            echo "  ⏳ $name v$pinned_ver: in quarantine (${age_days}d old) — SKIPPING"
            return 1
        fi
        return 0
    }

    # git: no portable binaries; build the pinned tarball into ~/.local (Debian/WSL/macOS)
    _install_git() {
        local v="$1" r="$2"
        _quarantined "git" "$v" "$r" || return 0
        local cmd_path=""
        if [[ -x "$HOME/.local/bin/git" ]]; then
            cmd_path="$HOME/.local/bin/git"
        elif command -v git &>/dev/null; then
            cmd_path=$(command -v git)
        fi
        if [[ -n "$cmd_path" ]]; then
            local installed_ver
            installed_ver=$("$cmd_path" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+[0-9.]*' | head -1)
            if [[ "$installed_ver" == "$v" ]]; then
                printf "  ✅ %-12s v%-10s (up to date)\n" "git" "$installed_ver"
                return 0
            fi
        fi
        printf "  📦 %-12s installing v%s from source\n" "git" "$v"
        local url="https://mirrors.edge.kernel.org/pub/software/scm/git/git-${v}.tar.xz"
        local sums_url="https://mirrors.edge.kernel.org/pub/software/scm/git/sha256sums.asc"
        local tmpfile extract_dir jobs
        tmpfile=$(mktemp "/tmp/git-XXXXXX")
        curl -fsSL -o "$tmpfile" "$url" || { echo "    ❌ Download failed for git"; rm -f "$tmpfile"; return 1; }
        local expected actual
        expected=$(curl -fsSL "$sums_url" | awk -v n="git-${v}.tar.xz" 'index($0, n) {print $1; exit}')
        actual=$(sha256sum "$tmpfile" 2>/dev/null | awk '{print $1}')
        [[ -z "$actual" ]] && actual=$(shasum -a 256 "$tmpfile" | awk '{print $1}')
        if [[ -z "$expected" || "$expected" != "$actual" ]]; then
            echo "    ❌ CHECKSUM MISMATCH for git"
            rm -f "$tmpfile"
            return 1
        fi
        extract_dir="/tmp/git-extract"
        rm -rf "$extract_dir" && mkdir -p "$extract_dir"
        tar xJf "$tmpfile" -C "$extract_dir"
        rm -f "$tmpfile"
        jobs=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)
        (cd "$extract_dir/git-${v}" && make prefix="$HOME/.local" NO_TCLTK=1 -j"$jobs" all && make prefix="$HOME/.local" NO_TCLTK=1 install) \
            || { echo "    ❌ git build failed"; rm -rf "$extract_dir"; return 1; }
        rm -rf "$extract_dir"
        echo "    ✅ git v${v} installed"
    }

    if [[ "$PLATFORM" == "macos" ]]; then
        # macOS: git is provided by Homebrew (Step 1); no source build needed.
        _git_ver_now=$(git --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+[0-9.]*' | head -1)
        printf "  ✅ %-12s v%-10s (via Homebrew)\n" "git" "${_git_ver_now:-?}"
    else
        v=$(_ver git); r=$(_released git)
        _install_git "$v" "$r"
    fi

    # uv (Debian / WSL / macOS)
    v=$(_ver uv); r=$(_released uv)
    _ensure "uv" "uv" "$v" "$r" \
        "https://github.com/astral-sh/uv/releases/download/${v}/uv-${UV_TRIPLE}.tar.gz" \
        "https://github.com/astral-sh/uv/releases/download/${v}/uv-${UV_TRIPLE}.tar.gz.sha256" \
        "tar" "uv-${UV_TRIPLE}/uv"

    # gh (Debian / WSL / macOS) — GitHub release, not apt/brew latest
    v=$(_ver gh); r=$(_released gh)
    if [[ "$PLATFORM" == "macos" ]]; then
        _ensure "gh" "gh" "$v" "$r" \
            "https://github.com/cli/cli/releases/download/v${v}/gh_${v}_${GH_OS}_${GH_ARCH}.zip" \
            "https://github.com/cli/cli/releases/download/v${v}/gh_${v}_checksums.txt" \
            "zip" "gh"
    else
        _ensure "gh" "gh" "$v" "$r" \
            "https://github.com/cli/cli/releases/download/v${v}/gh_${v}_${GH_OS}_${GH_ARCH}.tar.gz" \
            "https://github.com/cli/cli/releases/download/v${v}/gh_${v}_checksums.txt" \
            "tar" "gh_${v}_${GH_OS}_${GH_ARCH}/bin/gh"
    fi

if [[ "$PLATFORM" != "macos" ]]; then
    # starship
    v=$(_ver starship); r=$(_released starship)
    _ensure "starship" "starship" "$v" "$r" \
        "https://github.com/starship/starship/releases/download/v${v}/starship-${ARCH}-unknown-linux-musl.tar.gz" \
        "https://github.com/starship/starship/releases/download/v${v}/starship-${ARCH}-unknown-linux-musl.tar.gz.sha256" \
        "tar" "starship"

    # ripgrep
    v=$(_ver ripgrep); r=$(_released ripgrep)
    _ensure "rg" "rg" "$v" "$r" \
        "https://github.com/BurntSushi/ripgrep/releases/download/${v}/ripgrep-${v}-${ARCH}-unknown-linux-musl.tar.gz" \
        "https://github.com/BurntSushi/ripgrep/releases/download/${v}/ripgrep-${v}-${ARCH}-unknown-linux-musl.tar.gz.sha256" \
        "tar" "ripgrep-${v}-${ARCH}-unknown-linux-musl/rg"

    # zoxide
    v=$(_ver zoxide); r=$(_released zoxide)
    _ensure "zoxide" "zoxide" "$v" "$r" \
        "https://github.com/ajeetdsouza/zoxide/releases/download/v${v}/zoxide-${v}-${ARCH}-unknown-linux-musl.tar.gz" \
        "" "tar" "zoxide"

    # delta (aarch64 ships gnu only; x86_64 uses musl)
    v=$(_ver delta); r=$(_released delta)
    _ensure "delta" "delta" "$v" "$r" \
        "https://github.com/dandavison/delta/releases/download/${v}/delta-${v}-${DELTA_TRIPLE}.tar.gz" \
        "" "tar" "delta-${v}-${DELTA_TRIPLE}/delta"

    # eza
    v=$(_ver eza); r=$(_released eza)
    _ensure "eza" "eza" "$v" "$r" \
        "https://github.com/eza-community/eza/releases/download/v${v}/eza_${ARCH}-unknown-linux-gnu.tar.gz" \
        "" "tar" "eza"

    # bat
    v=$(_ver bat); r=$(_released bat)
    _ensure "bat" "bat" "$v" "$r" \
        "https://github.com/sharkdp/bat/releases/download/v${v}/bat-v${v}-${ARCH}-unknown-linux-musl.tar.gz" \
        "" "tar" "bat-v${v}-${ARCH}-unknown-linux-musl/bat"

    # xh
    v=$(_ver xh); r=$(_released xh)
    _ensure "xh" "xh" "$v" "$r" \
        "https://github.com/ducaale/xh/releases/download/v${v}/xh-v${v}-${ARCH}-unknown-linux-musl.tar.gz" \
        "" "tar" "xh-v${v}-${ARCH}-unknown-linux-musl/xh"

    # yq
    v=$(_ver yq); r=$(_released yq)
    _ensure "yq" "yq" "$v" "$r" \
        "https://github.com/mikefarah/yq/releases/download/v${v}/yq_linux_${YQ_ARCH}" \
        "" \
        "binary" "yq"

    # bun
    v=$(_ver bun); r=$(_released bun)
    _ensure "bun" "bun" "$v" "$r" \
        "https://github.com/oven-sh/bun/releases/download/bun-v${v}/bun-linux-${BUN_ARCH}.zip" \
        "https://github.com/oven-sh/bun/releases/download/bun-v${v}/SHASUMS256.txt" \
        "zip" "bun-linux-${BUN_ARCH}/bun"

    # atuin
    v=$(_ver atuin); r=$(_released atuin)
    _ensure "atuin" "atuin" "$v" "$r" \
        "https://github.com/atuinsh/atuin/releases/download/v${v}/atuin-${ARCH}-unknown-linux-musl.tar.gz" \
        "https://github.com/atuinsh/atuin/releases/download/v${v}/atuin-${ARCH}-unknown-linux-musl.tar.gz.sha256" \
        "tar" "atuin-${ARCH}-unknown-linux-musl/atuin"

    # zellij
    v=$(_ver zellij); r=$(_released zellij)
    _ensure "zellij" "zellij" "$v" "$r" \
        "https://github.com/zellij-org/zellij/releases/download/v${v}/zellij-${ARCH}-unknown-linux-musl.tar.gz" \
        "" "tar" "zellij"
fi

# Configure delta in git if installed
if command -v delta &>/dev/null || [[ -x "$HOME/.local/bin/delta" ]]; then
    git config --global core.pager "delta"
    git config --global interactive.diffFilter "delta --color-only"
    git config --global delta.navigate true
    git config --global delta.light false
    # zdiff3 needs Git >= 2.35; older git rejects the merge entirely
    _git_ver=$(git version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
    _git_major="${_git_ver%%.*}"
    _git_minor="${_git_ver#*.}"
    if [[ "${_git_major:-0}" -gt 2 ]] || { [[ "${_git_major:-0}" -eq 2 ]] && [[ "${_git_minor:-0}" -ge 35 ]]; }; then
        git config --global merge.conflictstyle zdiff3
    else
        git config --global merge.conflictstyle diff3
    fi
fi

# ============================================================================
# STEP 6: Bootstrap dotfiles (copy to ~/.dotfiles, write ~/.zshrc)
# ============================================================================
echo -e "\n\033[1;34m📂 STEP 6: Bootstrapping dotfiles...\033[0m\n"

if [[ "$DOTFILES_DIR" != "$TARGET_DIR" ]]; then
    echo "🚚 Copying dotfiles to $TARGET_DIR..."
    mkdir -p "$TARGET_DIR"
    rsync -a --delete --exclude='.git' "$DOTFILES_DIR/" "$TARGET_DIR/" 2>/dev/null \
        || (cd "$DOTFILES_DIR" && find . -path ./.git -prune -o -print | while read -r f; do
            if [[ -d "$f" ]]; then mkdir -p "$TARGET_DIR/$f"
            else cp -f "$f" "$TARGET_DIR/$f" 2>/dev/null || true; fi
        done)
    echo "  ✅ Dotfiles copied to $TARGET_DIR"
fi

# Ensure ~/.zshrc sources dotfiles
local_loader='[ -f "$HOME/.dotfiles/core/init.zsh" ] && source "$HOME/.dotfiles/core/init.zsh"'
touch "$HOME/.zshrc"
if ! grep -qF 'dotfiles/core/init.zsh' "$HOME/.zshrc" 2>/dev/null; then
    echo "" >> "$HOME/.zshrc"
    echo "# 🚀 Dotfiles loader" >> "$HOME/.zshrc"
    echo "$local_loader" >> "$HOME/.zshrc"
    echo "  ✅ Added dotfiles loader to ~/.zshrc"
else
    echo "  ✅ ~/.zshrc already sources dotfiles"
fi

# Deploy starship config
mkdir -p "$HOME/.config"
if [[ -f "$TARGET_DIR/config/starship.toml" ]]; then
    cp -f "$TARGET_DIR/config/starship.toml" "$HOME/.config/starship.toml"
    echo "  🎨 Deployed Starship config"
fi

# Deploy atuin config
if [[ -f "$TARGET_DIR/config/atuin.toml" ]]; then
    mkdir -p "$HOME/.config/atuin"
    cp -f "$TARGET_DIR/config/atuin.toml" "$HOME/.config/atuin/config.toml"
    echo "  📜 Deployed Atuin config (filter_mode = directory)"
fi

# Deploy zellij config & layouts
if [[ -d "$TARGET_DIR/config/zellij" ]]; then
    mkdir -p "$HOME/.config/zellij/layouts"
    [[ -f "$TARGET_DIR/config/zellij/config.kdl" ]] && cp -f "$TARGET_DIR/config/zellij/config.kdl" "$HOME/.config/zellij/config.kdl"
    [[ -d "$TARGET_DIR/config/zellij/layouts" ]] && cp -rf "$TARGET_DIR/config/zellij/layouts/." "$HOME/.config/zellij/layouts/"
    echo "  🪟 Deployed Zellij config & layouts"
fi

# Configure copy-on-select (terminal only — not global PRIMARY↔CLIPBOARD sync)
if [[ "$PLATFORM" == "macos" ]]; then
    defaults write com.googlecode.iterm2 CopySelection -bool true 2>/dev/null || true
    defaults write com.apple.Terminal CopyOnSelect -bool true 2>/dev/null || true
    echo "  📋 Configured macOS copy-on-select"
fi

# Reset tool cache
rm -f "$HOME/.cache/dotfiles_tools"

# ============================================================================
# STEP 7: Verify the install (fails loudly if a promised tool is missing)
# ============================================================================
echo -e "\n\033[1;34m🩺 STEP 7: Verifying installation...\033[0m"

DOCTOR="$TARGET_DIR/doctor.zsh"
[[ -f "$DOCTOR" ]] || DOCTOR="$DOTFILES_DIR/doctor.zsh"
if [[ -f "$DOCTOR" ]] && command -v zsh &>/dev/null; then
    if ! zsh "$DOCTOR"; then
        echo -e "\033[1;31m❌ Verification failed — some promised tools are missing (see above).\033[0m"
        echo -e "\033[1;33m   Fix the missing tools and re-run: bash install.sh --force\033[0m"
        exit 1
    fi
else
    echo -e "\033[1;33m  ⚠️  doctor.zsh not found — skipping verification.\033[0m"
fi

# ============================================================================
# DONE — launch zsh
# ============================================================================
echo -e "\n\033[1;36m=================================================================\033[0m"
echo -e "\033[1;32m  🎉 INSTALLATION COMPLETE!\033[0m"
echo -e "\033[1;36m=================================================================\033[0m"
echo ""
echo -e "  \033[1;33mNext steps:\033[0m"
echo -e "    1. Run \033[1;32mgit-setup\033[0m to configure git identity"
echo -e "    2. Run \033[1;32mssh-setup\033[0m to generate SSH keys"
echo ""

echo -e "\033[1;36m🐚 Launching zsh...\033[0m\n"
exec zsh --login
