# ============================================================================
# 🏁 DOTFILES TEST SUITE (CI/CD)
# ============================================================================

# Support direct execution (cross-shell compatible)
if [ -n "$ZSH_VERSION" ]; then
    SCRIPT_DIR="$( cd "$( dirname "${(%):-%x}" )" && pwd )"
else
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
fi
DOT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "🚀 Starting Dotfiles Test Suite..."

# 1. Environment Simulation
[ -n "$BASH_VERSION" ] && shopt -s expand_aliases 2>/dev/null || true
export HOME="/tmp/dotfiles_test_home"
mkdir -p "$HOME/.cache"
source "$SCRIPT_DIR/mock_tools.sh"

# 2. Source the Loader
echo "📥 Sourcing init.sh..."
source "$DOT_DIR/init.sh"

# 3. Validation Tests
test_passed=0
test_failed=0

function assert_defined() {
    # Portable check for command, function, or alias
    if command -v "$1" >/dev/null 2>&1 || [ "$(type -t "$1" 2>/dev/null)" == "function" ] || alias "$1" >/dev/null 2>&1; then
        echo -e "  ✅ [PASSED] Function/Alias defined: $1"
        ((test_passed++))
    else
        echo -e "  ❌ [FAILED] Missing component: $1"
        ((test_failed++))
    fi
}

function assert_var() {
    local val
    if [ -n "$ZSH_VERSION" ]; then
        val="${(P)1}"
    else
        val="${!1}"
    fi

    if [ -n "$val" ]; then
        echo -e "  ✅ [PASSED] Variable set: $1=$val"
        ((test_passed++))
    else
        echo -e "  ❌ [FAILED] Variable not set: $1"
        ((test_failed++))
    fi
}

echo -e "\n🔍 Checking Core Variables..."
assert_var IS_MAC
assert_var IS_LINUX
assert_var IS_WIN
assert_var CURRENT_SHELL
assert_var HAS_ZOXIDE
assert_var HAS_FZF

echo -e "\n🔍 Checking Core Functions..."
assert_defined extract
assert_defined compress
assert_defined backup
assert_defined symlink
assert_defined port
assert_defined kill-port
assert_defined envup
assert_defined memhog

echo -e "\n🔍 Checking Aliases..."
assert_defined gs
assert_defined gl
assert_defined c
assert_defined ls

echo -e "\n📊 Test Results: $test_passed Passed, $test_failed Failed."

if [ $test_failed -gt 0 ]; then
    echo -e "\n🛑 CI/CD FAILURE: Critical components missing."
    exit 1
else
    echo -e "\n🎉 CI/CD SUCCESS: Environment is healthy."
    exit 0
fi
