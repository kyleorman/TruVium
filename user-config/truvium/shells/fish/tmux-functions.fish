# Path to the Zsh script
set zsh_tmux_script "$HOME/path/to/tmux-script.zsh"

# Unified tmux_cmd function
function tmux_cmd
    zsh $zsh_tmux_script cmd $argv
end

# Usage examples in Fish:
# tmux_cmd toggle          # Toggle session persistence
# tmux_cmd start-cleanup   # Start the cleanup loop
# tmux_cmd stop-cleanup    # Stop the cleanup loop
# tmux_cmd check-cleanup   # Check if the cleanup loop is running
