# ~/.bash_profile: executed by bash for login shells

# If .bashrc exists, source it
if [ -f "$HOME/.bashrc" ]; then
    source "$HOME/.bashrc"
fi

# Create a unique history file for each session
HISTDIR="$HOME/.bash_history.d"
mkdir -p "$HISTDIR"

# Generate unique history filename with timestamp
HISTFILE_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
HISTFILE_SESSION="$HISTDIR/history_${HISTFILE_TIMESTAMP}_$$"
HISTFILE="$HISTFILE_SESSION"

# Configure history settings
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups
HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S "
shopt -s histappend
shopt -s cmdhist

# Save history after every command
PROMPT_COMMAND="history -a; $PROMPT_COMMAND"

# Function to merge all history files
merge_history() {
    if [ -d "$HISTDIR" ]; then
        cat "$HISTDIR"/history_* | sort -k 2 > "$HOME/.bash_history_complete"
        echo "History merged to ~/.bash_history_complete"
    fi
}

# Create alias for merging history
alias histmerge='merge_history'

# Log session start in history
echo "# Session started: $(date)" >> "$HISTFILE"

# Display session information
echo "Using history file: $HISTFILE"
echo "Type 'histmerge' to consolidate all history files"

# Function to save history on exit
save_history_on_exit() {
    echo "# Session ended: $(date)" >> "$HISTFILE"
    history -a
}

# Register the exit trap
trap save_history_on_exit EXIT
