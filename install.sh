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
# Output: one line per step, detail lines only for an action or a problem. NO_COLOR or a
# piped stdout turns colour off.
# ============================================================================
set -euo pipefail

SECONDS=0
STEP_TOTAL=7

# Colour only on a terminal, and never with NO_COLOR set.
if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-dumb}" != dumb ]]; then
    USE_COLOR=1
    C_CYN=$'\033[1;36m' C_GRN=$'\033[1;32m' C_YEL=$'\033[1;33m' C_RED=$'\033[1;31m'
    C_MAG=$'\033[1;35m' C_DIM=$'\033[38;5;244m' C_RST=$'\033[0m'
else
    USE_COLOR=0
    C_CYN="" C_GRN="" C_YEL="" C_RED="" C_MAG="" C_DIM="" C_RST=""
fi

# The repo this script lives in. It is used in place: no copy is made.
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$REPO_DIR"

# The quarantine window in days: one number in <repo>/.freshness (update-versions.sh and dotdoctor read it too).
FRESH_DAYS=$(tr -dc '0-9' 2>/dev/null < "$DOTFILES_DIR/.freshness" || true)
[[ -n "$FRESH_DAYS" ]] || { echo "❌ $DOTFILES_DIR/.freshness is missing or holds no number of days"; exit 1; }

# YYYY-MM-DD date FRESH_DAYS back (GNU, then BSD). A release is allowed when its date is <= this.
_quarantine_cutoff() {
    date -d "-${FRESH_DAYS} days" +%F 2>/dev/null || date -v-"${FRESH_DAYS}"d +%F
}

