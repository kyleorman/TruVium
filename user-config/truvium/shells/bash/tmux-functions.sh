# Path to the Zsh script
ZSH_TMUX_SCRIPT="$HOME/.config/truvium/shells/zsh/tmux-functions.zsh"

# Unified tmux_cmd function
tmux_cmd() {
    zsh "$ZSH_TMUX_SCRIPT" cmd "$@"
}

# Usage examples in Bash:
# tmux_cmd toggle          # Toggle session persistence
# tmux_cmd start-cleanup   # Start the cleanup loop
# tmux_cmd stop-cleanup    # Stop the cleanup loop
# tmux_cmd check-cleanup   # Check if the cleanup loop is running

