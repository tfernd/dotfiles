# ============================================================================
# 🏁 DOTFILES TEST SUITE (zsh-only)
# ============================================================================

SCRIPT_DIR="$( cd "$( dirname "${(%):-%x}" )" && pwd )"
DOT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "🚀 Starting Dotfiles Test Suite (zsh-only)..."

# 1. Environment Simulation
export HOME="/tmp/dotfiles_test_home"
mkdir -p "$HOME/.cache"

# Load mocks BEFORE init so tool cache detects them
source "$SCRIPT_DIR/mock_tools.zsh"
export PATH="/tmp/dotfiles_mock_bin:$PATH"
rm -f "$HOME/.cache/dotfiles_tools"

# 2. Source the Loader
echo "📥 Sourcing core/init.zsh..."
source "$DOT_DIR/core/init.zsh"

# Re-ensure mocks take precedence
export PATH="/tmp/dotfiles_mock_bin:$PATH"

# 3. Validation Tests
test_passed=0
test_failed=0

function assert_defined() {
    if command -v "$1" >/dev/null 2>&1 || (( ${+functions[$1]} )) || alias "$1" >/dev/null 2>&1; then
        echo -e "  ✅ [PASSED] Defined: $1"
        ((test_passed++))
    else
        echo -e "  ❌ [FAILED] Missing: $1"
        ((test_failed++))
    fi
}

function assert_var() {
    local val="${(P)1}"
    if [[ -n "$val" ]]; then
        echo -e "  ✅ [PASSED] Variable: $1=$val"
        ((test_passed++))
    else
        echo -e "  ❌ [FAILED] Variable not set: $1"
        ((test_failed++))
    fi
}

echo -e "\n🔍 Checking Platform Detection..."
assert_var DOTFILES_PLATFORM
assert_var IS_MAC
assert_var IS_LINUX
assert_var IS_WSL

echo -e "\n🔍 Checking Feature Flags..."
assert_var HAS_ZOXIDE
assert_var HAS_EZA
assert_var HAS_BAT
assert_var HAS_GH
assert_var HAS_UV
assert_var HAS_BUN
assert_var HAS_ATUIN
assert_var HAS_FZF
assert_var HAS_ZELLIJ

echo -e "\n🔍 Checking Zellij..."
assert_defined zj
assert_defined zja
assert_defined zjl
assert_defined zjs
assert_defined zjk
assert_defined zjd

echo -e "\n🔍 Checking File & Navigation..."
assert_defined ls
assert_defined ll
assert_defined lt
assert_defined lsh
assert_defined llh
assert_defined lth
assert_defined cat
assert_defined cd
assert_defined extract
assert_defined compress
assert_defined ..

echo -e "\n🔍 Checking Git Aliases & Tools..."
assert_defined gs
assert_defined gd
assert_defined ga
assert_defined gl
assert_defined gp
assert_defined gb
assert_defined gba
assert_defined gds
assert_defined pr
assert_defined prs
assert_defined gstat
assert_defined ghv

echo -e "\n🔍 Checking Network & System..."
assert_defined myip
assert_defined localip
assert_defined port
assert_defined kill-port
assert_defined sleep
assert_defined http
assert_defined copy
assert_defined cpwd
assert_defined df
assert_defined free
assert_defined reload
assert_defined x
assert_defined path
assert_defined please

echo -e "\n🔍 Checking Autoloaded Functions..."
assert_defined server
assert_defined git-setup
assert_defined ssh-setup
assert_defined c
assert_defined del
assert_defined rl
assert_defined rt
assert_defined empty-trash

echo -e "\n🧪 Functional: compress & extract"
touch "/tmp/data"
for ext in zip tar tar.gz tgz tar.bz2 tbz2 tar.xz txz tar.zst 7z gz bz2 xz zst Z; do
    archive="/tmp/test_arc.$ext"
    compress "$archive" "/tmp/data" >/dev/null 2>&1
    if [[ -f "$archive" ]]; then
        echo -e "  ✅ [PASSED] compress .$ext"
        ((test_passed++))
        rm -f "$archive"
    else
        echo -e "  ❌ [FAILED] compress .$ext"
        ((test_failed++))
    fi
done
rm -f "/tmp/data"

echo -e "\n🧪 Functional: Network"
myip >/dev/null 2>&1 && { echo -e "  ✅ [PASSED] myip"; ((test_passed++)); } || { echo -e "  ❌ [FAILED] myip"; ((test_failed++)); }
localip >/dev/null 2>&1 && { echo -e "  ✅ [PASSED] localip"; ((test_passed++)); } || { echo -e "  ❌ [FAILED] localip"; ((test_failed++)); }
port 8080 >/dev/null 2>&1 && { echo -e "  ✅ [PASSED] port"; ((test_passed++)); } || { echo -e "  ❌ [FAILED] port"; ((test_failed++)); }

echo -e "\n🧪 Functional: Git lifecycle"
GIT_ROOT="/tmp/test_git_repo"
command rm -rf "$GIT_ROOT" >/dev/null 2>&1
mkdir -p "$GIT_ROOT" && cd "$GIT_ROOT"
git init >/dev/null 2>&1
git config user.email "test@example.com"
git config user.name "Test User"
touch "base.txt"
git add "base.txt" >/dev/null 2>&1
git commit -m "initial" >/dev/null 2>&1
echo "change" >> "base.txt"

if eval "gs" | grep -q "base.txt"; then
    echo -e "  ✅ [PASSED] gs"
    ((test_passed++))
else
    echo -e "  ❌ [FAILED] gs"
    ((test_failed++))
fi

if eval "gd" | grep -q "+change"; then
    echo -e "  ✅ [PASSED] gd"
    ((test_passed++))
else
    echo -e "  ❌ [FAILED] gd"
    ((test_failed++))
fi

cd "$DOT_DIR"
command rm -rf "$GIT_ROOT" >/dev/null 2>&1

echo -e "\n📊 Results: $test_passed Passed, $test_failed Failed."
if (( test_failed > 0 )); then
    echo -e "\n🛑 FAILURE: $test_failed tests failed."
    exit 1
else
    echo -e "\n🎉 SUCCESS: All tests passed."
    exit 0
fi
