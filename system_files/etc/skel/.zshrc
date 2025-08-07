
 
#ALIAS
alias grep="grep --color=auto"
alias fgrep="fgrep --color=auto"
alias egrep="egrep --color=auto"
alias cat="bat -p"
alias lt="tree -uh --sort=size -L 1"
alias ltm="tree -uhp --filelimit 20 --sort=size -L 3"
alias cp="advcp -g" #copy but with graphical progress bar
alias mv="advmv -g" #move but with graphical progress bar
alias ..="cd .."

setopt NO_BEEP
setopt autocd 
setopt privileged
#setopt correct 
setopt menucomplete
setopt histignoredups # prevents duplicate history entrys
setopt histignorespace # 
setopt noclobber # prevents overwriting already a file that already exists. Override is >! e.g. cat /dev/null >! ~/.zshrc 
setopt extendedglob
setopt globdots
setopt append_history inc_append_history share_history
setopt auto_menu menu_complete
zmodload -a colors

zstyle ':completion:*' menu select
#zstyle ':completion:*' 
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS} ma=0\;33

zstyle ':completion:*:descriptions' format "$fg[yellow]%B--- %d%b"
zstyle ':completion:*:messages' format '%d'
zstyle ':completion:*:warnings' format "$fg[red]No matches for:$reset_color %d"


zmodload zsh/complist
autoload -U compinit && compinit
autoload -U colors && colors
#run local, user binaries
export PATH=$PATH:~/.cargo/bin
export PATH="$HOME/.local/bin:$PATH"

plugins=(aliases alias-finder dnf copyfile copypath fzf dnf git gh rsync ssh sudo pip safe-paste systemadmin tldr zoxide z zsh-interactive-cd zsh-syntax-highlighting zsh-autosuggestions colored-man-pages)
#plugins see:https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins
#some plugins require additional configuration to be used by your shell

#omz update default
zstyle ':omz:update' frequency 14
zstyle ':omz:update' mode auto 

mkcd() {
    mkdir -p "$1" && cd "$1"
}


# Enhanced cd with proper truncation and column alignment
cd() {
    builtin cd "$@" && {
        local item_count=$(ls -1 | wc -l)
        if [ $item_count -gt 20 ]; then
            echo "Directory contains $item_count items:"
            local col_width=$(($(tput cols) / 2 - 1))
            ls -1 --color=always -F | head -40 | awk -v width="$col_width" '
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
            ls --color=auto -F
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
    
    nautilus "$target_dir" >/dev/null 2>&1 &
    disown
    echo "Nautilus opened for: $(realpath "$target_dir")"
}
