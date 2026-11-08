#!/usr/bin/env bash
# ============================================================================
# 🔄 UPDATE VERSIONS SCRIPT
# Checks upstream GitHub releases for each tool in versions.toml
# Enforces the supply-chain quarantine: age_days >= the number of days in .freshness
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSIONS_FILE="$SCRIPT_DIR/versions.toml"
MIN_AGE_DAYS=$(tr -dc '0-9' 2>/dev/null < "$SCRIPT_DIR/.freshness" || true)
[[ -n "$MIN_AGE_DAYS" ]] || { echo "❌ $SCRIPT_DIR/.freshness is missing or holds no number of days"; exit 1; }
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
    ["starship"]="starship/starship"
    ["uv"]="astral-sh/uv"
    ["zoxide"]="ajeetdsouza/zoxide"
    ["terraform"]="hashicorp/terraform"
    ["terraform-ls"]="hashicorp/terraform-ls"
    ["rg"]="BurntSushi/ripgrep"
    ["fd"]="sharkdp/fd"
    ["fzf"]="junegunn/fzf"
    ["just"]="casey/just"
    ["lazygit"]="jesseduffield/lazygit"
    ["btm"]="ClementTsang/bottom"
    ["yazi"]="sxyazi/yazi"
    ["firacode-nerd"]="ryanoasis/nerd-fonts"
)

NOW_EPOCH=$(date +%s)
CUTOFF_DATE=$(date -d "-${MIN_AGE_DAYS} days" "+%Y-%m-%d" 2>/dev/null || date -v-"${MIN_AGE_DAYS}"d "+%Y-%m-%d")

echo -e "\n\033[1;36m=================================================================\033[0m"
echo -e "\033[1;35m  🔄 CHECKING TOOL RELEASES (Quarantine: >= ${MIN_AGE_DAYS} days old)\033[0m"
echo -e "  📅 Safe Cutoff Date: \033[1;33m${CUTOFF_DATE}\033[0m"
echo -e "\033[1;36m=================================================================\033[0m\n"

printf "\033[1;37m%-15s %-12s %-14s %-12s %-15s\033[0m\n" "TOOL" "CURRENT" "SAFE VERSION" "RELEASED" "STATUS"
printf "%-15s %-12s %-14s %-12s %-15s\n" "---------------" "------------" "--------------" "------------" "---------------"

declare -A NEW_VERSIONS=()
declare -A NEW_DATES=()
declare -A IS_NEW=()
UPDATES_COUNT=0

_api() {
    local path="$1"
    if command -v gh &>/dev/null && gh auth status &>/dev/null; then
        gh api "$path" 2>/dev/null || true
    else
        curl -sSL "https://api.github.com/${path}" 2>/dev/null || true
    fi
}

_fetch_releases() {
    local repo="$1"
    _api "repos/${repo}/releases?per_page=15"
}

