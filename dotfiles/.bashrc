# Add ~/scripts and ~/.local/bin to PATH if they exist
if [ -d "$HOME/.local/bin" ]; then
    PATH="$HOME/.local/bin:$PATH"
fi
if [ -d "$HOME/scripts" ]; then
    PATH="$HOME/scripts:$PATH"
fi
export PATH

# Aliases
alias ls='ls --color=auto -hF'
alias la='ls -Al'
alias ll='ls -alF'
alias l.='ls -d .* --color=auto'

alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

alias vim='vim -p' # Open multiple files in tabs
alias vi='vim'
alias svi='sudo vim'

alias update='sudo pacman -Syu'
alias cleanup='sudo pacman -Rns $(pacman -Qtdq)'

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

# Custom prompt