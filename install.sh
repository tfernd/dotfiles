#!/usr/bin/env bash
# ============================================================================
# 🚀 DOTFILES BOOTSTRAP (bare-metal entry point)
# ============================================================================
# Usage (the repo loads in place: clone it anywhere, nothing is copied):
#   git clone <repo-url> ~/path/to/dotfiles
#   bash ~/path/to/dotfiles/install.sh [--force]
#   It appends the loader line to ~/.zshrc, at most once. An existing core/init.zsh
#   line, from any clone, is left alone.
#   --force  also reinstalls a tool whose installed version equals its pin.
#            It never downgrades: a newer installed version is always kept.
#   --no-shell  do not start a new zsh at the end.
#   --tools-only  only step 5, the pinned tools: no apt, no sudo, no doctor, no new shell
#                 (dotdoctor update --apply uses it).
# ============================================================================
set -euo pipefail

echo -e "\n\033[1;36m=================================================================\033[0m"
echo -e "\033[1;35m  🚀 DOTFILES BARE-METAL BOOTSTRAP\033[0m"
echo -e "\033[1;36m=================================================================\033[0m\n"

# The repo this script lives in. It is used in place: no copy is made.
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$REPO_DIR"

# The quarantine window in days: one number in <repo>/.freshness (update-versions.sh and dotdoctor read it too).
FRESH_DAYS=$(tr -dc '0-9' 2>/dev/null < "$DOTFILES_DIR/.freshness" || true)
[[ -n "$FRESH_DAYS" ]] || { echo "❌ $DOTFILES_DIR/.freshness is missing or holds no number of days"; exit 1; }

# Flags. Parsed with a loop (not "$@") so an empty argument list is safe under set -u.
FORCE=0
NO_SHELL=0
FAILED_TOOLS=()
TOOLS_ONLY=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --force) FORCE=1 ;;
        --no-shell) NO_SHELL=1 ;;
        --tools-only) TOOLS_ONLY=1; NO_SHELL=1 ;;
        *) echo "⚠️ Ignoring unknown option: $1" ;;
    esac
    shift
done

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

# Homebrew formulae for macOS: step 1 installs them, and so does --tools-only (brew provides
# most tools there).
BREW_FORMULAE=(
    zsh curl wget coreutils
    starship zoxide atuin zellij bat eza trash-cli yq xh fzf
    git git-delta jq bun hashicorp/tap/terraform hashicorp/tap/terraform-ls
    ripgrep fd just lazygit bottom yazi
    p7zip zip unzip xz zstd unar
    zsh-autosuggestions zsh-syntax-highlighting
)

