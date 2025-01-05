########################################
# Custom Startup Configuration for Nu #
########################################

# Debug mode
let DEBUG = false

# Start a new tmux session with a generated name if not already inside tmux
if $nu.env.is_interactive {
    let is_tmux_running = $nu.env.contains "TMUX"
    if not $is_tmux_running {
        let SESSION_NAME = (date now | date to-int)
        tmux new-session -As $"session-($SESSION_NAME)"
        tmux set-option -t $"session-($SESSION_NAME)" @persistent 0
    }
}

# Load a prompt
def load_prompt [prompt_name] {
    let prompt_path = $"~/.config/truvium/shells/nushell/prompts/($prompt_name).nu"
    if (ls $prompt_path | length) > 0 {
        source-env $prompt_path
        if $DEBUG { print $"DEBUG: Prompt loaded: ($prompt_name) from ($prompt_path)" }
    } else {
        print $"Error: Prompt ($prompt_name) not found at ($prompt_path)"
    }
}

# Welcome prompt for new tmux sessions
if $nu.env.contains "TMUX" {
    if (tmux show-environment | lines | where .contains "TMUX_WELCOME_SHOWN=1" | length) == 0 {
        figlet TruVium | boxes | lolcat
        fortune -s | lolcat
        tmux set-environment TMUX_WELCOME_SHOWN 1
    }
}

# Source all `.nu` files in a directory
def source_directory [dir] {
    if (ls $dir | length) > 0 {
        ls $dir | each { |file|
            if $file.name != "init.nu" {
                source-env $"($file.name)"
                if $DEBUG { print $"Loaded: ($file.name)" }
            }
        }
    } else {
        print $"Warning: Directory ($dir) not found"
    }
}

# Load base NuShell configurations
source_directory ~/.config/truvium/shells/nushell

# Load CLI tool configurations
source_directory ~/.config/truvium/shells/nushell/tools

# Change to your preferred prompt: starship, omp
load_prompt "starship"

