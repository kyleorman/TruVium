##################
# tmux-functions #
##################

# Path to the Zsh script
ZSH_TMUX_SCRIPT="$HOME/.config/truvium/shells/zsh/tmux-functions.zsh"

# Unified tmux_cmd function
tmux_cmd() {
    if [[ ! -f "$ZSH_TMUX_SCRIPT" ]]; then
        echo "Error: tmux script not found at $ZSH_TMUX_SCRIPT" >&2
        return 1
    fi

    if ! command -v zsh >/dev/null 2>&1; then
        echo "Error: zsh is not installed or not in PATH" >&2
        return 1
    fi

    # Execute the script with proper output handling
    output=$(zsh -c "source $ZSH_TMUX_SCRIPT; tmux_cmd $*" 2>&1)
    status=$?

    # Only display output if there is any
    if [[ -n "$output" ]]; then
        echo "$output"
    fi

    return $status
}

# Override the tmux command to handle session creation
tmux() {
    if [[ -n "$TMUX" ]]; then
        case "$1" in
            cmd)
                shift
                tmux_cmd "$@"
                ;;
            *)
                command tmux "$@"
                ;;
        esac
    elif [[ $# -eq 0 ]]; then
        # Let zsh handle the session creation and cleanup setup
        zsh -c "source $ZSH_TMUX_SCRIPT; tmux"
    else
        command tmux "$@"
    fi
}
