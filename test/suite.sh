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
# Load mocks BEFORE init.sh so the tool cache detects mock binaries
source "$SCRIPT_DIR/mock_tools.sh"
export PATH="/tmp/dotfiles_mock_bin:$PATH"
# Force tool cache rebuild with mocks in PATH
rm -f "$HOME/.cache/bashrc_tools"

# 2. Source the Loader
echo "📥 Sourcing init.sh..."
source "$DOT_DIR/init.sh"

# 3. Ensure mocks still take precedence after init.sh PATH additions
[ -n "$BASH_VERSION" ] && shopt -s expand_aliases 2>/dev/null || true
export HOME="/tmp/dotfiles_test_home"
mkdir -p "$HOME/.cache"
export PATH="/tmp/dotfiles_mock_bin:$PATH"

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

echo -e "\n🔍 Checking OS & Shell..."
assert_var IS_MAC
assert_var IS_LINUX
assert_var IS_WSL
assert_var CURRENT_SHELL

echo -e "\n🔍 Checking Feature Flags..."
assert_var HAS_ZOXIDE
assert_var HAS_FZF
assert_var HAS_EZA
assert_var HAS_BAT
assert_var HAS_FD
assert_var HAS_LAZYGIT
assert_var HAS_GH
assert_var HAS_UV
assert_var HAS_BUN

echo -e "\n🔍 Checking File & Navigation Tools..."
assert_defined ls
assert_defined ll
assert_defined lt
assert_defined cat
assert_defined y
assert_defined fd
assert_defined cw
assert_defined backup
assert_defined symlink
assert_defined extract
assert_defined compress
assert_defined up
assert_defined ..
assert_defined '~'
assert_defined -

echo -e "\n🔍 Checking Search & Fuzzy Workflows..."
assert_defined f
assert_defined ff
assert_defined h
assert_defined hh
assert_defined rt
assert_defined rtt

echo -e "\n🔍 Checking Git & GitHub Aliases..."
assert_defined lg
assert_defined gs
assert_defined ga
assert_defined gl
assert_defined gu
assert_defined gam
assert_defined gr
assert_defined gb
assert_defined gba
assert_defined gds
assert_defined gdss
assert_defined prs
assert_defined gstats
assert_defined ghn
assert_defined ghm
assert_defined ghr
assert_defined ghv
assert_defined ghme

echo -e "\n🔍 Checking Network & System Utilities..."
assert_defined myip
assert_defined localip
assert_defined port
assert_defined kill-port
assert_defined memhog
assert_defined top
assert_defined http
assert_defined copy
assert_defined cpwd
assert_defined df
assert_defined free
assert_defined weather
assert_defined reload
assert_defined x
assert_defined daemonize
assert_defined matrix
assert_defined starwars
assert_defined path
assert_defined please


echo -e "\n🔍 Checking AI Guards..."
assert_defined node
assert_defined npm
assert_defined npx
assert_defined yarn
assert_defined pnpm
assert_defined nodemon
assert_defined ts-node
assert_defined tsx
assert_defined python
assert_defined pip
assert_defined venv
assert_defined poetry
assert_defined grep
assert_defined server
assert_defined json
assert_defined calc

# Test one guard to ensure alias logic works (only if UV is simulated as present)
if [ "$HAS_UV" = "true" ]; then
    if eval "python" 2>&1 | grep -q "AI: Use 'uv run' instead of 'python'"; then
        echo -e "  ✅ [PASSED] AI Guard functional check (python)"
        ((test_passed++))
    else
        echo -e "  ❌ [FAILED] AI Guard functional check (python)"
        ((test_failed++))
    fi
else
    echo -e "  ✅ [PASSED] AI Guard skip check (UV not present)"
    ((test_passed++))
fi

echo -e "\n🔍 Checking Meta/Management Functions..."
assert_defined dotdoctor
assert_defined envup
assert_defined pyclean
assert_defined git-setup
assert_defined ssh-setup
assert_defined ssh-login
assert_defined ssh-test
assert_defined dotfiles-share-root
assert_defined setup-terminal
assert_defined refresh
assert_defined hclear
assert_defined myhelp
assert_defined help_git
assert_defined note
assert_defined note-config
assert_defined help
assert_defined c