# Every tool in REPOS. One with no row in versions.toml yet is added at its newest safe release.
for tool in $(printf '%s\n' "${!REPOS[@]}" | sort); do
    repo="${REPOS[$tool]:-}"
    [[ -z "$repo" ]] && continue

    # Current version from versions.toml (empty for a tool with no row yet)
    curr_ver=$(awk '/^\[/{s = ($0 == "[tools]" || $0 == "[fonts]")} s' "$VERSIONS_FILE" | grep "^${tool} *=" | sed -E 's/.*version = "([^"]+)".*/\1/') || true
    curr_date=$(awk '/^\[/{s = ($0 == "[tools]" || $0 == "[fonts]")} s' "$VERSIONS_FILE" | grep "^${tool} *=" | sed -E 's/.*released = "([^"]+)".*/\1/') || true
    # A font with no row is not added: new rows go to [tools].
    [[ -z "$curr_ver" && "$tool" == firacode-nerd ]] && continue

    # Fetch release JSON
    json=$(_fetch_releases "$repo")
    if [[ -z "$json" || "$(echo "$json" | jq -r 'type' 2>/dev/null || true)" != "array" ]]; then
        fetch_msg=$(echo "$json" | jq -r '.message // empty' 2>/dev/null || true)
        printf "%-15s %-12s \033[31m%-14s %-12s %-15s\033[0m\n" "$tool" "$curr_ver" "error" "-" "fetch failed${fetch_msg:+: $fetch_msg}"
        continue
    fi
    if [[ "$json" == "[]" ]]; then
        printf "%-15s %-12s \033[31m%-14s %-12s %-15s\033[0m\n" "$tool" "$curr_ver" "error" "-" "fetch failed"
        continue
    fi

    # Safe releases (not draft/prerelease, published on or before CUTOFF_DATE), newest publish first
    candidates=$(echo "$json" | jq -r --arg cutdate "$CUTOFF_DATE" '
        [ .[] | select(.draft == false and .prerelease == false)
          | .epoch = (.published_at | fromdateiso8601)
          | select(.published_at[:10] <= $cutdate)
        ] | sort_by(.epoch) | reverse | .[] | "\(.tag_name) \(.published_at[:10])"
    ' 2>/dev/null || true)

    # The highest version wins, not the latest publish: a patch on an older line can be published later.
    # sort -V only orders plain dotted numbers, so a tool with any other safe tag keeps newest-by-date.
    match=""
    if [[ -n "$candidates" ]]; then
        numeric=true
        normalised=""
        while read -r tag rel_day; do
            t="${tag#v}"
            t="${t#bun-v}"
            [[ "${t,,}" =~ -(canary|rc|beta|alpha|pre|dev|nightly) ]] && continue
            [[ "$t" =~ ^[0-9]+(\.[0-9]+)*$ ]] || numeric=false
            normalised+="$t $rel_day"$'\n'
        done <<< "$candidates"
        if [[ "$numeric" == true ]]; then
            match=$(printf '%s' "$normalised" | sort -V -k1,1 | tail -n 1)
        else
            match="${normalised%%$'\n'*}"
        fi
        # Never propose a version that is not newer than the pin
        top=${match%% *}
        if [[ -n "$top" && -n "$curr_ver" && "$curr_ver" != "$top" ]] \
            && [[ "$(printf '%s\n%s\n' "$curr_ver" "$top" | sort -V | tail -n 1)" == "$curr_ver" ]]; then
            match="$curr_ver $curr_date"
        fi
    fi

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
        label="🚀 UPDATE"
        if [[ -z "$curr_ver" ]]; then
            label="🆕 ADD"
            IS_NEW["$tool"]=1
        fi
        printf "%-15s \033[33m%-12s\033[0m \033[1;32m%-14s\033[0m %-12s \033[1;33m%-15s\033[0m\n" "$tool" "${curr_ver:--}" "$safe_ver" "$rel_date" "$label"
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

echo -e "\033[1;33mFound $UPDATES_COUNT tool update(s) passing the ${MIN_AGE_DAYS}-day quarantine rule.\033[0m\n"

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
    for tool in $(printf '%s\n' "${!NEW_VERSIONS[@]}" | sort); do
        new_v="${NEW_VERSIONS[$tool]}"
        new_d="${NEW_DATES[$tool]}"
        if [[ -n "${IS_NEW[$tool]:-}" ]]; then
            last=$(awk '/^\[/{s = ($0 == "[tools]")} s && /^[a-z0-9_-]+ *= *\{/{n = NR} END{print n + 0}' "$VERSIONS_FILE")
            [[ "$last" -gt 0 ]] || { echo "  ❌ no [tools] rows in versions.toml: cannot add $tool"; continue; }
            sed -i "${last}a ${tool} = { version = \"${new_v}\", released = \"${new_d}\" }" "$VERSIONS_FILE"
            echo "  ✅ Added $tool -> v$new_v ($new_d)"
        else
            sed -i -E "s|^(${tool} *= *\{ *version = *)\"[^\"]+\"(, *released = *)\"[^\"]+\"( *\})|\1\"${new_v}\"\2\"${new_d}\"\3|" "$VERSIONS_FILE"
            echo "  ✅ Updated $tool -> v$new_v ($new_d)"
        fi
    done
    echo -e "\n\033[1;32m🎉 versions.toml updated successfully!\033[0m"
    echo -e "Run \033[1;36mbash install.sh\033[0m to install the new versions."
else
    echo "No changes applied."
fi
