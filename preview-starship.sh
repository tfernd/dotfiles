#!/usr/bin/env bash
# ============================================================================
# Starship prompt gallery: renders the prompt in common states, in colour.
# Usage: preview.sh [--config FILE] [--only STATE] [--list] [--help]
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/../config/starship.toml"
[[ -f "$CONFIG" ]] || CONFIG="$SCRIPT_DIR/config/starship.toml"
ONLY=""
STATES=(plain clean dirty sync detached merge rebase failed slow jobs node python rust longpath)

usage() {
    cat <<USAGE
Usage: preview.sh [--config FILE] [--only STATE] [--list] [--help]
  --config FILE   starship.toml to preview (default: the repo's config/starship.toml)
  --only STATE    render one state; --list prints the names
Builds a throwaway repo in a temp dir; touches no real repo, no ~/.config, no network.
USAGE
}

while (( $# > 0 )); do
    case "$1" in
        --config) [[ $# -ge 2 ]] || { echo "❌ --config needs a file" >&2; exit 1; }; CONFIG="$2"; shift 2 ;;
        --only)   [[ $# -ge 2 ]] || { echo "❌ --only needs a state" >&2; exit 1; }; ONLY="$2"; shift 2 ;;
        --list)   printf '%s\n' "${STATES[@]}"; exit 0 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "❌ unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
done

command -v starship >/dev/null 2>&1 || { echo "❌ starship not on PATH" >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "❌ git not on PATH" >&2; exit 1; }
[[ -f "$CONFIG" ]] || { echo "❌ missing config: $CONFIG" >&2; exit 1; }
CONFIG="$(cd "$(dirname "$CONFIG")" && pwd)/$(basename "$CONFIG")"
if [[ -n "$ONLY" ]]; then
    ok=false
    for s in "${STATES[@]}"; do [[ "$s" == "$ONLY" ]] && ok=true; done
    [[ "$ok" == true ]] || { echo "❌ unknown state: $ONLY (see --list)" >&2; exit 1; }
fi

COLS="$(tput cols 2>/dev/null || true)"
[[ "$COLS" =~ ^[0-9]+$ ]] || COLS=100
(( COLS > 120 )) && COLS=120

T="$(mktemp -d "${TMPDIR:-/tmp}/starship-preview.XXXXXX")"
trap 'rm -rf "$T"' EXIT

# Isolated git: no global config, no owner identity, no network.
export HOME="$T/home"
mkdir -p "$HOME"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=preview GIT_AUTHOR_EMAIL=preview@example.test
export GIT_COMMITTER_NAME=preview GIT_COMMITTER_EMAIL=preview@example.test
export GIT_TERMINAL_PROMPT=0
export STARSHIP_CONFIG="$CONFIG" STARSHIP_CACHE="$T/cache"
unset VIRTUAL_ENV CONDA_DEFAULT_ENV STARSHIP_SHELL

g() { git -c advice.detachedHead=false -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }

# A repo with a bare origin and two branches that conflict on conflict.txt.
mkrepo() {
    local name="$1"
    g init -q -b main "$T/seed-$name"
    ( cd "$T/seed-$name"
      echo base > base.txt; echo main > conflict.txt; echo r > ren.txt
      g add . && g commit -qm base && g tag -a v1.2.0 -m release
      echo next > next.txt; g add next.txt; g commit -qm next )
    g clone -q --bare "$T/seed-$name" "$T/origin-$name.git"
    g clone -q "$T/origin-$name.git" "$T/$name" 2>/dev/null
    ( cd "$T/$name"
      g checkout -q -b feature && echo feature > conflict.txt && g commit -qam feature
      g checkout -q main )
}

for n in clean dirty sync detached merge rebase; do mkrepo "$n"; done
mkdir -p "$T/plain"

( cd "$T/dirty"
  echo x >> base.txt; g stash -q
  echo staged >> base.txt; g add base.txt
  echo mod >> conflict.txt; echo new > new.txt; g rm -q ren.txt )

( cd "$T/sync"
  echo a > ahead.txt; g add ahead.txt; g commit -qm ahead
  g clone -q "$T/origin-sync.git" "$T/other"
  cd "$T/other"; echo b > behind.txt; g add behind.txt; g commit -qm behind; g push -q origin main
  cd "$T/sync"; g fetch -q )

( cd "$T/detached"; g checkout -q --detach v1.2.0 )

( cd "$T/merge"; echo m2 > conflict.txt; g commit -qam m2; g merge feature >/dev/null 2>&1 || true )
( cd "$T/rebase"; echo m2 > conflict.txt; g commit -qam m2; g checkout -q feature; g rebase main >/dev/null 2>&1 || true )

mkdir -p "$T/proj/node" "$T/proj/python" "$T/proj/rust"
echo '{"name":"demo","version":"1.0.0"}' > "$T/proj/node/package.json"
printf '[project]\nname = "demo"\nversion = "0.1.0"\n' > "$T/proj/python/pyproject.toml"
printf '[package]\nname = "demo"\nversion = "0.1.0"\n' > "$T/proj/rust/Cargo.toml"
mkdir -p "$T/clean/src/components/widgets/buttons/primary/variants/long_directory_name"

render() {
    local label="$1" dir="$2"; shift 2
    printf '\033[2m%s\033[0m\n' "$label"
    ( cd "$dir" && starship prompt --terminal-width "$COLS" "$@" 2>/dev/null ) \
        | awk '{ t = $0; gsub(/\033\[[0-9;]*m/, "", t); gsub(/[ \t]/, "", t); if (t != "") { print; exit } }' \
        || printf '(starship failed)\n'
}

for s in "${STATES[@]}"; do
    [[ -z "$ONLY" || "$ONLY" == "$s" ]] || continue
    case "$s" in
        plain)    render "not a repo" "$T/plain" ;;
        clean)    render "clean on main" "$T/clean" ;;
        dirty)    render "dirty: staged, modified, untracked, deleted, stash" "$T/dirty" ;;
        sync)     render "ahead 1 / behind 1 of origin" "$T/sync" ;;
        detached) render "detached HEAD on a tag" "$T/detached" ;;
        merge)    render "merge conflict" "$T/merge" ;;
        rebase)   render "rebase conflict" "$T/rebase" ;;
        failed)   render "last command failed (status 1)" "$T/clean" --status=1 ;;
        slow)     render "slow command (4.2 s)" "$T/clean" --cmd-duration=4200 ;;
        jobs)     render "2 background jobs" "$T/clean" --jobs=2 ;;
        node)     render "node project" "$T/proj/node" ;;
        python)   VIRTUAL_ENV="$T/proj/python/.venv" render "python project with venv" "$T/proj/python" ;;
        rust)     render "rust project" "$T/proj/rust" ;;
        longpath) render "long path" "$T/clean/src/components/widgets/buttons/primary/variants/long_directory_name" ;;
    esac
done

if [[ -z "$ONLY" ]]; then
    D=$'\xf3\xb0\x9c\x98'
    printf '\033[2mlegend\033[0m\n'
    printf ' \033[32m+2\033[0m staged     \033[33m~3\033[0m modified   \033[34m?1\033[0m untracked  \033[31m-1\033[0m deleted   \033[35m»1\033[0m renamed\n'
    printf ' \033[1;31m=1\033[0m conflict   \033[90m*1\033[0m stash      \033[32m⇡2\033[0m ahead      \033[31m⇣1\033[0m behind    \033[31m⇡2⇣1\033[0m diverged\n'
    printf ' \033[1;35m%s abc1234\033[0m detached HEAD       \033[1;35mv1.2\033[0m  tag on this commit\n' "$D"
    printf ' \033[1;35mREBASE 2/5   MERGE   PICK   REVERT   BISECT   AM\033[0m   in progress\n'
    printf ' (nothing after the branch name = clean tree, in sync)\n'
fi
exit 0
