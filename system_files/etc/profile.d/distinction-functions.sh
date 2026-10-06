#!/usr/bin/bash
# Sourced from /etc/profile (bash login) and /etc/zsh/zshrc (every zsh
# interactive shell). Never executed under pure sh — bash/zsh-only
# syntax (`[[ ]]`, `local`, `=~`, `disown`) is intentional.
# mkcd - Create and enter directory
mkcd() {
    if [ -z "$1" ]; then
        echo "Usage: mkcd <directory>" >&2
        return 1
    fi
    
    if mkdir -p "$1"; then
        cd "$1" || return 1
        printf "\033[36m\033[0m Entered: \033[36m%s\033[0m\n" "$1"
    else
        echo "Failed to create directory: $1" >&2
        return 1
    fi
}
