#!/usr/bin/env bash
# ============================================================================
# 🔄 UPDATE VERSIONS SCRIPT
# Checks upstream GitHub releases for each tool in versions.toml
# Enforces the 14-day supply-chain quarantine rule: age_days >= 14
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSIONS_FILE="$SCRIPT_DIR/versions.toml"
MIN_AGE_DAYS=14
APPLY=false

# Parse flags
for arg in "$@"; do
    case "$arg" in
        --apply|-a|-y) APPLY=true ;;
        --help|-h)
            echo "Usage: ./update-versions.sh [--apply]"
            echo "  --apply, -a    Automatically write updated versions to versions.toml"
            exit 0
            ;;
    esac
done

if [[ ! -f "$VERSIONS_FILE" ]]; then
    echo "❌ FATAL: $VERSIONS_FILE not found."
    exit 1
fi

# Tool repository mapping
declare -A REPOS=(
    ["atuin"]="atuinsh/atuin"
    ["bat"]="sharkdp/bat"
    ["bun"]="oven-sh/bun"
    ["delta"]="dandavison/delta"
    ["eza"]="eza-community/eza"
    ["gh"]="cli/cli"
    ["git"]="git/git"
    ["ripgrep"]="BurntSushi/ripgrep"
    ["starship"]="starship/starship"
    ["uv"]="astral-sh/uv"
    ["xh"]="ducaale/xh"
    ["yq"]="mikefarah/yq"
    ["zellij"]="zellij-org/zellij"
    ["zoxide"]="ajeetdsouza/zoxide"
    ["firacode-nerd"]="ryanoasis/nerd-fonts"
)

NOW_EPOCH=$(date +%s)
CUTOFF_EPOCH=$((NOW_EPOCH - MIN_AGE_DAYS * 86400))
CUTOFF_DATE=$(date -d "@$CUTOFF_EPOCH" "+%Y-%m-%d" 2>/dev/null || date -r "$CUTOFF_EPOCH" "+%Y-%m-%d" 2>/dev/null)

echo -e "\n\033[1;36m=================================================================\033[0m"
echo -e "\033[1;35m  🔄 CHECKING TOOL RELEASES (Quarantine: >= ${MIN_AGE_DAYS} days old)\033[0m"
echo -e "  📅 Safe Cutoff Date: \033[1;33m${CUTOFF_DATE}\033[0m"
echo -e "\033[1;36m=================================================================\033[0m\n"

printf "\033[1;37m%-15s %-12s %-14s %-12s %-15s\033[0m\n" "TOOL" "CURRENT" "SAFE VERSION" "RELEASED" "STATUS"
printf "%-15s %-12s %-14s %-12s %-15s\n" "---------------" "------------" "--------------" "------------" "---------------"

declare -A NEW_VERSIONS=()
declare -A NEW_DATES=()
UPDATES_COUNT=0

_api() {
    local path="$1"
    if command -v gh &>/dev/null && gh auth status &>/dev/null; then
        gh api "$path" 2>/dev/null || return 1
    else
        curl -fsSL "https://api.github.com/${path}" 2>/dev/null || return 1
    fi
}

_fetch_releases() {
    local repo="$1"
    if [[ "$repo" == "git/git" ]]; then
        _fetch_git_tags || return 1
        return 0
    fi
    _api "repos/${repo}/releases?per_page=15"
}