# Steps 1 to 4 set up the system; --tools-only skips them.
if [[ "$TOOLS_ONLY" -eq 0 ]]; then
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
        brew install "${BREW_FORMULAE[@]}"
        brew install --cask font-fira-code-nerd-font 2>/dev/null || true

    else
        echo "📦 Updating APT package lists..."
        sudo apt update -y

        # deb822 .sources files (Pop!_OS, Ubuntu 24.04+) name components on a "Components:" line.
        _has_universe() { grep -Eqr '^(deb|Components:).*[[:space:]]universe([[:space:]]|$)' "$@" 2>/dev/null; }
        if command -v add-apt-repository &>/dev/null; then
            if ! _has_universe /etc/apt/sources.list /etc/apt/sources.list.d/; then
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
            xclip \
            p7zip-full \
            unzip \
            zip \
            gzip \
            tar \
            unrar-free \
            xz-utils \
            zstd \
            bzip2
        sudo apt install -y \
            zsh-autosuggestions \
            zsh-syntax-highlighting \
            2>/dev/null || echo "  ⚠️  zsh plugins not installed via apt (optional: Step 3 clones them)"

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
            echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null 2>&1 \
                || echo "  ⚠️  Could not add $ZSH_PATH to /etc/shells (needs sudo)"
        fi
        echo "  Setting $ZSH_PATH as default shell..."
        if sudo chsh -s "$ZSH_PATH" "$USER" 2>/dev/null || chsh -s "$ZSH_PATH" 2>/dev/null; then
            echo "  ✅ Default shell: zsh"
        else
            echo "  ⚠️  Could not set zsh as the default shell (optional). Run: chsh -s $ZSH_PATH"
        fi
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

    # FiraCode Nerd Font (Linux): download the zip into a temp dir, check it against the GitHub
    # release asset digest, then unzip. On failure: prints a ❌ line and returns 1 (set -e stops the run).
    _install_font() {
        local ver="$1" work zip release_path release_json digest expected actual
        work=$(mktemp -d "/tmp/firacode-XXXXXX") || { echo "    ❌ Cannot create temp dir for FiraCode"; return 1; }
        # Runs whenever this function returns, success or failure: removes the download.
        # Every fallible step below returns explicitly, so this trap fires on each failure path.
        trap 'rm -rf "$work"; trap - RETURN' RETURN
        zip="$work/FiraCode.zip"
        release_path="repos/ryanoasis/nerd-fonts/releases/tags/v${ver}"
        if command -v gh &>/dev/null && gh auth status &>/dev/null; then
            release_json=$(gh api "$release_path") \
                || { echo "    ❌ GitHub API lookup failed for FiraCode Nerd Font v${ver} (gh exit $?)"; return 1; }
        else
            release_json=$(curl -fsSL "https://api.github.com/${release_path}") \
                || { echo "    ❌ GitHub API lookup failed for FiraCode Nerd Font v${ver} (curl exit $?; rate limit? try: gh auth login)"; return 1; }
        fi
        digest=$(jq -r '.assets[] | select(.name == "FiraCode.zip") | .digest // empty' <<<"$release_json" 2>/dev/null) || digest=""
        if [[ "$digest" != sha256:* ]]; then
            echo "    ❌ No SHA256 digest for FiraCode Nerd Font v${ver}"
            return 1
        fi
        expected="${digest#sha256:}"
        curl -fsSL -o "$zip" "https://github.com/ryanoasis/nerd-fonts/releases/download/v${ver}/FiraCode.zip" \
            || { echo "    ❌ Download failed for FiraCode Nerd Font (curl exit $?)"; return 1; }
        actual=$(sha256sum "$zip" 2>/dev/null | awk '{print $1}') || actual=""
        if [[ -z "$actual" ]]; then
            actual=$(shasum -a 256 "$zip" 2>/dev/null | awk '{print $1}') || actual=""
        fi
        if [[ -z "$actual" ]]; then
            echo "    ❌ No sha256sum or shasum available to verify FiraCode Nerd Font"
            return 1
        fi
        if [[ "$expected" != "$actual" ]]; then
            echo "    ❌ CHECKSUM MISMATCH for FiraCode Nerd Font!"
            return 1
        fi
        mkdir -p "$HOME/.local/share/fonts" || { echo "    ❌ Cannot create ~/.local/share/fonts"; return 1; }
        unzip -qo "$zip" -d "$HOME/.local/share/fonts/" || { echo "    ❌ Unzip failed for FiraCode Nerd Font"; return 1; }
        # The font is in place even if the cache refresh fails, so this is a warning, not a failure.
        fc-cache -f "$HOME/.local/share/fonts/" 2>/dev/null \
            || echo "    ⚠️ fc-cache failed: the font may need a new login to show up"
        return 0
    }

    # The font is optional: the shell works without it, so a failure is a warning (⚠️), not a fatal error.
    if [[ "$PLATFORM" == "macos" ]]; then
        if brew install --cask font-fira-code-nerd-font; then
            echo "  ✅ FiraCode Nerd Font installed"
        else
            echo "  ⚠️  FiraCode Nerd Font not installed via Homebrew (optional): terminal icons may be missing"
        fi
    else
        if fc-list : family 2>/dev/null | grep -qi "FiraCode" || [[ -d "$HOME/.local/share/fonts" && $(find "$HOME/.local/share/fonts" -name "*FiraCode*" | head -1) ]]; then
            echo "  ✅ FiraCode Nerd Font already installed"
        else
            echo "  Downloading FiraCode Nerd Font v${FONT_VER}..."
            if _install_font "$FONT_VER"; then
                echo "  ✅ FiraCode Nerd Font v${FONT_VER} installed"
            else
                echo "  ⚠️  FiraCode Nerd Font v${FONT_VER} not installed (optional): terminal icons may be missing. See the ❌ line above."
            fi
        fi
    fi
    echo ""