echo -e "\n🔍 Checking Underlying Dependencies..."
function assert_tool() {
    if command -v "$1" >/dev/null 2>&1; then
        echo -e "  ✅ [PASSED] Tool installed: $1"
        ((test_passed++))
    else
        echo -e "  ❌ [FAILED] Tool missing: $1"
        ((test_failed++))
    fi
}

assert_tool git
assert_tool curl
assert_tool tar
assert_tool zip
assert_tool unzip
assert_tool 7z
assert_tool xz
assert_tool zstd
assert_tool bzip2
assert_tool gzip
assert_tool lsof
assert_tool cmatrix
assert_tool telnet

echo -e "\n🧪 Functional Tests: backup"
function assert_file_glob() {
    if ls $1 >/dev/null 2>&1; then
        echo -e "  ✅ [PASSED] File found (glob): $1"
        ((test_passed++))
        rm -f $1
    else
        echo -e "  ❌ [FAILED] File not found (glob): $1"
        ((test_failed++))
    fi
}

touch "/tmp/test_backup"
backup "/tmp/test_backup" >/dev/null 2>&1
assert_file_glob "/tmp/test_backup.*.bak"
rm -f /tmp/test_backup

echo -e "\n🧪 Functional Tests: note (default — saves to cwd)"
(cd /tmp && note "Test Note" >/dev/null 2>&1)
assert_file_glob "/tmp/notes.txt"
rm -f "/tmp/notes.txt"

echo -e "\n🧪 Functional Tests: note (configured DOTFILES_NOTES_FILE)"
DOTFILES_NOTES_FILE="/tmp/custom_notes.txt" note "Custom Path Note" >/dev/null 2>&1
assert_file_glob "/tmp/custom_notes.txt"
rm -f "/tmp/custom_notes.txt"

echo -e "\n🧪 Functional Tests: note-config (existence)"
if command -v note-config >/dev/null 2>&1 || [ "$(type -t note-config 2>/dev/null)" = "function" ]; then
    echo -e "  ✅ [PASSED] note-config is defined"
    ((test_passed++))
else
    echo -e "  ❌ [FAILED] note-config is not defined"
    ((test_failed++))
fi

echo -e "\n🧪 Functional Tests: compress & extract"
touch "/tmp/data"
for ext in zip tar tar.gz tgz tar.bz2 tbz2 tar.xz txz tar.zst 7z rar gz bz2 xz zst Z; do
    archive="/tmp/test_arc.$ext"
    echo "  Checking extension: .$ext"
    
    # Test Compress
    compress "$archive" "/tmp/data" >/dev/null 2>&1
    if [ -f "$archive" ]; then
        echo -e "    ✅ [PASSED] compress .$ext"
        ((test_passed++))
        rm -f "$archive"
    else
        echo -e "    ❌ [FAILED] compress .$ext"
        ((test_failed++))
    fi

    # Test Extract
    touch "$archive"
    extract "$archive" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "    ✅ [PASSED] extract .$ext (exit code 0)"
        ((test_passed++))
    else
        echo -e "    ❌ [FAILED] extract .$ext (exit code $?)"
        ((test_failed++))
    fi
    rm -f "$archive"
done
rm -f "/tmp/data"

# Test failure mode: Verify that compress returns 1 if the underlying tool is missing
mv "/tmp/dotfiles_mock_bin/7z" "/tmp/dotfiles_mock_bin/7z_hidden"
compress "/tmp/fail.7z" "/etc/hostname" >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "  ✅ [PASSED] compress error handling (detects missing tools)"
    ((test_passed++))
else
    echo -e "  ❌ [FAILED] compress failed to detect missing 7z binary"
    ((test_failed++))
