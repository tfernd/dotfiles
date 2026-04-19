---
inclusion: auto
---

# Dotfiles Architecture & Conventions

This is a cross-platform shell dotfiles repo (macOS, Linux/Debian, WSL). Every change must respect the architecture below.

## Directory Structure

| Directory   | Purpose                                            | Load Order   |
| ----------- | -------------------------------------------------- | ------------ |
| `core/`     | Foundational: OS detection, PATH, history          | 1st (always) |
| `plugins/`  | Shell integrations: tool cache, zoxide, starship   | 2nd          |
| `modules/`  | Feature modules: git, network, dev, archives, etc. | 3rd          |
| `platform/` | OS-specific overrides: colors, GPG, paths          | 4th          |
| `test/`     | Test suite and mocks                               | Not loaded   |

## Load Order (init.sh)

1. `core/path-utils.sh` → `_path_add`, `_path_clean`
2. `core/os-detect.sh` → `IS_MAC`, `IS_LINUX`, `IS_WSL`, `CURRENT_SHELL`
3. `core/paths.sh` → Platform PATH entries, Homebrew
4. `core/history.sh` → History config
5. `plugins/tool-cache.sh` → `HAS_*` flags (always, cached)
6. `plugins/shell.sh` → Oh My Zsh, Starship
7. `plugins/zoxide.sh` → Smart `cd`
8. `modules/*.sh` → Feature modules
9. `platform/*.sh` → OS overrides

## Key Patterns

### Tool Detection

```bash
# plugins/tool-cache.sh exports HAS_* flags
if [ "$HAS_TOOL" = "true" ]; then
    alias cmd='tool_name'
fi
```

### Cross-Platform Branching

```bash
if [ "$IS_MAC" = "true" ]; then
    # macOS
elif [ "$IS_LINUX" = "true" ]; then
    # Linux (check IS_WSL for WSL-specific)
fi
```

### Function Definition

```bash
unalias name 2>/dev/null || true
function name() {
    # implementation
}
```

### Include Guards (expensive operations)

```bash
if [ "$_GUARD_LOADED" = "true" ]; then return; fi
_GUARD_LOADED=true
```
