#!/bin/sh 

# mkcd - Create and enter directory
mkcd() {
    if [ -z "$1" ]; then
        echo "Usage: mkcd <directory>" >&2
        return 1
    fi
    
    if mkdir -p "$1"; then
        cd "$1" || return 1
        
        # Shell-specific colour handling
        case "$SHELL_TYPE" in
            zsh)
                print -P "%F{cyan}✓%f Entered: %F{cyan}$1%f"
                ;;
            bash)
                echo -e "\033[36m✓\033[0m Entered: \033[36m$1\033[0m"
                ;;
            *)
                printf "\033[36m✓\033[0m Entered: \033[36m%s\033[0m\n" "$1"
                ;;
        esac
    else
        echo "Failed to create directory: $1" >&2
        return 1
    fi
}

# Extract function - Universal archive extractor
extract() {
    if [ -z "$1" ]; then
        echo "Usage: extract <archive>" >&2
        return 1
    fi
    
    if [ ! -f "$1" ]; then
        echo "Error: '$1' is not a valid file" >&2
        return 1
    fi
    
    case "$1" in
        *.tar.bz2)   tar xvjf "$1"    ;;
        *.tar.gz)    tar xvzf "$1"    ;;
        *.tar.xz)    tar xvJf "$1"    ;;
        *.bz2)       bunzip2 "$1"     ;;
        *.rar)       unrar x "$1"     ;;
        *.gz)        gunzip "$1"      ;;
        *.tar)       tar xvf "$1"     ;;
        *.tbz2)      tar xvjf "$1"    ;;
        *.tgz)       tar xvzf "$1"    ;;
        *.zip)       unzip "$1"       ;;
        *.Z)         uncompress "$1"  ;;
        *.7z)        7z x "$1"        ;;
        *.xiso)      xiso -x "$1"     ;;
        *)           
            echo "Error: Unsupported archive format" >&2
            return 1
            ;;
    esac
}

#custom rm command from anthrophic's claude Sonnet 4:
rm() {
    if [[ -d "$1" ]]; then
        local file_count=$(find "$1" -type f | wc -l)
        local CYAN="\033[031m"
        local NC="\033[0m"
        echo -e "This is a directory containing $CYAN$file_count$NC files."
        echo -n "Are you quite certain you wish to delete it? [y/N] "
        read -q "REPLY?"
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            command rm -rf "$@"
        fi
    else
        command rm -i "$@"
    fi
}

# Enhanced cd with proper truncation and column alignment
cd() {
    builtin cd "$@" && {
        local item_count=$(ls -1 | wc -l)
        if [ $item_count -gt 20 ]; then
            echo "Directory contains $item_count items:"
            local col_width=$(($(tput cols) / 2 - 1))
            eza --icons=always --classify=always --color=always| head -40 | awk -v width="$col_width" '
            {
                # Remove ANSI codes for length check
                plain = $0
                gsub(/\033\[[0-9;]*m/, "", plain)
                
                if (length(plain) > width - 3) {
                    printf "%-*s", width, substr($0, 1, width-3) "..."
                } else {
                    printf "%-*s", width, $0
                }
                
                if (NR % 2 == 0) print ""
            }
            END { if (NR % 2 == 1) print "" }'
            echo "... and $((item_count - 40)) more items (use 'ls' to see all)"
        else
            eza --icons=always --classify=always --color=always
        fi
    }
}

# Enhanced nautilus launcher with error handling
naut() {
    local target_dir="${1:-.}"
    
    if [[ ! -d "$target_dir" ]]; then
        echo "Directory '$target_dir' does not exist."
        return 1
    fi
    local CYAN="\033[031m"
    local NC="\033[0m"
    nautilus "$target_dir" >/dev/null 2>&1 &
    disown
    echo "Nautilus opened for: $CYAN$(realpath "$target_dir")$NC"
}


