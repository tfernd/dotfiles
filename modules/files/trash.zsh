# ============================================================================
# SAFE DELETION (rm/del → Trash)
# ============================================================================

if [[ "$HAS_TRASH" == "true" ]]; then
    function rm() {
        local args=()
        local force=false

        for arg in "$@"; do
            case "$arg" in
                -rf|-f|-fr) force=true ;;
                -*) ;;
                *) args+=("$arg") ;;
            esac
        done

        local existing=()
        for item in "${args[@]}"; do
            [[ -e "$item" ]] && existing+=("$item")
        done

        if (( ${#existing[@]} > 0 )); then
            if [[ "$HAS_TRASH_PUT" == "true" ]]; then
                command trash-put "${existing[@]}"
            else
                command trash "${existing[@]}"
            fi
        elif [[ "$force" == "false" ]] && (( ${#args[@]} > 0 )); then
            [[ "$HAS_TRASH_PUT" == "true" ]] && command trash-put "${args[@]}" || command trash "${args[@]}"
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
