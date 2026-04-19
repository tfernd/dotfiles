---
inclusion: fileMatch
fileMatchPattern: "test/*"
---

# Testing Guide

## Running Tests

```bash
bash test/suite.sh
```

## Test Architecture

### `test/suite.sh` — Test Suite

- Loads mocks BEFORE `init.sh` (so tool cache detects mock binaries)
- Tests: variable definitions, function availability, functional behavior

### `test/mock_tools.sh` — Mock Binaries

- Creates mock executables in `/tmp/dotfiles_mock_bin`
- Specialized mocks run BEFORE generic handlers (fzf, trash)
- Generic fallback: exit 0 for no-args (command -v check), echo mock output otherwise
- Archive mocks: create files for compress/extract tests

## Adding Tests for New Commands

### Existence check:

```bash
# In test/suite.sh
assert_defined my_command
```

### Functional test:

```bash
my_command some_arg >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "  ✅ [PASSED] my_command"
    ((test_passed++))
else
    echo -e "  ❌ [FAILED] my_command"
    ((test_failed++))
fi
```

### New external tool mock:

Add to the `TOOLS` array in `test/mock_tools.sh`. If it needs specialized behavior, add a `case` block in the specialized mocks section (BEFORE the generic handlers).

## Mock Loading Order

CRITICAL: Mocks must be loaded BEFORE `init.sh` so the tool cache detects them:

```bash
source "$SCRIPT_DIR/mock_tools.sh"
export PATH="/tmp/dotfiles_mock_bin:$PATH"
rm -f "$HOME/.cache/bashrc_tools"  # Force cache rebuild
source "$DOT_DIR/init.sh"
```
