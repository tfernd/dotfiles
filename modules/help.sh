#!/usr/bin/env bash
# ============================================================================
# HELP MENU & CHEAT SHEETS
# ============================================================================
function myhelp() {
    echo -e "\n\033[1;36m=================================================================\033[0m"
    echo -e "\033[1;35m  🚀 THE CROSS-PLATFORM TERMINAL CHEATSHEET\033[0m"
    echo -e "\033[1;36m=================================================================\033[0m\n"

    # Padded print helper
    print_cmd() { printf "  \033[1;32m%-15s\033[0m : %s\n" "$1" "$2"; }

    echo -e "\033[1;33m📂 FILES & NAVIGATION\033[0m"
    [ "$HAS_ZOXIDE" = "true" ] && print_cmd "cd" "Smarter cd (zoxide)"
    print_cmd "up, .., ~" "Go up N levels, up 1 level, or Home"
    print_cmd "-" "Jump to the last directory you were in"
    print_cmd "cw" "Switch editor workspace to current folder (Kiro/Cursor/Code/Antigravity)"
    if [ "$HAS_EZA" = "true" ]; then
        print_cmd "ls, ll" "Modern ls with icons (ll = long format, lt = tree)"
        print_cmd "lsh, llh" "Same as above but shows hidden files"
    else
        print_cmd "ls, ll" "Standard ls and ll listing"
    fi
    [ "$HAS_BAT" = "true" ] && print_cmd "cat" "Modern cat with syntax highlighting (bat)"
    print_cmd "extract"   "Unzip ANY archive format instantly"
    print_cmd "symlink" "Create a symlink — symlink <link> <target>"
    print_cmd "compress"  "Zip files instantly (e.g. compress archive docs/)"
    print_cmd "backup"    "Backup a file (e.g. backup file.txt -> file.txt_date.bak)"
    print_cmd "note"      "Quick note with timestamp (note-config to set save path)"
    print_cmd "note-config" "Set where notes are saved (persists in ~/.custom.zsh)"

    echo -e "\n\033[1;33m🔍 SEARCH & SYSTEM\033[0m"
    print_cmd "memhog"   "Show top 15 memory-hogging processes"
    [ "$HAS_YAZI" = "true" ] && print_cmd "y"      "Terminal visual file explorer (yazi)"
    print_cmd "top"    "Process monitor (btm/bottom if installed, else system top)"
    [ "$HAS_XH" = "true" ]   && print_cmd "http"   "API testing and cURL replacement (xh)"
    [ "$HAS_RG" = "true" ]   && print_cmd "rg"     "Blazing fast text search (ripgrep)"
    [ "$HAS_TLDR" = "true" ] && print_cmd "tldr"   "Quick cheat sheets for terminal commands"
    if [ "$HAS_FZF" = "true" ]; then
        print_cmd "Alt+F / f"        "Fuzzy file search from CWD -> inject path at cursor"
        print_cmd "Alt+Shift+F / ff"  "Fuzzy file search from HOME -> inject path at cursor"
        print_cmd "Ctrl+H / h"        "Fuzzy history search -> inject command at cursor"
        print_cmd "hh"                "Fuzzy history search -> copy to clipboard"
    fi
    print_cmd "port, kill-port" "Check what app is on a port, and Kill it"
    print_cmd "copy, cpwd, ccat" "Clipboard: copy stdin, copy pwd, copy file"
    print_cmd "c"           "Clear the terminal screen"
    print_cmd "myip, localip" "Get public and local IP address"
    print_cmd "df, free"    "Disk and Memory usage (human readable)"
    print_cmd "weather"     "Beautiful 3-day terminal weather forecast"
    print_cmd "sleep"       "Cross-platform sleep (with Python fallback)"
    print_cmd "reload, x"   "Reload shell, Exit terminal"
    print_cmd "daemonize"   "Run command in background and save logs"

    echo -e "\n\033[1;33m🐙 GIT & GITHUB\033[0m"
    [ "$HAS_LAZYGIT" = "true" ] && print_cmd "lg"  "Open Lazygit TUI (Visual Git)"
    print_cmd "gs, gds" "Git status (short), Git diff staged"
    print_cmd "gdss"   "Git diff staged (side-by-side view)"
    print_cmd "gb, gba" "List branches, List all branches (inc. remote)"
    print_cmd "gl, ga" "Git log (beautiful graph), Git add all"
    print_cmd "gp"     "Git push (current branch to remote)"
    print_cmd "gu, gr" "Git Undo / Redo (with confirmation prompt)"
    print_cmd "gam"    "Git Amend (add to last commit quietly)"
    print_cmd "gpf"    "Git Push (Safe Force for amended commits)"
    if [ "$HAS_GH" = "true" ]; then
        print_cmd "pr, prs" "Create a GitHub PR, List open PRs"
        print_cmd "gstats"  "Unified GitHub summary (Notifs, Mentions, Reviews)"
        print_cmd "ghn,ghm,ghr" "Manage Gh Notifs, Mentions, and Reviews"
        print_cmd "ghv, ghme" "View repo on GitHub, List my PRs"
    fi
    print_cmd "help git" "Decode your git prompt symbols (cheat sheet)"

    echo -e "\n\033[1;33m🐍 DEVELOPMENT & DATA\033[0m"
    [ "$HAS_JQ" = "true" ] && print_cmd "jq"      "Command-line JSON processor"
    [ "$HAS_YQ" = "true" ] && print_cmd "yq"      "Command-line YAML processor"
    print_cmd "python, pip" "Strictly mapped to UV (AI Guard active if UV installed)"
    print_cmd "envup"   "Load variables from a .env file"
    print_cmd "pyclean" "Delete all __pycache__ and compiled files"
    print_cmd "server"  "Start a simple Python web server (default :8000)"
    print_cmd "uv-upgrade" "Upgrade all UV-managed global tools"
    print_cmd "json"    "Pretty-print minified JSON from stdin"
    print_cmd "calc"    "Command line calculator (usage: calc \"1 + 1\")"

    echo -e "\n\033[1;33m🛡️ SETUP & SAFETY\033[0m"
    print_cmd "setup-terminal" "Install all missing tools"
    print_cmd "editor-config" "Print recommended VS Code / Kiro settings for your OS"
    print_cmd "git-setup"  "Interactive: set git user.name + email globally"
    print_cmd "ssh-setup"  "Interactive: generate SSH key, add to agent, test"
    print_cmd "ssh-login"  "Quick: start ssh-agent + add your key"
    print_cmd "ssh-test"   "Test SSH connection to GitHub"
    print_cmd "dotfiles-share-root" "Setup same environment for the ROOT user"
    print_cmd "refresh"        "Rebuild tool cache + reload shell"
    print_cmd "please" "Re-run previous command with sudo"
    if [ "$HAS_TRASH" = "true" ]; then
        print_cmd "rm, del" "Move to Trash (Safe versions of deletion)"
    fi

    echo -e "\n\033[1;36m=================================================================\033[0m\n"
}