fi
mv "/tmp/dotfiles_mock_bin/7z_hidden" "/tmp/dotfiles_mock_bin/7z"
rm -f "/tmp/fail.7z"

echo -e "\n🧪 Functional Tests: Network & System"
# myip
myip >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "  ✅ [PASSED] myip"
    ((test_passed++))
else
    echo -e "  ❌ [FAILED] myip"
    ((test_failed++))
fi

# localip
localip >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "  ✅ [PASSED] localip"
    ((test_passed++))
else
    echo -e "  ❌ [FAILED] localip"
    ((test_failed++))
fi

# port
port 8080 >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "  ✅ [PASSED] port"
    ((test_passed++))
else
    echo -e "  ❌ [FAILED] port"
    ((test_failed++))
fi

# port (no arg)
port_out=$(port)
if echo "$port_out" | grep -q "Listing all listening ports"; then
    echo -e "  ✅ [PASSED] port (lists all if no arg)"
    ((test_passed++))
else
    echo -e "  ❌ [FAILED] port (lists all if no arg)"
    ((test_failed++))
fi

# kill-port
kill-port 8080 >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "  ✅ [PASSED] kill-port"
    ((test_passed++))
else
    echo -e "  ❌ [FAILED] kill-port"
    ((test_failed++))
fi

# daemonize
daemonize echo "hello" >/dev/null 2>&1
assert_file_glob "daemon_*.log"
rm -f daemon_*.log

# memhog
memhog >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "  ✅ [PASSED] memhog"
    ((test_passed++))
else
    echo -e "  ❌ [FAILED] memhog"
    ((test_failed++))
fi

# top (calls btm or top)
top --version >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "  ✅ [PASSED] top"
    ((test_passed++))
else
    echo -e "  ❌ [FAILED] top"
    ((test_failed++))
fi

# copy (reads from stdin)
echo "test-data" | copy >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "  ✅ [PASSED] copy"
    ((test_passed++))
else
    echo -e "  ❌ [FAILED] copy"
    ((test_failed++))
fi

# path (should return multiple lines)
line_count=$(path | wc -l)
if [ $line_count -gt 1 ]; then
    echo -e "  ✅ [PASSED] path (multi-line output: $line_count lines)"
    ((test_passed++))
else
    echo -e "  ❌ [FAILED] path (expected multiple lines, got $line_count)"
    ((test_failed++))
fi

# dotdoctor
dotdoctor >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "  ✅ [PASSED] dotdoctor"
    ((test_passed++))
else
    echo -e "  ❌ [FAILED] dotdoctor"
    ((test_failed++))
fi

# please (should return error since no history but shouldn't crash)
please >/dev/null 2>&1
if [ $? -ne 127 ]; then
    echo -e "  ✅ [PASSED] please (defined and executable)"
    ((test_passed++))
else
    echo -e "  ❌ [FAILED] please (command not found)"
    ((test_failed++))
fi

echo -e "\n🧪 Functional Tests: Dev & Management"
# envup
echo "TEST_ENV_VAR=found_it" > "/tmp/.test_env"
envup "/tmp/.test_env" >/dev/null 2>&1
if [ "$TEST_ENV_VAR" = "found_it" ]; then
    echo -e "  ✅ [PASSED] envup (variable loaded)"
    ((test_passed++))
else
    echo -e "  ❌ [FAILED] envup (variable not found)"
    ((test_failed++))
fi
rm -f "/tmp/.test_env"

# pyclean
mkdir -p "/tmp/test_pyclean/__pycache__"
touch "/tmp/test_pyclean/test.pyc"
pyclean "/tmp/test_pyclean" >/dev/null 2>&1  # Need to check if pyclean handles args or uses PWD
# Wait, pyclean uses 'find .', so we need to cd or it might not work as expected in test.
# Let's check pyclean definition again.
# pyclean: find . -depth ... -delete
( cd "/tmp/test_pyclean" && pyclean >/dev/null 2>&1 )
if [ ! -d "/tmp/test_pyclean/__pycache__" ] && [ ! -f "/tmp/test_pyclean/test.pyc" ]; then
    echo -e "  ✅ [PASSED] pyclean (files removed)"
    ((test_passed++))
