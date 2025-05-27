# Add ~/scripts and ~/.local/bin to PATH if they exist
if [ -d "$HOME/.local/bin" ]; then
    PATH="$HOME/.local/bin:$PATH"
fi
if [ -d "$HOME/scripts" ]; then
    PATH="$HOME/scripts:$PATH"
fi
export PATH

# History configuration
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups
HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S "
shopt -s histappend
shopt -s checkwinsize

# Aliases
alias ls='ls --color=auto -hF'
alias la='ls -Al'
alias ll='ls -alF'
alias l.='ls -d .* --color=auto'
alias lslac='ls -la --color=auto'

alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias rgrep='grep -r --color=auto'

alias vim='vim -p' # Open multiple files in tabs
alias vi='vim'
alias svi='sudo vim'
alias e='vim'

alias update='sudo pacman -Syu'
alias cleanup='sudo pacman -Rns $(pacman -Qtdq)'

# System monitoring shortcuts
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias disk='df -h | grep -v loop'
alias mem='free -h | grep -i mem'

# Plasma/X11
alias kstart='dbus-run-session startplasma-wayland'
alias xstart='startx'

# Helper script aliases
# displayctl.sh is a user script, assuming it's in ~/scripts or ~/.local/bin
alias dc='displayuctl.sh'
# sessionctl.sh (sc) is run as root from /root to switch to user nikunj. No alias needed for nikunj.
# efibootmgr_helper.sh (ebm) requires root. Run with 'sudo /path/to/efibootmgr_helper.sh'.
# sbsign_helper.sh (sbs) requires root. Run with 'sudo /path/to/sbsign_helper.sh'.
# keytool_helper.sh (kth) requires root. Run with 'sudo /path/to/keytool_helper.sh'.
# mounter.sh (mntr) is for the live Arch environment.
# pacstrapper.sh (pstrap) is for the live Arch environment.

# Better process monitoring
alias psg='ps aux | grep -v grep | grep -i -e VSZ -e'
alias psm='ps aux | sort -nrk 4 | head -10' # Sort by memory usage
alias psc='ps aux | sort -nrk 3 | head -10' # Sort by CPU usage

# Custom prompt with git support
parse_git_branch() {
    git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/[\1]/'
}

# Check if command is available
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Define colors
RESET="\[\033[0m\]"
BLACK="\[\033[0;30m\]"
RED="\[\033[0;31m\]"
GREEN="\[\033[0;32m\]"
YELLOW="\[\033[0;33m\]"
BLUE="\[\033[0;34m\]"
PURPLE="\[\033[0;35m\]"
CYAN="\[\033[0;36m\]"
WHITE="\[\033[0;37m\]"
BOLD_RED="\[\033[1;31m\]"
BOLD_GREEN="\[\033[1;32m\]"
BOLD_YELLOW="\[\033[1;33m\]"
BOLD_BLUE="\[\033[1;34m\]"

# Set prompt
set_prompt() {
    local exit_code=$?
    
    # Exit code color (red if error)
    local exit_color="${GREEN}"
    if [ $exit_code -ne 0 ]; then
        exit_color="${BOLD_RED}"
    fi

    # Git branch
    local git_info=""
    if command_exists git; then
        git_branch=$(parse_git_branch)
        if [ ! -z "$git_branch" ]; then
            git_info="${PURPLE}${git_branch} "
        fi
    fi

    # Determine if running as root
    local user_color="${GREEN}"
    if [ $UID -eq 0 ]; then
        user_color="${BOLD_RED}"
    fi

    # Final prompt composition
    PS1="${BOLD_BLUE}[\!]${RESET} ${user_color}\u${RESET}@${CYAN}\h${RESET}:${BOLD_YELLOW}\w${RESET} ${git_info}${exit_color}\$${RESET} "
}

# Set the prompt command to run before each prompt
PROMPT_COMMAND=set_prompt

# Enable programmable completion features
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi