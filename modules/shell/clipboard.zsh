# ============================================================================
# CLIPBOARD HANDLING
# ============================================================================

if [[ "$DOTFILES_PLATFORM" == "macos" ]]; then
    alias copy='pbcopy'
elif [[ "$DOTFILES_PLATFORM" == "wsl" ]]; then
    if (( $+commands[clip.exe] )); then
        alias copy='clip.exe'
    elif (( $+commands[xclip] )); then
        alias copy='xclip -selection clipboard'
    fi
elif [[ "$IS_LINUX" == "true" ]]; then
    if (( $+commands[xclip] )); then
        alias copy='xclip -selection clipboard'
    elif (( $+commands[wl-copy] )); then
        alias copy='wl-copy'
    elif (( $+commands[xsel] )); then
        alias copy='xsel --clipboard --input'
    fi
fi

alias cpwd='pwd | copy'