fi

# ============================================================================
# STEP 5: Install pinned CLI tools (quarantine + checksum verified)
# uv, gh: Debian / WSL / macOS. Other tools: Linux binaries.
# ============================================================================
echo -e "\033[1;34m🔧 STEP 5: Installing pinned CLI tools...\033[0m\n"

mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

if [[ "$TOOLS_ONLY" -eq 1 && "$PLATFORM" == "macos" ]]; then
    brew install "${BREW_FORMULAE[@]}"
fi

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

    # Only [tools] and [fonts]: [fixes] and [osv] reuse the names (bun-brotli, uv).
    _ver() { awk '/^\[/{s = ($0 == "[tools]" || $0 == "[fonts]")} s' "$DOTFILES_DIR/versions.toml" | grep -E "^$1[[:space:]]*=" | sed -E 's/.*version = "([^"]+)".*/\1/'; }
    _released() { awk '/^\[/{s = ($0 == "[tools]" || $0 == "[fonts]")} s' "$DOTFILES_DIR/versions.toml" | grep -E "^$1[[:space:]]*=" | sed -E 's/.*released = "([^"]+)".*/\1/'; }

    # True (0) only when version $1 is strictly newer than $2, by sort -V. An empty version is never newer.
    _is_newer() {
        [[ -n "$1" && -n "$2" && "$1" != "$2" ]] || return 1
        [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n1)" == "$1" ]]
    }

    _github_digest() {
        local url="$1"
        local repo tag asset
        repo=$(echo "$url" | sed -E 's|https://github.com/([^/]+/[^/]+)/releases/download/.*|\1|')
        tag=$(echo "$url" | sed -E 's|https://github.com/[^/]+/[^/]+/releases/download/([^/]+)/.*|\1|')
        asset="${url##*/}"
        curl -fsSL "https://api.github.com/repos/${repo}/releases/tags/${tag}" \
            | jq -r --arg n "$asset" '.assets[] | select(.name == $n) | .digest // empty'
    }

    # Every fallible step returns 1 explicitly after a ❌ line. That keeps the exit status
    # visible (no silent set -e exit) and makes the RETURN trap run on each failure path.
    # A url "gh:<owner/repo>|<version>|<asset regex>" is looked up in the release's asset list, and
    # only when the tool is installed: projects name their files differently and tag with or without
    # a v, and the same JSON carries the SHA256 digest. Prints "<download url><TAB><digest or empty>".
    _resolve_gh_asset() {
        local spec="${1#gh:}" repo ver re tag json row
        IFS='|' read -r repo ver re <<<"$spec"
        for tag in "v${ver}" "${ver}"; do
            json=$(curl -fsSL "https://api.github.com/repos/${repo}/releases/tags/${tag}" 2>/dev/null) || continue
            row=$(jq -r --arg re "$re" '[.assets[]? | select(.name | test($re; "i"))] | .[0] // empty | [.browser_download_url, (.digest // "")] | @tsv' <<<"$json" 2>/dev/null) || continue
            if [[ -n "$row" ]]; then
                printf '%s\n' "$row"
                return 0
            fi
        done
        return 1
    }

    # Puts a file at ~/.local/bin/<name> through a temporary file and mv. cp onto a running binary
    # fails (text file busy), and cp onto a symlink writes through it into the file it points at.
    _place_bin() {
        local src="$1" name="$2" dest="$HOME/.local/bin/$2"
        cp -f "$src" "$dest.new" && chmod +x "$dest.new" && mv -f "$dest.new" "$dest" \
            || { rm -f "$dest.new"; echo "    ❌ Copy to ~/.local/bin failed for $name"; return 1; }
    }

    _install_bin() {
        local name="$1" url="$2" checksum_url="$3" extract_cmd="$4" binary_path="$5"
        local work
        work=$(mktemp -d "/tmp/${name}-XXXXXX") || { echo "    ❌ Cannot create temp dir for $name"; return 1; }
        # Runs whenever this function returns, success or failure: removes the download and extract tree.
        trap 'rm -rf "$work"; trap - RETURN' RETURN
        local tmpfile="$work/download" pre_digest=""
        if [[ "$url" == gh:* ]]; then
            local resolved
            resolved=$(_resolve_gh_asset "$url") || { echo "    ❌ No release asset found for $name (${url#gh:})"; return 1; }
            url="${resolved%%$'\t'*}"
            pre_digest="${resolved#*$'\t'}"
        fi
        curl -fsSL -o "$tmpfile" "$url" || { echo "    ❌ Download failed for $name (curl exit $?)"; return 1; }

        local expected=""
        if [[ -n "$checksum_url" ]]; then
            local sums
            sums=$(curl -fsSL "$checksum_url") || { echo "    ❌ Checksum download failed for $name (curl exit $?)"; return 1; }
            expected=$(awk -v n="${url##*/}" 'index($0, n) {print $1; exit}' <<<"$sums")
            [[ -z "$expected" ]] && expected=$(awk '{print $1; exit}' <<<"$sums")
        else
            local digest="$pre_digest"
            if [[ -z "$digest" ]]; then
                digest=$(_github_digest "$url") \
                    || { echo "    ❌ GitHub API lookup failed for $name (curl exit $?; rate limit? try: gh auth login)"; return 1; }
            fi
            [[ "$digest" == sha256:* ]] && expected="${digest#sha256:}"
        fi
        if [[ -z "$expected" ]]; then
            echo "    ❌ No SHA256 available for $name"
            return 1
        fi
        local actual=""
        actual=$(sha256sum "$tmpfile" 2>/dev/null | awk '{print $1}') || actual=""
        if [[ -z "$actual" ]]; then
            actual=$(shasum -a 256 "$tmpfile" 2>/dev/null | awk '{print $1}') || actual=""
        fi
        if [[ -z "$actual" ]]; then
            echo "    ❌ No sha256sum or shasum available to verify $name"
            return 1
        fi
        if [[ "$expected" != "$actual" ]]; then
            echo "    ❌ CHECKSUM MISMATCH for $name!"
            return 1
        fi

        case "$extract_cmd" in
            tar)
                local extract_dir="$work/extract"
                mkdir -p "$extract_dir" || { echo "    ❌ Cannot create extract dir for $name"; return 1; }
                tar xzf "$tmpfile" -C "$extract_dir" || { echo "    ❌ Extract failed for $name (tar)"; return 1; }
                local bin_src="$extract_dir/${binary_path}"
                [[ -f "$bin_src" ]] || bin_src=$(find "$extract_dir" -name "${binary_path##*/}" -type f 2>/dev/null | head -1) || true
                [[ -n "$bin_src" && -f "$bin_src" ]] || { echo "    ❌ ${binary_path} not found in the $name archive"; return 1; }
                _place_bin "$bin_src" "$name" || return 1
                ;;
            zip)
                local tmpdir="$work/zip"
                mkdir -p "$tmpdir" || { echo "    ❌ Cannot create extract dir for $name"; return 1; }
                unzip -qo "$tmpfile" -d "$tmpdir" || { echo "    ❌ Unzip failed for $name"; return 1; }
                local bin_found=""
                bin_found=$(find "$tmpdir" -name "$name" -type f 2>/dev/null | head -1) || true
                [[ -z "$bin_found" ]] && bin_found=$(find "$tmpdir" -name "${binary_path##*/}" -type f 2>/dev/null | head -1) || true
                [[ -n "$bin_found" ]] || { echo "    ❌ $name binary not found in the archive"; return 1; }
                _place_bin "$bin_found" "$name" || return 1
                ;;
            binary)
                _place_bin "$tmpfile" "$name" || return 1
                ;;
            *)
                echo "    ❌ Unknown extract mode '$extract_cmd' for $name"
                return 1
                ;;
        esac
        chmod +x "$HOME/.local/bin/$name" || { echo "    ❌ chmod failed for $name"; return 1; }
        echo "    ✅ $name installed"
    }

    # Install policy (never downgrade). The copy in ~/.local/bin is the one that counts: it comes first
    # on PATH, so it is what runs. A copy from apt or Homebrew is not looked at (apt's gh would
    # otherwise keep a newer, unvetted release in place of the pin); dotdoctor clean lists such copies.
    #   no pin in versions.toml yet  -> skipped (update-versions.sh --apply adds the row)
    #   copy newer than the pin      -> kept, even with --force
    #   copy equal to the pin        -> skipped, or reinstalled with --force
    #   copy older, or missing       -> installed
    _ensure() {
        local name="$1" cmd="$2" pinned_ver="$3" released_date="$4"
        shift 4
        if [[ -z "$pinned_ver" ]]; then
            printf "  ⏳ %-12s no pin in versions.toml yet (bash update-versions.sh --apply adds it)\n" "$name"
            return 0
        fi
        _quarantined "$name" "$pinned_ver" "$released_date" || return 0

        local cmd_path=""
        [[ -x "$HOME/.local/bin/$cmd" ]] && cmd_path="$HOME/.local/bin/$cmd"

        if [[ -n "$cmd_path" ]]; then
            local installed_ver=$("$cmd_path" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+[0-9.]*' | head -1)
            if _is_newer "$installed_ver" "$pinned_ver"; then
                echo "  ⚠️ $name $installed_ver is newer than the pin $pinned_ver: kept (bump the pin when the release passes quarantine)"
                return 0
            fi
            if [[ "$installed_ver" == "$pinned_ver" && "$FORCE" -eq 0 ]]; then
                printf "  ✅ %-12s v%-10s (up to date)\n" "$name" "$installed_ver"
                return 0
            fi
        fi

        printf "  📦 %-12s installing v%s\n" "$name" "$pinned_ver"
        # One tool failing must not stop the others: it is listed at the end and the run exits 1.
        _install_bin "$name" "$@" || FAILED_TOOLS+=("$name")
    }

    # YYYY-MM-DD date FRESH_DAYS back (GNU, then BSD). A release is allowed when its date is <= this.
    _quarantine_cutoff() {
        date -d "-${FRESH_DAYS} days" +%F 2>/dev/null || date -v-"${FRESH_DAYS}"d +%F
    }

    _quarantined() {
        local name="$1" pinned_ver="$2" released_date="$3"
        if [[ -z "$released_date" ]]; then
            return 0
        fi
        local cutoff
        cutoff=$(_quarantine_cutoff)
        # Both sides are fixed-width YYYY-MM-DD, so string order is calendar order (no 86400 math).
        if [[ "$released_date" > "$cutoff" ]]; then
            echo "  ⏳ $name v$pinned_ver: in quarantine (released $released_date, cutoff $cutoff) — SKIPPING"
            return 1
        fi
        return 0
    }

    # An old source build in ~/.local/bin comes first on PATH and would hide the system git.
    _git_path=$(command -v git 2>/dev/null || true)
    if [[ "$_git_path" == "$HOME/.local/bin/git" ]]; then
        echo "  ❌ $_git_path is an old source build of git and hides the system git: remove it, then re-run install.sh"
        exit 1
    fi
    _git_ver_now=$(git --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+[0-9.]*' | head -1) || _git_ver_now=""
    if [[ -z "$_git_ver_now" ]]; then
        echo "  ❌ git is missing or not runnable (Step 1 should have installed it)"
        exit 1
    fi
    if [[ "$PLATFORM" == "macos" ]]; then
        printf "  ✅ %-12s v%-10s (via Homebrew)\n" "git" "$_git_ver_now"
    else
        printf "  ✅ %-12s v%-10s (via apt)\n" "git" "$_git_ver_now"
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

    # terraform: HashiCorp's release server, checked against its SHA256SUMS file
    v=$(_ver terraform); r=$(_released terraform)
    _ensure "terraform" "terraform" "$v" "$r" \
        "https://releases.hashicorp.com/terraform/${v}/terraform_${v}_linux_${YQ_ARCH}.zip" \
        "https://releases.hashicorp.com/terraform/${v}/terraform_${v}_SHA256SUMS" \
        "zip" "terraform"

    # terraform-ls: same server and checksum file as terraform
    v=$(_ver terraform-ls); r=$(_released terraform-ls)
    _ensure "terraform-ls" "terraform-ls" "$v" "$r" \
        "https://releases.hashicorp.com/terraform-ls/${v}/terraform-ls_${v}_linux_${YQ_ARCH}.zip" \
        "https://releases.hashicorp.com/terraform-ls/${v}/terraform-ls_${v}_SHA256SUMS" \
        "zip" "terraform-ls"

    # rg, fd, fzf, just, lazygit, btm, yazi: GitHub release assets, found by asset name regex
    # (gh:<repo>|<version>|<regex>) and checked against the digest GitHub lists for the asset.
    case "$ARCH" in
        x86_64)  RG_ASSET='ripgrep-[0-9.]+-x86_64-unknown-linux-musl\.tar\.gz$'; BTM_ASSET='bottom_x86_64-unknown-linux-musl\.tar\.gz$'; LG_ARCH="x86_64" ;;
        *)       RG_ASSET='ripgrep-[0-9.]+-aarch64-unknown-linux-gnu\.tar\.gz$'; BTM_ASSET='bottom_aarch64-unknown-linux-gnu\.tar\.gz$'; LG_ARCH="arm64" ;;
    esac
    v=$(_ver rg); r=$(_released rg)
    _ensure "rg" "rg" "$v" "$r" "gh:BurntSushi/ripgrep|${v}|${RG_ASSET}" "" "tar" "rg"
    v=$(_ver fd); r=$(_released fd)
    _ensure "fd" "fd" "$v" "$r" "gh:sharkdp/fd|${v}|fd-v[0-9.]+-${ARCH}-unknown-linux-musl\.tar\.gz\$" "" "tar" "fd"
    v=$(_ver fzf); r=$(_released fzf)
    _ensure "fzf" "fzf" "$v" "$r" "gh:junegunn/fzf|${v}|fzf-[0-9.]+-linux_${YQ_ARCH}\.tar\.gz\$" "" "tar" "fzf"
    v=$(_ver just); r=$(_released just)
    _ensure "just" "just" "$v" "$r" "gh:casey/just|${v}|just-[0-9.]+-${ARCH}-unknown-linux-musl\.tar\.gz\$" "" "tar" "just"
    v=$(_ver lazygit); r=$(_released lazygit)
    _ensure "lazygit" "lazygit" "$v" "$r" "gh:jesseduffield/lazygit|${v}|lazygit_[0-9.]+_Linux_${LG_ARCH}\.tar\.gz\$" "" "tar" "lazygit"
    v=$(_ver btm); r=$(_released btm)
    _ensure "btm" "btm" "$v" "$r" "gh:ClementTsang/bottom|${v}|${BTM_ASSET}" "" "tar" "btm"
    v=$(_ver yazi); r=$(_released yazi)
    _ensure "yazi" "yazi" "$v" "$r" "gh:sxyazi/yazi|${v}|yazi-${ARCH}-unknown-linux-musl\.zip\$" "" "zip" "yazi"
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

