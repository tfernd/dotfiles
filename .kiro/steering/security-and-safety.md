---
inclusion: fileMatch
fileMatchPattern: "modules/*,plugins/*,core/*,platform/*,init.sh,install.sh"
---

# Security & Safety Rules

## Least Privilege

- Never run `sudo` in aliases or functions without explicit user confirmation
- `install.sh` uses `sudo` only for APT operations — never for user-level config
- The `please` alias is interactive-only and Linux/macOS-only

## Destructive Operations

All destructive operations MUST have confirmation prompts:

```bash
echo -n "Proceed? (y/N): "
read -r confirm
if [[ "$confirm" =~ ^[yY] ]]; then
    # execute
fi
```

Currently protected: `gu` (undo), `gam` (amend), `gpf` (force push), `gr` (redo), `hclear` (history wipe)

## Trash Safety Model

- `rm` and `del` ALWAYS map to trash (never permanent delete)
- If `trash-put` (Linux) or `trash` (macOS) is available → use it
- Fallback: `rm -i` (interactive confirmation)
- AI Terminal: `rm`/`del` → trash is the ONLY delete operation available

## AI Terminal Sandbox

The AI terminal is a restricted environment. It MUST NOT have access to:

- Git write operations (commit, push, reset, amend)
- GitHub/PR operations
- System installers (`setup-terminal`, `install.sh`)
- Secret loading (`envup`)
- Process management (`kill-port`, `daemonize`)
- Network discovery (`myip`, `localip`)
- Privilege escalation (`please`, `sudo`)
- Clipboard access (`copy`, `cpwd`)

## Variable Quoting

Always quote variables in command arguments:

```bash
# GOOD
local dest="${1}.bak"
cp -r "$1" "$dest"

# BAD — command injection risk
cp -r $1 $dest
```

## Path Safety

- `_path_add` checks directory existence before adding to PATH
- `_path_clean` deduplicates PATH entries
- Never add user-controlled paths without validation

## Secrets

- Never store tokens, passwords, or API keys in shell files
- Use `envup` to load `.env` files into the session
- `.env` files should be in `.gitignore`
- `DOTFILES_NOTES_FILE` and other config vars are safe (paths, not secrets)
