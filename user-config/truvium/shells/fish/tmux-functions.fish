##################
# tmux-functions #
##################

# Path to the Zsh script
set -g zsh_tmux_script "$HOME/.config/truvium/shells/zsh/tmux-functions.zsh"

# Unified tmux_cmd function
function tmux_cmd
    if not test -f "$zsh_tmux_script"
        echo "Error: tmux script not found at $zsh_tmux_script" >&2
        return 1
    end

    if not command -v zsh >/dev/null 2>&1
        echo "Error: zsh is not installed or not in PATH" >&2
        return 1
    end

    # Execute the script with proper output handling
    set -l output (zsh -c "source $zsh_tmux_script; tmux_cmd $argv" 2>&1)
    set -l status_code $status

    # Only display output if there is any
    if test -n "$output"
        echo $output
    end

    return $status_code
end

# Override the tmux command to handle session creation
function tmux
    if set -q TMUX
        switch $argv[1]
            case "cmd"
                set -e argv[1]
                tmux_cmd $argv
            case '*'
                command tmux $argv
        end
    else if test (count $argv) -eq 0
        # Let zsh handle the session creation and cleanup setup
        zsh -c "source $zsh_tmux_script; tmux"
    else
        command tmux $argv
    end
end
