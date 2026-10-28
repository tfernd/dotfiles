# ============================================================================
# SAFE DELETION (rm/del → Trash)
# ============================================================================

# Loaded in every shell, AI/agent shells included: nothing is deleted for good
# through `rm`, it goes to the trash. (`command rm` and scripts still bypass it.)
if [[ "$HAS_TRASH" == "true" ]]; then
    # No helper function here: an agent shell can lack one, and rm then fails with "command not found".
    function rm() {
        local args=() arg
        local force=false opts_done=false

        # rm's own flags (-r, -i, -v, ...) don't apply to trash; only -f matters
        for arg in "$@"; do
            if [[ "$opts_done" == "false" ]]; then
                case "$arg" in
                    --)      opts_done=true; continue ;;
                    --force) force=true; continue ;;
                    --*)     continue ;;
                    -?*)     [[ "$arg" == *f* ]] && force=true; continue ;;
                esac
            fi
            args+=("$arg")
        done

        local existing=() item
        for item in "${args[@]}"; do
            [[ -e "$item" || -L "$item" ]] && existing+=("$item")
        done

        local targets=("${existing[@]}")
        # Nothing exists: let the trash tool print its "not found" error
        if (( ${#targets[@]} == 0 )) && [[ "$force" == "false" ]]; then
            targets=("${args[@]}")
        fi
        (( ${#targets[@]} > 0 )) || return 0

        if [[ "$HAS_TRASH_PUT" == "true" ]]; then
            command trash-put -- "${targets[@]}"
        else
            command trash "${targets[@]}"
        fi
    }
    alias del='rm'

    if [[ "$HAS_TRASH_PUT" == "true" ]]; then
        alias rl='trash-list'

        function rt() {
            local entries=$(trash-list 2>/dev/null)
            if [[ -z "$entries" ]]; then
                echo "🗑️  Trash is empty."
                return 0
            fi

            # Use fzf if available, otherwise fall back to trash-restore
            if [[ "$HAS_FZF" != "true" ]]; then
                trash-restore
                return
            fi

            local selected=$(echo "$entries" | fzf --height 60% --reverse --cycle \
                --border=rounded --info=inline \
                --header "Select file to restore (ESC to cancel)" \
                --preview 'echo {}' --preview-window=down:3:wrap)

            [[ -n "$selected" ]] || { echo "Cancelled."; return 0; }

            # Extract the original path from trash-list output (format: "date time path")
            local orig_path=$(echo "$selected" | awk '{$1=""; $2=""; print}' | sed 's/^  //')

            echo -e "📂 Restore: \033[1;33m$orig_path\033[0m"
            echo ""
            echo "  1) Restore to original location"
            echo "  2) Restore to current directory"
            echo "  3) Cancel"
            echo ""
            echo -n "Choice [1/2/3]: "
            read -r choice

            case "$choice" in
                1)
                    # Feed the index to trash-restore
                    local idx=$(trash-list 2>/dev/null | grep -nF "$selected" | head -1 | cut -d: -f1)
                    if [[ -n "$idx" ]]; then
                        echo "$((idx - 1))" | trash-restore 2>/dev/null
                        echo "✅ Restored to original location."
                    else
                        echo "❌ Could not find entry in trash."
                    fi
                    ;;
                2)
                    local basename=$(basename "$orig_path")
                    local idx=$(trash-list 2>/dev/null | grep -nF "$selected" | head -1 | cut -d: -f1)
                    if [[ -n "$idx" ]]; then
                        echo "$((idx - 1))" | trash-restore 2>/dev/null
                        # Move from original location to current directory
                        if [[ -e "$orig_path" ]]; then
                            mv "$orig_path" "./$basename"
                            echo "✅ Restored to ./$basename"
                        else
                            echo "✅ Restored (check original location)."
                        fi
                    else
                        echo "❌ Could not find entry in trash."
                    fi
                    ;;
                *)
                    echo "Cancelled."
                    ;;
            esac
        }

        function empty-trash() {
            local count=$(trash-list 2>/dev/null | wc -l | tr -d ' ')
            if [[ "$count" -eq 0 ]]; then
                echo "🗑️  Trash is empty."
                return 0
            fi
            local size=$(trash-list 2>/dev/null | awk '{print $3}' | paste -sd+ | bc 2>/dev/null || echo "?")
            echo -e "🗑️  \033[1;33mTrash contains $count file(s)\033[0m"
            echo ""
            trash-list 2>/dev/null | head -20
            [[ "$count" -gt 20 ]] && echo "  ... and $((count - 20)) more"
            echo ""
            echo -n "Empty trash permanently? (y/N): "
            read -r confirm
            if [[ "$confirm" =~ ^[yY] ]]; then
                trash-empty
                echo "✅ Trash emptied."
            else
                echo "Cancelled."
            fi
        }
    else
        alias rm='trash'
        alias del='trash'
    fi
else
    alias rm='rm -i'
    alias del='rm -i'
fi