if [[ "$TOOLS_ONLY" -eq 1 ]]; then
    rm -f "$HOME/.cache/dotfiles_tools"
    if [[ ${#FAILED_TOOLS[@]} -gt 0 ]]; then
        echo -e "\n\033[1;31m❌ Not installed: ${FAILED_TOOLS[*]}\033[0m"
        exit 1
    fi
    echo -e "\n\033[1;32m✅ Pinned tools done.\033[0m Open a new shell (exec zsh) to use them."
    exit 0
fi

# ============================================================================
# STEP 6: Load dotfiles in place (no copy), append the ~/.zshrc loader, deploy configs
# ============================================================================
echo -e "\n\033[1;34m📂 STEP 6: Wiring dotfiles in place...\033[0m\n"

# Escapes $1 for use inside a double-quoted zsh string: \ " $ and backtick.
_dq_escape() { printf '%s' "$1" | sed -e 's/[\\"$`]/\\&/g'; }

# Appends the loader to ~/.zshrc, at most once. It only appends: ~/.zshrc is never rewritten or backed up.
# Any existing line that sources a .../core/init.zsh counts as installed, so nothing is appended then.
_ensure_zshrc_loader() {
    touch "$HOME/.zshrc" || { echo "  ❌ Cannot create or touch $HOME/.zshrc"; return 1; }
    if grep -qF 'core/init.zsh' "$HOME/.zshrc"; then
        echo "  ✅ ~/.zshrc already sources core/init.zsh"
        return 0
    fi
    local q
    q="$(_dq_escape "$REPO_DIR")"
    {
        echo ""
        echo "# 🚀 Dotfiles loader"
        echo "[ -f \"${q}/core/init.zsh\" ] && source \"${q}/core/init.zsh\""
    } >> "$HOME/.zshrc" || { echo "  ❌ Could not append the loader to $HOME/.zshrc"; return 1; }
    echo "  ✅ Added dotfiles loader to ~/.zshrc (sources $REPO_DIR/core/init.zsh)"
}
_ensure_zshrc_loader

# Deploy starship config (copied from the repo's config/ into ~/.config)
mkdir -p "$HOME/.config"
if [[ -f "$DOTFILES_DIR/config/starship.toml" ]]; then
    cp -f "$DOTFILES_DIR/config/starship.toml" "$HOME/.config/starship.toml"
    echo "  🎨 Deployed Starship config"
fi

# Deploy atuin config
if [[ -f "$DOTFILES_DIR/config/atuin.toml" ]]; then
    mkdir -p "$HOME/.config/atuin"
    cp -f "$DOTFILES_DIR/config/atuin.toml" "$HOME/.config/atuin/config.toml"
    echo "  📜 Deployed Atuin config (filter_mode = directory)"
fi

# Deploy zellij config & layouts
if [[ -d "$DOTFILES_DIR/config/zellij" ]]; then
    mkdir -p "$HOME/.config/zellij/layouts"
    [[ -f "$DOTFILES_DIR/config/zellij/config.kdl" ]] && cp -f "$DOTFILES_DIR/config/zellij/config.kdl" "$HOME/.config/zellij/config.kdl"
    [[ -d "$DOTFILES_DIR/config/zellij/layouts" ]] && cp -rf "$DOTFILES_DIR/config/zellij/layouts/." "$HOME/.config/zellij/layouts/"
    echo "  🪟 Deployed Zellij config & layouts"
fi

# Configure copy-on-select (terminal only — not global PRIMARY↔CLIPBOARD sync)
if [[ "$PLATFORM" == "macos" ]]; then
    _cos_ok=1
    defaults write com.googlecode.iterm2 CopySelection -bool true 2>/dev/null || _cos_ok=0
    defaults write com.apple.Terminal CopyOnSelect -bool true 2>/dev/null || _cos_ok=0
    if [[ "$_cos_ok" -eq 1 ]]; then
        echo "  📋 Configured macOS copy-on-select"
    else
        echo "  ⚠️ Could not set macOS copy-on-select (optional): set it in your terminal's preferences"
    fi
fi

# Reset tool cache
rm -f "$HOME/.cache/dotfiles_tools"

# ============================================================================
# STEP 7: Verify the install (fails loudly if a promised tool is missing)
# ============================================================================
echo -e "\n\033[1;34m🩺 STEP 7: Verifying installation...\033[0m"

DOCTOR="$DOTFILES_DIR/doctor.zsh"
if [[ -f "$DOCTOR" ]] && command -v zsh &>/dev/null; then
    if ! zsh "$DOCTOR"; then
        echo -e "\033[1;31m❌ Verification failed — some promised tools are missing (see above).\033[0m"
        echo -e "\033[1;33m   Fix the missing tools and re-run: bash install.sh --force\033[0m"
        exit 1
    fi
else
    echo -e "\033[1;33m  ⚠️  doctor.zsh not found — skipping verification.\033[0m"
fi

if [[ ${#FAILED_TOOLS[@]} -gt 0 ]]; then
    echo -e "\n\033[1;31m❌ Not installed: ${FAILED_TOOLS[*]}\033[0m"
    exit 1
fi

# ============================================================================
# DONE — launch zsh
# ============================================================================
echo -e "\n\033[1;36m=================================================================\033[0m"
echo -e "\033[1;32m  🎉 INSTALLATION COMPLETE!\033[0m"
echo -e "\033[1;36m=================================================================\033[0m"
echo ""
if [[ "$NO_SHELL" -eq 1 ]]; then
    exit 0
fi
echo -e "  \033[1;33mNext steps:\033[0m"
echo -e "    1. Run \033[1;32mgit-setup\033[0m to configure git identity"
echo -e "    2. Run \033[1;32mssh-setup\033[0m to generate SSH keys"
echo ""
echo -e "\033[1;36m🐚 Launching zsh...\033[0m\n"
exec zsh --login
