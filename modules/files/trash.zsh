# ============================================================================
# SAFE DELETION (rm/del → Trash)
# ============================================================================

# Loaded in every shell, AI/agent shells included: nothing is deleted for good
# through `rm`, it goes to the trash. (`command rm` and scripts still bypass it.)
# One function for every machine, and no helper function: an agent shell can lack one, and rm then fails
# with "command not found". The backend is picked at call time, so an uninstalled trash-cli cannot leave
# a stale cached HAS_TRASH_PUT making rm exit 127.
unalias rm del 2>/dev/null
function rm() {
    local args=() arg ch
    local force=false opts_done=false recursive=false dir=false verbose=false

    for arg in "$@"; do
        if [[ "$opts_done" == "false" ]]; then
            case "$arg" in
                --)            opts_done=true; continue ;;
                --force)       force=true; continue ;;
                --recursive)   recursive=true; continue ;;
                --dir)         dir=true; continue ;;
                --verbose)     verbose=true; continue ;;
                --interactive|--interactive=*) continue ;;
                --*)
                    print -r -u2 -- "rm: unrecognized option '$arg'"
                    return 1 ;;
                -?*)
                    for ch in ${(s::)arg#-}; do
                        case "$ch" in
                            f)   force=true ;;
                            r|R) recursive=true ;;
                            d)   dir=true ;;
                            v)   verbose=true ;;
                            i|I) ;;
                            *)
                                print -r -u2 -- "rm: invalid option -- '$ch'"
                                return 1 ;;
                        esac
                    done
                    continue ;;
            esac
        fi
        args+=("$arg")
    done

    if (( ${#args[@]} == 0 )); then
        [[ "$force" == "true" ]] && return 0
        print -r -u2 -- "rm: missing operand"
        return 1
    fi

    # Refuse the whole run before anything moves; `rm -rf ~/*` expands to children and is fine.
    # A symlink is judged by its own path (removing it removes the link), anything else by its real path.
    local item abs real
    for item in "${args[@]}"; do
        abs=${item:a}
        if [[ -L "$item" ]]; then real=$abs; else real=${item:A}; fi
        if [[ "$item" == (.|..|*/.|*/..) || "$abs" == / || "$real" == / \
            || ( -n "$HOME" && ( "$abs" == "${HOME:a}" || "$real" == "${HOME:A}" ) ) ]]; then
            print -r -u2 -- "❌ rm: refusing to remove '$item'"
            return 1
        fi
    done

    local backend=""
    if (( $+commands[trash-put] )); then
        backend=trash-put
    elif (( $+commands[trash] )); then
        backend=trash
    fi

    if [[ -z "$backend" ]]; then
        if [[ "$HAS_TRASH" == "true" ]]; then
            print -r -u2 -- "❌ rm: trash-put missing, run refresh"
            return 1
        fi
        if [[ "$IS_AGENT" == "true" ]]; then
            print -r -u2 -- "❌ rm: no trash tool installed; install trash-cli"
            return 1
        fi
        # -f (and -I, --interactive=never) would override -i and delete for real, so they are dropped.
        local keep=()
        [[ "$recursive" == "true" ]] && keep+=(-r)
        [[ "$dir" == "true" ]] && keep+=(-d)
        [[ "$verbose" == "true" ]] && keep+=(-v)
        command rm -i "${keep[@]}" -- "${args[@]}"
        return
    fi

    # A directory without -r is trashed too (deliberate: it is recoverable, unlike real rm's refusal).
    local existing=() missing_rc=0
    for item in "${args[@]}"; do
        if [[ -e "$item" || -L "$item" ]]; then
            existing+=("$item")
        elif [[ "$force" == "false" ]]; then
            print -r -u2 -- "rm: cannot remove '$item': No such file or directory"
            missing_rc=1
        fi
    done

    (( ${#existing[@]} > 0 )) || return $missing_rc

    local rc=0
    if [[ "$backend" == "trash-put" ]]; then
        command trash-put -- "${existing[@]}" || rc=$?
    else
        command trash -- "${existing[@]}" || rc=$?
    fi
    (( rc == 0 )) || return $rc
    return $missing_rc
}
alias del='rm'

if [[ "$HAS_TRASH_PUT" == "true" ]]; then
    alias rl='trash-list'

    # A name with a newline in it breaks the line-based parsing below (limitation).
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

        # Entries are identified by their position, never by their text (a path can be a prefix of another).
        local -a lines match
        lines=("${(@f)entries}")
        local numbered="" n
        for (( n = 1; n <= ${#lines[@]}; n += 1 )); do
            numbered+="$n"$'\t'"${lines[n]}"$'\n'
        done

        local selected=$(print -rn -- "$numbered" | fzf --height 60% --reverse --cycle \
            --border=rounded --info=inline --delimiter=$'\t' --with-nth=2.. \
            --header "Select file to restore (ESC to cancel)" \
            --preview 'echo {2..}' --preview-window=down:3:wrap)

        [[ -n "$selected" ]] || { echo "Cancelled."; return 0; }

        local idx=${selected%%$'\t'*}
        if [[ "$idx" != <-> ]] || (( idx < 1 || idx > ${#lines[@]} )); then
            echo "❌ Could not find entry in trash."
            return 1
        fi
        local line=${lines[idx]}

        # trash-list prints "date time path"
        local when orig
        if [[ "$line" =~ '^([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}) (.*)$' ]]; then
            when=$match[1]
            orig=$match[2]
        else
            echo "❌ Could not read the trash entry."
            return 1
        fi
        # Which copy of an identical line this is (same path trashed in the same second).
        local nth=1
        for (( n = 1; n < idx; n += 1 )); do
            [[ "${lines[n]}" == "$line" ]] && nth=$(( nth + 1 ))
        done

        echo -e "📂 Restore: \033[1;33m$orig\033[0m"
        echo ""
        echo "  1) Restore to original location"
        echo "  2) Restore to current directory"
        echo "  3) Cancel"
        echo ""
        echo -n "Choice [1/2/3]: "
        local choice
        read -r choice

        local base=${orig:t} dest=""
        case "$choice" in
            1) ;;
            2) dest="$PWD/$base" ;;
            *) echo "Cancelled."; return 0 ;;
        esac

        if [[ -e "$orig" || -L "$orig" ]]; then
            echo "❌ $orig already exists; nothing restored."
            return 1
        fi
        if [[ -n "$dest" && ( -e "$dest" || -L "$dest" ) ]]; then
            echo "❌ ./$base already exists; nothing restored."
            return 1
        fi

        # trash-restore PATH lists the entries under PATH whatever the current directory is, so its
        # own listing gives the index to feed it. Empty input makes it list and exit.
        local listing=$(print -r -- "" | trash-restore "$orig" 2>/dev/null)
        local -a rows
        rows=("${(@f)listing}")
        local row ridx="" seen=0
        for row in "${rows[@]}"; do
            if [[ "$row" =~ '^ *([0-9]+) ([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}) (.*)$' ]] \
                && [[ "$match[2]" == "$when" && "$match[3]" == "$orig" ]]; then
                seen=$(( seen + 1 ))
                (( seen == nth )) && ridx=$match[1]
            fi
        done
        if [[ -z "$ridx" ]]; then
            echo "❌ Could not find entry in trash."
            return 1
        fi

        if ! print -r -- "$ridx" | trash-restore "$orig" >/dev/null 2>&1; then
            echo "❌ Could not restore from trash."
            return 1
        fi

        # Trust the filesystem and the trash, not the exit status.
        local after=$(trash-list 2>/dev/null)
        local -a after_lines
        after_lines=("${(@f)after}")
        local after_count=${#after_lines[@]}
        [[ -z "$after" ]] && after_count=0
        if [[ ! -e "$orig" && ! -L "$orig" ]] || (( after_count != ${#lines[@]} - 1 )); then
            echo "❌ Restore did not complete; check $orig and the trash."
            return 1
        fi

        if [[ -z "$dest" ]]; then
            echo "✅ Restored to original location."
            return 0
        fi
        if mv -n -- "$orig" "$dest" && [[ -e "$dest" || -L "$dest" ]] && [[ ! -e "$orig" && ! -L "$orig" ]]; then
            echo "✅ Restored to ./$base"
        else
            echo "❌ Restored to $orig, but could not move it to ./$base"
            return 1
        fi
    }

    function empty-trash() {
        local listing
        listing=$(trash-list 2>/dev/null) || { print -r -u2 -- "❌ Could not read the trash."; return 1; }
        local count=0
        [[ -n "$listing" ]] && count=${#${(f)listing}}
        if [[ "$count" -eq 0 ]]; then
            echo "🗑️  Trash is empty."
            return 0
        fi
        echo -e "🗑️  \033[1;33mTrash contains $count file(s)\033[0m"
        echo ""
        trash-list 2>/dev/null | head -20
        [[ "$count" -gt 20 ]] && echo "  ... and $((count - 20)) more"
        echo ""
        echo -n "Empty trash permanently? (y/N): "
        read -r confirm
        if [[ "$confirm" == (y|Y|yes|YES) ]]; then
            if trash-empty; then
                echo "✅ Trash emptied."
            else
                echo "❌ Could not empty the trash."
                return 1
            fi
        else
            echo "Cancelled."
        fi
    }
fi