function help_git() {
    # True-color (24-bit) ANSI — matching starship.toml [palettes.hyper]
    local grey="\033[38;2;108;112;134m"   # #6c7086
    local red="\033[38;2;243;139;168m"    # #f38ba8
    local green="\033[38;2;166;227;161m"  # #a6e3a1
    local yellow="\033[38;2;249;226;175m" # #f9e2af
    local magenta="\033[38;2;203;166;247m" # #cba6f7
    local cyan="\033[38;2;137;220;235m"   # #89dceb
    local white="\033[38;2;205;214;244m"  # #cdd6f4
    local bold="\033[1m"
    local reset="\033[0m"

    # Fixed-width row printing for symbols
    print_sym() {
        local sym="$1" color="$2" vlen="$3" label="$4" desc="$5"
        local pad=$((6 - vlen))
        printf "    ${color}${bold}%s${reset}%*s  ${color}%-12s${reset}  ${white}%s${reset}\n" \
            "$sym" "$pad" "" "$label" "$desc"
    }

    echo -e "\n${cyan}=================================================================${reset}"
    echo -e "${magenta}  GIT PROMPT CHEAT SHEET${reset}"
    echo -e "${cyan}=================================================================${reset}"

    echo -e "\n${yellow}  YOUR PROMPT LOOKS LIKE THIS:${reset}"
    local user="${USER:-${USERNAME:-$(whoami)}}"
    echo -e "  ${cyan}${user}${reset}  ${white}…/my-repo${reset}  ${yellow}refactor${reset}  ${white}[${reset} ${grey}⛶2${reset} ${red}⨳1${reset} ${green}⇡3${reset} ${red}⇣1${reset} ${green}+2${reset} ${yellow}!3${reset} ${magenta}↦1${reset} ${red}✘1${reset} ${cyan}?7${reset} ${white}]${reset}  ${green}+90${reset} ${red}-132${reset} ${white}00:30${reset}"

    echo -e "\n${yellow}  GIT STATUS SYMBOLS${reset}"
    echo -e "    ${bold}${white}SYM     NAME          DESCRIPTION${reset}"
    echo -e "    ${grey}───     ────────────  ───────────────────────────────────────${reset}"
    print_sym "⛶N"  "$grey"    2 "stashed"    "N stash entries saved (git stash list)"
    print_sym "⨳N"  "$red"     2 "conflicted" "N merge conflicts — resolve before commit"
    print_sym "⇡N"  "$green"   2 "ahead"      "N commits ahead of remote (need to push)"
    print_sym "⇣N"  "$red"     2 "behind"     "N commits behind remote (need to pull)"
    print_sym "+N"  "$green"   2 "staged"     "N files added to index (git add)"
    print_sym "!N"  "$yellow"  2 "modified"   "N tracked files changed but not staged"
    print_sym "↦N"  "$magenta" 2 "renamed"    "N files renamed in the index"
    print_sym "✘N"  "$red"     2 "deleted"    "N files deleted (staged or unstaged)"
    print_sym "?N"  "$cyan"    2 "untracked"  "N new files not yet tracked"

    echo -e "\n${yellow}  GIT METRICS${reset}"
    echo -e "    ${bold}${white}SYM     NAME          DESCRIPTION${reset}"
    echo -e "    ${grey}───     ────────────  ───────────────────────────────────────${reset}"
    print_sym "+N"   "$green" 2 "added"      "Lines added in your working changes"
    print_sym "-N"   "$red"   2 "deleted"    "Lines deleted in your working changes"

    echo -e "\n${cyan}=================================================================\n${reset}"
}

unalias help 2>/dev/null || true
function help() {
    if [ "$1" = "git" ]; then
        help_git | less -RF
    else
        myhelp | less -RF
    fi
}
