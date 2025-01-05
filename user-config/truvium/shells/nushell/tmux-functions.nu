let-env zsh_tmux_script = "~/.path/to/tmux-script.zsh"

# Unified tmux_cmd function
def tmux_cmd [args: string] {
    zsh $zsh_tmux_script cmd $args
}

# Usage examples in NuShell:
# tmux_cmd toggle          # Toggle session persistence
# tmux_cmd start-cleanup   # Start the cleanup loop
# tmux_cmd stop-cleanup    # Stop the cleanup loop
# tmux_cmd check-cleanup   # Check if the cleanup loop is running

