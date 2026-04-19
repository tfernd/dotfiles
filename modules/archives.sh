#!/usr/bin/env bash
# ============================================================================
# ARCHIVING & COMPRESSION FUNCTIONS
# ============================================================================

# --- Smart Archive Extraction ---
# Extracts ANY archive format. Optional second argument specifies destination.
# Usage: extract <archive> [destination]
unalias extract 2>/dev/null || true
function extract() {
    if [ -z "$1" ]; then
        echo -e "📝 \033[1;33mUsage:\033[0m extract <archive_file> [destination]"
        return 1
    fi

    if [ ! -f "$1" ]; then
        echo "❌ File '$1' not found!"
        return 1
    fi

    local dest="${2:-.}"

    # Create destination if it doesn't exist
    if [ "$dest" != "." ] && [ ! -d "$dest" ]; then
        mkdir -p "$dest"
    fi

    case "$1" in
        *.tar.bz2|*.tbz2) tar xvjf "$1" -C "$dest"        ;;
        *.tar.gz|*.tgz)   tar xvzf "$1" -C "$dest"        ;;
        *.tar.xz|*.txz)   tar xvJf "$1" -C "$dest"        ;;
        *.tar.zst)        tar --zstd -xvf "$1" -C "$dest" ;;
        *.tar)            tar xvf "$1" -C "$dest"         ;;
        *.zip)            unzip "$1" -d "$dest"           ;;
        *.rar)            unrar x "$1" "$dest/"           ;;
        *.7z)             7z x "$1" -o"$dest"             ;;
        *.bz2)            bunzip2 -k "$1"                 ;;
        *.gz)             gunzip -k "$1"                  ;;
        *.Z)              gunzip "$1"                     ;;
        *.xz)             unxz -k "$1"                    ;;
        *.zst)            unzstd -o "$dest/$(basename "${1%.zst}")" "$1"   ;;
        *)                echo "❌ Unknown archive format: '$1'"; return 1 ;;
    esac

    if [ $? -eq 0 ]; then
        [ "$dest" != "." ] && echo "📂 Extracted to $dest"
        return 0
    else
        echo "❌ Extraction failed!"
        return 1
    fi
}

# --- Smart Archiver ---
# Compressed files instantly. Default format is tar.gz.
unalias compress 2>/dev/null || true
function compress() {
    if [ $# -lt 2 ]; then
        echo -e "📝 \033[1;33mUsage:\033[0m compress <archive_name[.zip|.tar.gz|.7z|etc]> <file/folder> [more files...]"
        echo "💡 Default extension is .tar.gz if none is provided."
        return 1
    fi

    local archive=$1
    shift

    # Append .tar.gz if no extension is given
    if [[ "$archive" != *.* ]]; then
        archive="${archive}.tar.gz"
    fi

    echo "📦 Compressing into $archive..."
    case "$archive" in
        *.tar.bz2 | *.tbz2) tar cvjf           "$archive" "$@" ;;
        *.tar.gz | *.tgz)   tar cvzf           "$archive" "$@" ;;
        *.tar.xz | *.txz)   tar cvJf           "$archive" "$@" ;;
        *.tar.zst)          tar --zstd -cvf    "$archive" "$@" ;;
        *.tar)              tar cvf            "$archive" "$@" ;;
        *.zip)              zip -r             "$archive" "$@" ;;
        *.7z)               7z a               "$archive" "$@" ;;
        *.bz2)              bzip2 -c    "$@" > "$archive"      ;;
        *.gz)               gzip -c     "$@" > "$archive"      ;;
        *.xz)               xz -c       "$@" > "$archive"      ;;
        *.zst)              zstd -c     "$@" > "$archive"      ;;
        *.Z)                compress -c "$@" > "$archive"      ;;
        *)                  echo "❌ Unsupported format '$archive'."; return 1 ;;
    esac

    if [ $? -eq 0 ]; then
        echo "✅ Successfully created $archive"
        return 0
    else
        echo "❌ Compression failed!"
        return 1
    fi
}