# git/git has no GitHub Releases API payload. tags.atom has name + updated date in one fetch.
_fetch_git_tags() {
    local atom
    atom=$(curl -fsSL "https://github.com/git/git/tags.atom" 2>/dev/null) || return 1
    echo "$atom" | jq -R -s '
        [ scan("<entry>[\\s\\S]*?</entry>") as $e
          | ($e | capture("<title>\\s*(?<tag_name>v[0-9]+\\.[0-9]+\\.[0-9]+)\\s*</title>") // empty) as $t
          | ($e | capture("<updated>\\s*(?<published_at>[^<]+)</updated>") // empty) as $u
          | select($t.tag_name != null and $u.published_at != null)
          | {tag_name:$t.tag_name, published_at:$u.published_at, draft:false, prerelease:false}
        ]
    ' 2>/dev/null
}

for tool in atuin bat bun delta eza gh git ripgrep starship uv xh yq zellij zoxide firacode-nerd; do
    repo="${REPOS[$tool]:-}"
    [[ -z "$repo" ]] && continue

    # Current version from versions.toml
    curr_ver=$(grep "^${tool} *=" "$VERSIONS_FILE" | sed -E 's/.*version = "([^"]+)".*/\1/')
    curr_date=$(grep "^${tool} *=" "$VERSIONS_FILE" | sed -E 's/.*released = "([^"]+)".*/\1/')

    # Fetch release JSON
    json=$(_fetch_releases "$repo" || echo "[]")
    if [[ "$json" == "[]" || -z "$json" ]]; then
        printf "%-15s %-12s \033[31m%-14s %-12s %-15s\033[0m\n" "$tool" "$curr_ver" "error" "-" "fetch failed"
        continue
    fi

    # Parse newest release where published_at <= CUTOFF_DATE and not draft/prerelease
    match=$(echo "$json" | jq -r --argjson cutoff "$CUTOFF_EPOCH" '
        [ .[] | select(.draft == false and .prerelease == false)
          | .epoch = (.published_at | fromdateiso8601)
          | select(.epoch <= $cutoff)
        ] | sort_by(.epoch) | reverse | .[0] // empty | "\(.tag_name) \(.published_at[:10])"
    ' 2>/dev/null || true)

    if [[ -z "$match" ]]; then
        printf "%-15s %-12s %-14s %-12s \033[33m%-15s\033[0m\n" "$tool" "$curr_ver" "$curr_ver" "$curr_date" "no safe release"
        continue
    fi

    raw_tag=$(echo "$match" | awk '{print $1}')
    rel_date=$(echo "$match" | awk '{print $2}')

    # Normalize tag name (strip v, bun-v, etc.)
    safe_ver="$raw_tag"
    safe_ver="${safe_ver#v}"
    safe_ver="${safe_ver#bun-v}"

    if [[ "$curr_ver" == "$safe_ver" ]]; then
        printf "%-15s %-12s %-14s %-12s \033[32m%-15s\033[0m\n" "$tool" "$curr_ver" "$safe_ver" "$rel_date" "✅ up to date"
    else
        printf "%-15s \033[33m%-12s\033[0m \033[1;32m%-14s\033[0m %-12s \033[1;33m%-15s\033[0m\n" "$tool" "$curr_ver" "$safe_ver" "$rel_date" "🚀 UPDATE"
        NEW_VERSIONS["$tool"]="$safe_ver"
        NEW_DATES["$tool"]="$rel_date"
        UPDATES_COUNT=$((UPDATES_COUNT + 1))
    fi
done

echo ""

if [[ $UPDATES_COUNT -eq 0 ]]; then
    echo -e "\033[1;32m✨ All tools are already on the latest safe versions!\033[0m\n"
    exit 0
fi

echo -e "\033[1;33mFound $UPDATES_COUNT tool update(s) passing the 14-day quarantine rule.\033[0m\n"

if [[ "$APPLY" == "false" ]]; then
    if [[ -t 0 ]]; then
        read -p "Would you like to apply these updates to versions.toml? [y/N] " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            APPLY=true
        fi
    else
        echo "Run with --apply (or -a) to automatically update versions.toml."
    fi
fi

if [[ "$APPLY" == "true" ]]; then
    for tool in "${!NEW_VERSIONS[@]}"; do
        new_v="${NEW_VERSIONS[$tool]}"
        new_d="${NEW_DATES[$tool]}"
        sed -i -E "s|^(${tool} *= *\{ *version = *)\"[^\"]+\"(, *released = *)\"[^\"]+\"( *\})|\1\"${new_v}\"\2\"${new_d}\"\3|" "$VERSIONS_FILE"
        echo "  ✅ Updated $tool -> v$new_v ($new_d)"
    done
    echo -e "\n\033[1;32m🎉 versions.toml updated successfully!\033[0m"
    echo -e "Run \033[1;36mbash install.sh\033[0m to install the new versions."
else
    echo "No changes applied."
fi
