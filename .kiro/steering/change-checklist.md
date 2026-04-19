---
inclusion: fileMatch
fileMatchPattern: "modules/*,plugins/*,core/*,platform/*,init.sh,install.sh"
---

# Change Checklist — MANDATORY for Every Modification

When adding, editing, or removing any command, alias, or function in this dotfiles repo, you MUST complete ALL applicable items below.

## Before Writing Code

- [ ] Read the existing file to understand its structure and patterns
- [ ] Check `plugins/tool-cache.sh` — does the feature need a `HAS_*` flag?

## Cross-Platform Compatibility

- [ ] **macOS** (Zsh + Bash): Does it use GNU or BSD flags? (`stat -c` vs `stat -f`, `ls --color` vs `ls -G`)
- [ ] **Linux** (Zsh + Bash): Does it need `sudo`? APT package name?
- [ ] **WSL**: Does it need WSL-specific handling? Check `IS_WSL`

## Documentation Updates

- [ ] Update `modules/help.sh` — add/update `print_cmd` entry in the correct category
- [ ] Update `README.md` — add/update the command in the Terminal Inventory section
- [ ] If configurable, document the env var in `custom.example.sh`

## Installation

- [ ] If a new external tool is required, add to:
  - `install.sh` (macOS brew + Linux apt/brew sections)
  - `plugins/tool-cache.sh` (add `HAS_*` flag)
  - `install.sh` `REQUIRED_TOOLS` array (if mandatory)

## Testing

- [ ] Add to `test/suite.sh` — `assert_defined` for existence check
- [ ] Add functional test if the command has testable behavior
- [ ] Add mock to `test/mock_tools.sh` if the command depends on external tools
- [ ] Run `bash test/suite.sh` and verify 0 failures

## Security

- [ ] Destructive operations MUST have confirmation prompts (`read -r confirm`)
- [ ] Never use `rm` directly — always map to trash
- [ ] Never store secrets in shell files — use `envup` pattern
- [ ] Quote all variables in command arguments to prevent injection
