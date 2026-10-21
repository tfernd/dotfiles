# ============================================================================
# SHELL ALIASES (one-liners)
# ============================================================================

alias c='clear && printf "\e[3J"'
alias x='exit'
alias reload='exec zsh --login'
alias doctor='zsh "$DOTFILES_DIR/doctor.zsh"'
alias path='echo "$PATH" | tr ":" "\n"'
alias df='df -h'
alias please='sudo $(fc -ln -1)'
alias grep='grep --color=auto'

# free — Memory usage
if [[ "$IS_LINUX" == "true" ]]; then
    alias free='free -m'
fi

# --- SSH shortcuts ---
alias ssh-login='eval "$(ssh-agent -s)" &>/dev/null && ssh-add ~/.ssh/id_ed25519 && echo "✅ SSH agent ready (key loaded)"'
alias ssh-test='ssh -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 | head -1'

# --- Zellij Multiplexer ---
if [[ -d "$DOTFILES_DIR/config/zellij" ]]; then
    mkdir -p "$HOME/.config/zellij/layouts"
    local _zj_src="$DOTFILES_DIR/config/zellij/config.kdl"
    local _zj_dst="$HOME/.config/zellij/config.kdl"
    if [[ ! -r "$_zj_dst" ]] || [[ "$_zj_src" -nt "$_zj_dst" ]]; then
        cp -f "$_zj_src" "$_zj_dst" 2>/dev/null
    fi
    if [[ -d "$DOTFILES_DIR/config/zellij/layouts" ]]; then
        cp -rf "$DOTFILES_DIR/config/zellij/layouts/." "$HOME/.config/zellij/layouts/" 2>/dev/null
    fi
    local _zj_clip=""
    if [[ "$IS_MAC" == "true" ]]; then
        _zj_clip="pbcopy"
    elif [[ "$IS_WSL" == "true" ]] && (( $+commands[clip.exe] )); then
        _zj_clip="clip.exe"
    elif (( $+commands[wl-copy] )); then
        _zj_clip="wl-copy"
    elif (( $+commands[xclip] )); then
        _zj_clip="xclip -selection clipboard"
    elif (( $+commands[xsel] )); then
        _zj_clip="xsel --clipboard --input"
    elif (( $+commands[pbcopy] )); then
        _zj_clip="pbcopy"
    fi
    if [[ -n "$_zj_clip" && -r "$_zj_dst" ]] && ! grep -Fq "copy_command \"$_zj_clip\"" "$_zj_dst"; then
        local _zj_tmp="${_zj_dst}.tmp"
        sed "s|^copy_command .*|copy_command \"${_zj_clip}\"|" "$_zj_dst" > "$_zj_tmp" && mv "$_zj_tmp" "$_zj_dst"
    fi
    unset _zj_src _zj_dst _zj_clip _zj_tmp
fi

if [[ "$HAS_ZELLIJ" == "true" ]]; then
    alias zj='zellij'
    alias zja='zellij attach -c main'
    alias zjl='zellij list-sessions'
    alias zjd='zellij delete-all-sessions --force'

    zjs() {
        if [[ -n "$1" ]]; then
            zellij attach -c "$1"
            return
        fi
        local sessions
        sessions=$(zellij list-sessions -n 2>/dev/null)
        if [[ -z "$sessions" ]]; then
            echo "No active sessions. Starting 'main'..."
            zellij attach -c main
            return
        fi
        if (( $+commands[fzf] )); then
            local selected
            selected=$(echo "$sessions" | fzf --prompt="Select session to attach > " --height=12 --reverse | awk '{print $1}')
            [[ -n "$selected" ]] && zellij attach "$selected"
        else
            echo "$sessions"
            echo -n "Session name to attach: "
            read -r target
            if [[ -n "$target" ]]; then
                zellij attach "$target"
            fi
        fi
    }

    # Interactive session killer (arrow keys + enter, zero typing)
    zjk() {
        local sessions
        sessions=$(zellij list-sessions -n 2>/dev/null)
        if [[ -z "$sessions" ]]; then
            echo "No active sessions to kill."
            return 0
        fi
        if [[ -n "$1" ]]; then
            zellij delete-session --force "$1"
            return
        fi
        if (( $+commands[fzf] )); then
            local selected
            selected=$(echo "$sessions" | fzf --prompt="Select session to KILL (Enter) > " --height=12 --reverse | awk '{print $1}')
            if [[ -n "$selected" ]]; then
                zellij delete-session --force "$selected" && echo "✅ Killed session: $selected"
            fi
        else
            echo "$sessions"
            echo -n "Type session name to kill: "
            read -r target
            [[ -n "$target" ]] && zellij delete-session --force "$target"
        fi
    }
fi