# 0 when the release may be installed. A missing date fails closed: no date, no way to know its age.
_quarantined() {
    local name="$1" pinned_ver="$2" released_date="$3"
    if [[ -z "$released_date" ]]; then
        echo "  ⚠️ $name v$pinned_ver: no release date in versions.toml — SKIPPING"
        return 1
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

# --- Output helpers ---
# Counters for the final summary: packages and tools together.
N_INSTALLED=0 N_UPGRADED=0 N_UNCHANGED=0
STEP_NO="" STEP_NAME="" STEP_T0=0

_step_begin() { STEP_NO="$1" STEP_NAME="$2" STEP_T0=$SECONDS; }

# Prints "▸ [n/7] Name ....... <icon> text (Ns)". $1 is ok, warn or fail.
_step_end() {
    local icon="✅" col="$C_GRN" dots
    [[ "$1" == warn ]] && { icon="⚠️ "; col="$C_YEL"; }
    [[ "$1" == fail ]] && { icon="❌"; col="$C_RED"; }
    printf -v dots '%*s' "$(( 28 - ${#STEP_NAME} ))" ''
    dots="${dots// /.}"
    printf '%s▸ [%s/%s]%s %s %s%s%s %s %s%s%s %s(%ss)%s\n' \
        "$C_CYN" "$STEP_NO" "$STEP_TOTAL" "$C_RST" "$STEP_NAME" "$C_DIM" "$dots" "$C_RST" \
        "$icon" "$col" "$2" "$C_RST" "$C_DIM" "$(( SECONDS - STEP_T0 ))" "$C_RST"
}

# Runs a command with its output in a log; the log is shown only by _show_log (on failure).
RUN_LOG=""
_run_logged() {
    [[ -n "$RUN_LOG" ]] || RUN_LOG=$(mktemp "/tmp/dotfiles-install-XXXXXX")
    "$@" >"$RUN_LOG" 2>&1
}
_show_log() { [[ -s "$RUN_LOG" ]] && sed 's/^/    /' "$RUN_LOG" | tail -n 25 || true; }

_summary() {
    printf '%s  %d installed · %d upgraded · %d unchanged · %d failed%s   %s(%ss)%s\n' \
        "$C_DIM" "$N_INSTALLED" "$N_UPGRADED" "$N_UNCHANGED" "${#FAILED_TOOLS[@]}" "$C_RST" \
        "$C_DIM" "$SECONDS" "$C_RST"
}

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
_flags=""
[[ "$FORCE" -eq 1 ]] && _flags="$_flags --force"
[[ "$TOOLS_ONLY" -eq 1 ]] && _flags="$_flags --tools-only"
echo ""
printf '%s🚀 Dotfiles install%s  ·  platform: %s%s%s%s\n\n' "$C_MAG" "$C_RST" "$C_YEL" "$PLATFORM" "$C_RST" "$_flags"

# Homebrew formulae for macOS: step 1 installs them, and so does --tools-only (brew provides
# most tools there).
BREW_FORMULAE=(
    zsh curl wget coreutils
    starship zoxide atuin bat eza trash-cli fzf
    git git-delta jq bun hashicorp/tap/terraform hashicorp/tap/terraform-ls
    ripgrep fd just lazygit bottom yazi
    p7zip zip unzip xz zstd unar
    zsh-autosuggestions zsh-syntax-highlighting
)

# True when line $2 is in the newline-separated list $1.
_in_list() { [[ $'\n'"$1"$'\n' == *$'\n'"$2"$'\n'* ]]; }

# Installs the formulae of BREW_FORMULAE that brew does not list yet. brew's own chatter goes to a
# log, shown only on failure.
_brew_ensure() {
    local have f missing=()
    have=$(brew list --formula -1 2>/dev/null || true)
    for f in "${BREW_FORMULAE[@]}"; do
        if ! _in_list "$have" "${f##*/}"; then missing+=("$f"); fi
    done
    N_UNCHANGED=$(( N_UNCHANGED + ${#BREW_FORMULAE[@]} - ${#missing[@]} ))
    [[ ${#missing[@]} -gt 0 ]] || return 0
    echo "  📦 brew install: ${missing[*]}"
    if ! _run_logged brew install "${missing[@]}"; then
        _show_log
        echo "  ❌ brew install failed"
        return 1
    fi
    N_INSTALLED=$(( N_INSTALLED + ${#missing[@]} ))
}

# Steps 1 to 4 set up the system; --tools-only skips them.
if [[ "$TOOLS_ONLY" -eq 0 ]]; then
    # ============================================================================
    # STEP 1: System packages. Only what is missing is installed; apt update runs
    # only then, and only when the package lists are older than a day.
    # ============================================================================
    _step_begin 1 "System packages"

    # deb822 .sources files (Pop!_OS, Ubuntu 24.04+) name components on a "Components:" line.
    _has_universe() { grep -Eqr '^(deb|Components:).*[[:space:]]universe([[:space:]]|$)' "$@" 2>/dev/null; }

    # Prints the packages among "$@" that dpkg does not list as installed, one per line.
    _missing_pkgs() {
        local have p
        have=$(dpkg-query -W -f='${Package} ${Status}\n' "$@" 2>/dev/null | awk '$NF == "installed" {print $1}' || true)
        for p in "$@"; do
            if ! _in_list "$have" "$p"; then printf '%s\n' "$p"; fi
        done
    }

    # True when apt refreshed its lists within the last day.
    _apt_fresh() {
        [[ -n "$(find /var/lib/apt/periodic/update-success-stamp /var/cache/apt/pkgcache.bin \
            -mmin -1440 -print -quit 2>/dev/null || true)" ]]
    }

    _apt_update() {
        echo "  📦 apt update"
        _run_logged sudo apt-get update -qq || { _show_log; echo "  ❌ apt update failed"; return 1; }
    }

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

        _before=$N_INSTALLED
        _brew_ensure
        if [[ "$N_INSTALLED" -gt "$_before" ]]; then
            _step_end ok "$(( N_INSTALLED - _before )) installed via Homebrew"
        else
            _step_end ok "up to date"
        fi
    else
        REQUIRED_PKGS=(
            zsh git curl wget build-essential ca-certificates gnupg lsb-release procps lsof bc jq
            fontconfig xdg-utils trash-cli xclip p7zip-full unzip zip gzip tar unrar-free xz-utils zstd bzip2
        )
        PLUGIN_PKGS=(zsh-autosuggestions zsh-syntax-highlighting)
        WSL_PKGS=()
        [[ "$PLATFORM" == "wsl" ]] && WSL_PKGS=(wslu)

        _all_pkgs=("${REQUIRED_PKGS[@]}" "${PLUGIN_PKGS[@]}")
        [[ ${#WSL_PKGS[@]} -gt 0 ]] && _all_pkgs+=("${WSL_PKGS[@]}")
        _missing_all=()
        while IFS= read -r _p; do
            if [[ -n "$_p" ]]; then _missing_all+=("$_p"); fi
        done < <(_missing_pkgs "${_all_pkgs[@]}")

        # Which missing packages are required, and which belong to an optional group.
        _miss_req=() _miss_plug=() _miss_wsl=()
        if [[ ${#_missing_all[@]} -gt 0 ]]; then
            for _p in "${_missing_all[@]}"; do
                if _in_list "$(printf '%s\n' "${PLUGIN_PKGS[@]}")" "$_p"; then _miss_plug+=("$_p")
                elif [[ ${#WSL_PKGS[@]} -gt 0 ]] && _in_list "$(printf '%s\n' "${WSL_PKGS[@]}")" "$_p"; then _miss_wsl+=("$_p")
                else _miss_req+=("$_p"); fi
            done
        fi
        N_UNCHANGED=$(( N_UNCHANGED + ${#_all_pkgs[@]} - ${#_missing_all[@]} ))

        if [[ ${#_missing_all[@]} -eq 0 ]]; then
            _step_end ok "up to date (${#_all_pkgs[@]} packages)"
        else
            _need_update=0
            _apt_fresh || _need_update=1
            if command -v add-apt-repository &>/dev/null; then
                if ! _has_universe /etc/apt/sources.list /etc/apt/sources.list.d/; then
                    echo "  Enabling universe repository..."
                    sudo add-apt-repository -y universe 2>/dev/null || true
                    _need_update=1
                fi
            fi
            _updated=0
            if [[ "$_need_update" -eq 1 ]]; then _apt_update; _updated=1; fi

            # Installs "$@" quietly. A failure with lists not refreshed this run is retried once after apt update.
            _apt_install() {
                _run_logged sudo apt-get install -y -qq "$@" && return 0
                if [[ "$_updated" -eq 0 ]]; then
                    _apt_update || return 1
                    _updated=1
                    _run_logged sudo apt-get install -y -qq "$@" && return 0
                fi
                return 1
            }

            _step_warn=0
            if [[ ${#_miss_req[@]} -gt 0 ]]; then
                echo "  📦 apt install: ${_miss_req[*]}"
                if ! _apt_install "${_miss_req[@]}"; then
                    _show_log
                    _step_end fail "apt install failed"
                    exit 1
                fi
                N_INSTALLED=$(( N_INSTALLED + ${#_miss_req[@]} ))
            fi
            if [[ ${#_miss_plug[@]} -gt 0 ]]; then
                echo "  📦 apt install: ${_miss_plug[*]}"
                if _apt_install "${_miss_plug[@]}"; then
                    N_INSTALLED=$(( N_INSTALLED + ${#_miss_plug[@]} ))
                else
                    echo "  ⚠️  zsh plugins not installed via apt (optional: Step 3 clones them)"
                    _step_warn=1
                fi
            fi
            if [[ ${#_miss_wsl[@]} -gt 0 ]]; then
                echo "  📦 apt install: ${_miss_wsl[*]}"
                if _apt_install "${_miss_wsl[@]}"; then
                    N_INSTALLED=$(( N_INSTALLED + ${#_miss_wsl[@]} ))
                else
                    _step_warn=1
                fi
            fi
            if [[ "$_step_warn" -eq 1 ]]; then
                _step_end warn "installed, optional packages missing"
            else
                _step_end ok "${#_missing_all[@]} installed"
            fi
        fi
    fi

    # ============================================================================
    # STEP 2: Set zsh as default shell
    # ============================================================================
    _step_begin 2 "Default shell"

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
            _step_end ok "zsh is now the default shell"
        else
            echo "  ⚠️  Could not set zsh as the default shell (optional). Run: chsh -s $ZSH_PATH"
            _step_end warn "default shell unchanged"
        fi
    else
        _step_end ok "zsh is the default"
    fi

    # ============================================================================
    # STEP 3: Install Oh My Zsh + plugins
    # ============================================================================
    _step_begin 3 "Oh My Zsh"
    _omz_done=()

    if [[ ! -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]]; then
        echo "  Installing Oh My Zsh (pinned commit)..."
        OMZ_COMMIT="4b657407c98bbc8830ae66c2ac7ff3d737c55a83"  # 2026-08-29
        git clone -q --filter=blob:none https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
        # Full clone already fetched history; only fetch the pinned commit if it isn't present.
        (cd "$HOME/.oh-my-zsh" \
            && { git cat-file -e "${OMZ_COMMIT}^{commit}" 2>/dev/null || git fetch -q --depth=1 origin "$OMZ_COMMIT"; } \
            && git checkout -q --detach "$OMZ_COMMIT")
        OMZ_HEAD="$(git -C "$HOME/.oh-my-zsh" rev-parse HEAD)"
        if [[ "$OMZ_HEAD" != "$OMZ_COMMIT" ]]; then
            echo "❌ FATAL: Oh My Zsh HEAD is ${OMZ_HEAD}, expected ${OMZ_COMMIT}"
            exit 1
        fi
        _omz_done+=("Oh My Zsh ${OMZ_COMMIT:0:12}")
    fi

    ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
        echo "  Cloning zsh-autosuggestions..."
        git clone -q --depth=1 --branch v0.7.1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" 2>/dev/null || true
        _omz_done+=("zsh-autosuggestions")
    fi
    if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
        echo "  Cloning zsh-syntax-highlighting..."
        git clone -q --depth=1 --branch 0.8.0 https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" 2>/dev/null || true
        _omz_done+=("zsh-syntax-highlighting")
    fi
    if [[ ${#_omz_done[@]} -gt 0 ]]; then
        N_INSTALLED=$(( N_INSTALLED + ${#_omz_done[@]} ))
        _step_end ok "installed: ${_omz_done[*]}"
    else
        N_UNCHANGED=$(( N_UNCHANGED + 1 ))
        _step_end ok "up to date"
    fi

    # ============================================================================
    # STEP 4: Install Nerd Fonts
    # ============================================================================
    _step_begin 4 "FiraCode Nerd Font"

    _font_row=$(awk '/^\[/{s = ($0 == "[fonts]")} s' "$DOTFILES_DIR/versions.toml" | { grep -E '^firacode-nerd[[:space:]]*=' || true; })
    FONT_VER=$(sed -nE 's/.*version = "([^"]+)".*/\1/p' <<<"$_font_row")
    FONT_RELEASED=$(sed -nE 's/.*released = "([^"]+)".*/\1/p' <<<"$_font_row")
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
            release_json=$(curl --proto '=https' --tlsv1.2 -fsSL "https://api.github.com/${release_path}") \
                || { echo "    ❌ GitHub API lookup failed for FiraCode Nerd Font v${ver} (curl exit $?; rate limit? try: gh auth login)"; return 1; }
        fi
        digest=$(jq -r '.assets[] | select(.name == "FiraCode.zip") | .digest // empty' <<<"$release_json" 2>/dev/null) || digest=""
        if [[ "$digest" != sha256:* ]]; then
            echo "    ❌ No SHA256 digest for FiraCode Nerd Font v${ver}"
            return 1
        fi
        expected="${digest#sha256:}"
        curl --proto '=https' --tlsv1.2 -fsSL -o "$zip" "https://github.com/ryanoasis/nerd-fonts/releases/download/v${ver}/FiraCode.zip" \
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
        _casks=$(brew list --cask -1 2>/dev/null || true)
        if _in_list "$_casks" "font-fira-code-nerd-font"; then
            N_UNCHANGED=$(( N_UNCHANGED + 1 ))
            _step_end ok "already installed"
        elif _run_logged brew install --cask font-fira-code-nerd-font; then
            N_INSTALLED=$(( N_INSTALLED + 1 ))
            _step_end ok "installed"
        else
            _show_log
            echo "  ⚠️  FiraCode Nerd Font not installed via Homebrew (optional): terminal icons may be missing"
            _step_end warn "not installed (optional)"
        fi
    else
        _fonts=$(fc-list : family 2>/dev/null || true)
        if [[ "$_fonts" == *[Ff]ira[Cc]ode* ]] || [[ -d "$HOME/.local/share/fonts" && -n "$(find "$HOME/.local/share/fonts" -name "*FiraCode*" -print -quit)" ]]; then
            N_UNCHANGED=$(( N_UNCHANGED + 1 ))
            _step_end ok "already installed"
        else
            echo "  Downloading FiraCode Nerd Font v${FONT_VER}..."
            if _quarantined "FiraCode Nerd Font" "$FONT_VER" "$FONT_RELEASED" && _install_font "$FONT_VER"; then
                N_INSTALLED=$(( N_INSTALLED + 1 ))
                _step_end ok "v${FONT_VER} installed"
            else
                echo "  ⚠️  FiraCode Nerd Font v${FONT_VER} not installed (optional): terminal icons may be missing. See the ❌ line above."
                _step_end warn "not installed (optional)"
            fi
        fi
    fi
fi

# ============================================================================
# STEP 5: Install pinned CLI tools (quarantine + checksum verified)
# uv, gh: Debian / WSL / macOS. Other tools: Linux binaries.
# Tools already at their pin print nothing; installs run up to MAX_JOBS at a time.
# ============================================================================
_step_begin 5 "Pinned tools"

mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

if [[ "$TOOLS_ONLY" -eq 1 && "$PLATFORM" == "macos" ]]; then
    _brew_ensure
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
    _ver() { awk '/^\[/{s = ($0 == "[tools]" || $0 == "[fonts]")} s' "$DOTFILES_DIR/versions.toml" | { grep -E "^$1[[:space:]]*=" || true; } | sed -E 's/.*version = "([^"]+)".*/\1/'; }
    _released() { awk '/^\[/{s = ($0 == "[tools]" || $0 == "[fonts]")} s' "$DOTFILES_DIR/versions.toml" | { grep -E "^$1[[:space:]]*=" || true; } | sed -E 's/.*released = "([^"]+)".*/\1/'; }

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
        curl --proto '=https' --tlsv1.2 -fsSL "https://api.github.com/repos/${repo}/releases/tags/${tag}" \
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
            json=$(curl --proto '=https' --tlsv1.2 -fsSL "https://api.github.com/repos/${repo}/releases/tags/${tag}" 2>/dev/null) || continue
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
        rm -f "$dest.new"
        cp -f "$src" "$dest.new" && chmod +x "$dest.new" && mv -f "$dest.new" "$dest" \
            || { rm -f "$dest.new"; echo "    ❌ Copy to ~/.local/bin failed for $name"; return 1; }
    }

    # Runs in a background job (see _job_start): prints only ❌ lines, so its log is empty on success.
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
        curl --proto '=https' --tlsv1.2 -fsSL -o "$tmpfile" "$url" || { echo "    ❌ Download failed for $name (curl exit $?)"; return 1; }

        local expected=""
        if [[ -n "$checksum_url" ]]; then
            local sums
            sums=$(curl --proto '=https' --tlsv1.2 -fsSL "$checksum_url") || { echo "    ❌ Checksum download failed for $name (curl exit $?)"; return 1; }
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
                [[ ! -L "$bin_src" ]] || { echo "    ❌ ${binary_path} in the $name archive is a symlink, not a regular file"; return 1; }
                [[ -f "$bin_src" ]] || bin_src=$(find "$extract_dir" -name "${binary_path##*/}" -type f 2>/dev/null | head -1) || true
                [[ -n "$bin_src" && -f "$bin_src" && ! -L "$bin_src" ]] || { echo "    ❌ ${binary_path} not found in the $name archive"; return 1; }
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
    }

    # --- Parallel installs ---
    # Downloads are independent, so up to MAX_JOBS _install_bin runs go at once, each with its own log.
    # Results are reaped oldest first, so the lines print in the order the tools were asked for.
    # Each job is a full _install_bin: checksum, atomic _place_bin, ❌ lines. A job's exit status is its result.
    MAX_JOBS=4
    JOBDIR=""
    JOB_PID=() JOB_NAME=() JOB_KIND=() JOB_OLD=() JOB_VER=()
    JOB_N=0 JOB_HEAD=0

    # Waits for the oldest running job and prints its one-line result (the ❌ lines of its log on failure).
    _job_reap_one() {
        local i="$JOB_HEAD" rc=0 name
        name="${JOB_NAME[$i]}"
        wait "${JOB_PID[$i]}" || rc=$?
        JOB_HEAD=$(( i + 1 ))
        if [[ "$rc" -ne 0 ]]; then
            FAILED_TOOLS+=("$name")
            printf "  ❌ %-12s failed\n" "$name"
            cat "$JOBDIR/$name.log"
            return 0
        fi
        case "${JOB_KIND[$i]}" in
            new)
                N_INSTALLED=$(( N_INSTALLED + 1 ))
                printf "  📦 %-12s v%s installed\n" "$name" "${JOB_VER[$i]}" ;;
            force)
                N_UPGRADED=$(( N_UPGRADED + 1 ))
                printf "  🔁 %-12s v%s reinstalled\n" "$name" "${JOB_VER[$i]}" ;;
            *)
                N_UPGRADED=$(( N_UPGRADED + 1 ))
                printf "  ⬆️  %-12s v%s -> v%s\n" "$name" "${JOB_OLD[$i]:-?}" "${JOB_VER[$i]}" ;;
        esac
    }

    # $1 kind (new, upgrade, force), $2 installed version, $3 pinned version, then _install_bin's arguments.
    _job_start() {
        local kind="$1" old="$2" ver="$3" name="$4"
        shift 4
        if [[ -z "$JOBDIR" ]]; then JOBDIR=$(mktemp -d "/tmp/dotfiles-install-XXXXXX"); fi
        while [[ $(( JOB_N - JOB_HEAD )) -ge "$MAX_JOBS" ]]; do _job_reap_one; done
        ( _install_bin "$name" "$@" ) >"$JOBDIR/$name.log" 2>&1 &
        JOB_PID[JOB_N]=$! JOB_NAME[JOB_N]="$name" JOB_KIND[JOB_N]="$kind" JOB_OLD[JOB_N]="$old" JOB_VER[JOB_N]="$ver"
        JOB_N=$(( JOB_N + 1 ))
    }

    _jobs_finish() {
        while [[ "$JOB_HEAD" -lt "$JOB_N" ]]; do _job_reap_one; done
        if [[ -n "$JOBDIR" ]]; then rm -rf "$JOBDIR"; JOBDIR=""; fi
    }

    # Install policy (never downgrade). The copy in ~/.local/bin is the one that counts: it comes first
    # on PATH, so it is what runs. A copy from apt or Homebrew is not looked at (apt's gh would
    # otherwise keep a newer, unvetted release in place of the pin); dotdoctor clean lists such copies.
    #   no pin in versions.toml yet  -> skipped (update-versions.sh --apply adds the row)
    #   copy newer than the pin      -> kept, even with --force
    #   copy equal to the pin        -> skipped silently, or reinstalled with --force
    #   copy older, or missing       -> installed
    _ensure() {
        local name="$1" cmd="$2" pinned_ver="$3" released_date="$4"
        shift 4
        if [[ -z "$pinned_ver" ]]; then
            printf "  ⏳ %-12s no pin in versions.toml yet (bash update-versions.sh --apply adds it)\n" "$name"
            return 0
        fi
        _quarantined "$name" "$pinned_ver" "$released_date" || { N_UNCHANGED=$(( N_UNCHANGED + 1 )); return 0; }

        local cmd_path="" kind="new" installed_ver=""
        [[ -x "$HOME/.local/bin/$cmd" ]] && cmd_path="$HOME/.local/bin/$cmd"

        if [[ -n "$cmd_path" ]]; then
            installed_ver=$("$cmd_path" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+[0-9.]*' | head -1) || installed_ver=""
            if _is_newer "$installed_ver" "$pinned_ver"; then
                echo "  ⚠️ $name $installed_ver is newer than the pin $pinned_ver: kept (bump the pin when the release passes quarantine)"
                N_UNCHANGED=$(( N_UNCHANGED + 1 ))
                return 0
            fi
            if [[ "$installed_ver" == "$pinned_ver" ]]; then
                if [[ "$FORCE" -eq 0 ]]; then
                    N_UNCHANGED=$(( N_UNCHANGED + 1 ))
                    return 0
                fi
                kind="force"
            else
                kind="upgrade"
            fi
        fi

        # One tool failing must not stop the others: it is listed at the end and the run exits 1.
        _job_start "$kind" "$installed_ver" "$pinned_ver" "$name" "$@"
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
    N_UNCHANGED=$(( N_UNCHANGED + 1 ))

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

_jobs_finish

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

_tools_text="$N_INSTALLED installed · $N_UPGRADED upgraded · $N_UNCHANGED current"
if [[ ${#FAILED_TOOLS[@]} -gt 0 ]]; then
    _step_end fail "${#FAILED_TOOLS[@]} failed"
else
    _step_end ok "$_tools_text"
fi

if [[ "$TOOLS_ONLY" -eq 1 ]]; then
    rm -f "$HOME/.cache/dotfiles_tools"
    if [[ ${#FAILED_TOOLS[@]} -gt 0 ]]; then
        echo -e "\n${C_RED}❌ Not installed: ${FAILED_TOOLS[*]}${C_RST}"
        exit 1
    fi
    echo -e "\n${C_GRN}✅ Pinned tools done.${C_RST} Open a new shell (exec zsh) to use them."
    exit 0
fi

# ============================================================================
# STEP 6: Load dotfiles in place (no copy), append the ~/.zshrc loader, deploy configs
# ============================================================================
_step_begin 6 "Wiring dotfiles"
_wired=()

# Escapes $1 for use inside a double-quoted zsh string: \ " $ and backtick.
_dq_escape() { printf '%s' "$1" | sed -e 's/[\\"$`]/\\&/g'; }

# Appends the loader to ~/.zshrc, at most once. It only appends: ~/.zshrc is never rewritten or backed up.
# Any existing line that sources a .../core/init.zsh counts as installed, so nothing is appended then.
_ensure_zshrc_loader() {
    touch "$HOME/.zshrc" || { echo "  ❌ Cannot create or touch $HOME/.zshrc"; return 1; }
    if grep -qF 'core/init.zsh' "$HOME/.zshrc"; then
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
    _wired+=("~/.zshrc loader")
}
_ensure_zshrc_loader

# Copies a repo config to its place when it differs; $3 names it in the step line.
_deploy() {
    local src="$1" dest="$2" label="$3"
    [[ -f "$src" ]] || return 0
    mkdir -p "$(dirname "$dest")"
    if [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then
        return 0
    fi
    cp -f "$src" "$dest"
    _wired+=("$label")
}
_deploy "$DOTFILES_DIR/config/starship.toml" "$HOME/.config/starship.toml" "Starship config"
_deploy "$DOTFILES_DIR/config/atuin.toml" "$HOME/.config/atuin/config.toml" "Atuin config"

# Configure copy-on-select (terminal only — not global PRIMARY↔CLIPBOARD sync)
_cos_warn=0
if [[ "$PLATFORM" == "macos" ]]; then
    _cos_ok=1
    defaults write com.googlecode.iterm2 CopySelection -bool true 2>/dev/null || _cos_ok=0
    defaults write com.apple.Terminal CopyOnSelect -bool true 2>/dev/null || _cos_ok=0
    if [[ "$_cos_ok" -eq 0 ]]; then
        echo "  ⚠️ Could not set macOS copy-on-select (optional): set it in your terminal's preferences"
        _cos_warn=1
    fi
fi

# Reset tool cache
rm -f "$HOME/.cache/dotfiles_tools"

if [[ "$_cos_warn" -eq 1 ]]; then
    _step_end warn "wired, copy-on-select not set"
elif [[ ${#_wired[@]} -gt 0 ]]; then
    _step_end ok "updated: ${_wired[*]}"
else
    _step_end ok "up to date"
fi

# ============================================================================
# STEP 7: Verify the install (fails loudly if a promised tool is missing)
# ============================================================================
_step_begin 7 "Verification"

DOCTOR="$DOTFILES_DIR/doctor.zsh"
if [[ -f "$DOCTOR" ]] && command -v zsh &>/dev/null; then
    _doc_rc=0
    _doc_env=()
    [[ "$USE_COLOR" -eq 0 ]] && _doc_env=(NO_COLOR=1)
    _doc_out=$(env ${_doc_env[@]+"${_doc_env[@]}"} zsh "$DOCTOR" --quiet 2>&1) || _doc_rc=$?
    if [[ "$_doc_rc" -ne 0 ]]; then
        printf '%s\n' "$_doc_out"
        _step_end fail "doctor found missing items"
        echo -e "${C_YEL}   Fix the missing tools and re-run: bash install.sh --force${C_RST}"
        exit 1
    fi
    # Warnings stay visible; the doctor's own last line is the pass line.
    printf '%s\n' "$_doc_out" | sed '$d'
    _step_end ok "doctor: all required checks passed"
else
    echo -e "${C_YEL}  ⚠️  doctor.zsh not found — skipping verification.${C_RST}"
    _step_end warn "skipped"
fi

if [[ -n "$RUN_LOG" ]]; then rm -f "$RUN_LOG"; fi

echo ""
_summary
if [[ ${#FAILED_TOOLS[@]} -gt 0 ]]; then
    echo -e "\n${C_RED}❌ Not installed: ${FAILED_TOOLS[*]}${C_RST}"
    exit 1
fi

# ============================================================================
# DONE — launch zsh
# ============================================================================
echo ""
echo -e "${C_CYN}┏━ ${C_GRN}🎉 Dotfiles ready${C_CYN} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RST}"
echo -e "${C_CYN}┃${C_RST}  1. ${C_GRN}git-setup${C_RST}  configure your git identity"
echo -e "${C_CYN}┃${C_RST}  2. ${C_GRN}ssh-setup${C_RST}  generate SSH keys"
echo -e "${C_CYN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RST}"
echo ""
if [[ "$NO_SHELL" -eq 1 ]]; then
    exit 0
fi
echo -e "${C_CYN}🐚 Launching zsh...${C_RST}\n"
exec zsh --login