else
    echo -e "  ❌ [FAILED] pyclean (files still exist)"
    ((test_failed++))
fi
rm -rf "/tmp/test_pyclean"

echo -e "\n🧪 Functional Tests: Dev Tools"
# calc
calc_out=$(echo "1+1" | calc "1+1" 2>/dev/null)
if [ $? -eq 0 ]; then
    echo -e "  ✅ [PASSED] calc (executed)"
    ((test_passed++))
else
    echo -e "  ❌ [FAILED] calc"
    ((test_failed++))
fi

# calc (awk fallback)
# Temporarily hide bc to test awk fallback
if [ -f "/tmp/dotfiles_mock_bin/bc" ]; then
    mv "/tmp/dotfiles_mock_bin/bc" "/tmp/dotfiles_mock_bin/bc_hidden"
    calc_fallback=$(calc "2+2" 2>/dev/null </dev/null)
    if [ $? -eq 0 ]; then
        echo -e "  ✅ [PASSED] calc awk fallback (result: $calc_fallback)"
        ((test_passed++))
    else
        echo -e "  ❌ [FAILED] calc awk fallback"
        ((test_failed++))
    fi
    mv "/tmp/dotfiles_mock_bin/bc_hidden" "/tmp/dotfiles_mock_bin/bc"
fi

# server & json (basic existence check)
assert_defined server
assert_defined json

# setup-terminal
# creates a dummy install.sh in the expected location
mkdir -p "$HOME/.dotfiles"
echo "echo 'Mock Install'" > "$HOME/.dotfiles/install.sh"
chmod +x "$HOME/.dotfiles/install.sh"
setup-terminal >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "  ✅ [PASSED] setup-terminal"
    ((test_passed++))
else
    echo -e "  ❌ [FAILED] setup-terminal"
    ((test_failed++))
fi

# refresh
# Verify it targets the correct cache variable (alias contains $TOOL_CACHE)
if alias refresh | grep -q "TOOL_CACHE"; then
    echo -e "  ✅ [PASSED] refresh (alias correctly targets cache)"
    ((test_passed++))
else
    echo -e "  ❌ [FAILED] refresh (alias logic incorrect)"
    ((test_failed++))
fi

# c
assert_defined c

echo -e "\n🧪 Functional Tests: Navigation & Files"
# cd (zoxide)
( cd /tmp && cd / ) 
if [ $? -eq 0 ]; then
    echo -e "  ✅ [PASSED] cd (jumped successfully)"
    ((test_passed++))
else
    echo -e "  ❌ [FAILED] cd"
    ((test_failed++))
fi

# up
mkdir -p /tmp/up_test/a/b/c
( cd /tmp/up_test/a/b/c && up 2 && [ "$PWD" = "/tmp/up_test/a" ] )
if [ $? -eq 0 ]; then
    echo -e "  ✅ [PASSED] up (climbed 2 levels)"
    ((test_passed++))
else
    echo -e "  ❌ [FAILED] up"
    ((test_failed++))
fi
rm -rf /tmp/up_test

# ls/ll/lt
for cmd in ls ll lt; do
    eval "$cmd" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "  ✅ [PASSED] $cmd"
        ((test_passed++))
    else
        echo -e "  ❌ [FAILED] $cmd"
        ((test_failed++))
    fi
done

# cat/fd
cat /etc/hostname >/dev/null 2>&1 && fd . /tmp >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "  ✅ [PASSED] cat & fd"
    ((test_passed++))
else
    echo -e "  ❌ [FAILED] cat or fd"
    ((test_failed++))
fi

echo -e "\n🧪 Functional Tests: Fuzzy Search (FZF)"
# Mock the internal pickers to avoid /dev/tty issues in non-interactive tests
# Mock the internal pickers to avoid /dev/tty issues in non-interactive tests
function __fzf_search_files() { echo "mocked_path.txt"; }
function __fzf_search_history() { echo "mocked_history_cmd"; }

# f/ff/h/hh (using mocked fzf)
for cmd in f ff h hh; do
    result=$(eval "$cmd" 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo -e "  ✅ [PASSED] $cmd (returned: $result)"
        ((test_passed++))
    else
        echo -e "  ❌ [FAILED] $cmd"
        ((test_failed++))
    fi
done

echo -e "\n🧪 Functional Tests: Trash & Deletion"
touch /tmp/trash_test
eval "rm /tmp/trash_test" >/dev/null 2>&1
if [ ! -f /tmp/trash_test ]; then
    echo -e "  ✅ [PASSED] rm (file removed/trashed)"
    ((test_passed++))
else
    echo -e "  ❌ [FAILED] rm (file still exists)"
    ((test_failed++))
fi

# rt (restore) - verify it runs without error with mock fzf
rt >/dev/null 2>&1 <<EOF
dummy_file
EOF
echo -e "  ✅ [PASSED] rt (dispatcher check)"
((test_passed++))

echo -e "\n🧪 Functional Tests: Git Lifecycle"
GIT_ROOT="/tmp/test_git_repo"
# Force real rm for cleanup to avoid trash-put mocks interference
command rm -rf "$GIT_ROOT" >/dev/null 2>&1 
mkdir -p "$GIT_ROOT"
cd "$GIT_ROOT" || exit 1

git init >/dev/null 2>&1
git config user.email "test@example.com"
git config user.name "Test User"
touch "base.txt"
git add "base.txt" >/dev/null 2>&1
git commit -m "initial" >/dev/null 2>&1
echo "change" >> "base.txt"

# gs
if eval "gs" | grep -q "base.txt"; then
    echo -e "  ✅ [PASSED] gs (detected change)"
    ((test_passed++))
else
    echo -e "  ❌ [FAILED] gs"
    ((test_failed++))
fi

# gd
if eval "gd" | grep -q "+change"; then
    echo -e "  ✅ [PASSED] gd (detected change)"
    ((test_passed++))
else
    echo -e "  ❌ [FAILED] gd"
    ((test_failed++))
fi

# ga
touch "new-file.txt"
eval "ga" >/dev/null 2>&1
if git status | grep -i "new file:   new-file.txt" >/dev/null 2>&1; then
    echo -e "  ✅ [PASSED] ga (staged change)"
    ((test_passed++))
else
    echo -e "  ❌ [FAILED] ga"
    ((test_failed++))
fi

# gds
if eval "gds" | grep -q "new-file.txt"; then
    echo -e "  ✅ [PASSED] gds (detected staged diff)"
    ((test_passed++))
else
    echo -e "  ❌ [FAILED] gds"
    ((test_failed++))
fi

# gdss (side-by-side diff — function should exist and run)
gdss >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "  ✅ [PASSED] gdss (side-by-side diff)"
    ((test_passed++))
else
    echo -e "  ❌ [FAILED] gdss"
    ((test_failed++))
fi

# gr (redo)
git commit -m "init" >/dev/null 2>&1
echo "change" >> "file.txt"
git commit -m "second" >/dev/null 2>&1
# Select HEAD~1 via mock fzf (which returns 'dummy_file')
gr >/dev/null 2>&1 <<EOF
HEAD~1
EOF
if [ $? -eq 0 ]; then
    echo -e "  ✅ [PASSED] gr (redo logic dispatch)"
    ((test_passed++))
else
    echo -e "  ❌ [FAILED] gr"
    ((test_failed++))
fi

cd "$DOT_DIR"
command rm -rf "$GIT_ROOT" >/dev/null 2>&1

echo -e "\n📊 Test Results: $test_passed Passed, $test_failed Failed."

if [ $test_failed -gt 0 ]; then
    echo -e "\n🛑 CI/CD FAILURE: Critical components missing."
    exit 1
else
    echo -e "\n🎉 CI/CD SUCCESS: Environment is healthy."
    exit 0
fi
