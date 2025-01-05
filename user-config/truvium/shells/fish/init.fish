################################
# Custom Startup Configuration #
################################

# Enable debug mode (set to "true" for verbose output, "false" to suppress messages)
set -g DEBUG false

# Start a new tmux session with a generated name if not already inside tmux
if status --is-interactive
    if type -q tmux
        if not set -q TMUX
            # Generate a unique session name
            set SESSION_NAME "session-(date +%s)"
            # Start a new tmux session or attach to an existing one
            tmux new-session -As "$SESSION_NAME"
            # Mark the session as temporary (not persistent)
            tmux set-option -t "$SESSION_NAME" @persistent 0
        end
    end
end

# Function to load a prompt
function load_prompt
    set prompt_path "$HOME/.config/truvium/shells/fish/prompts/$argv.fish"
    if test -f "$prompt_path"
        source "$prompt_path"
        if test $DEBUG = true
            echo "DEBUG: Prompt loaded: $argv from $prompt_path"
        end
    else
        echo "Error: Prompt $argv not found at $prompt_path" >&2
    end
end

# TruVium welcome prompt for new tmux sessions
if set -q TMUX
    if not tmux show-environment TMUX_WELCOME_SHOWN | grep -q "TMUX_WELCOME_SHOWN=1"
        figlet TruVium | boxes | lolcat
        fortune -s | lolcat
        tmux set-environment TMUX_WELCOME_SHOWN 1
    end
end

# Function to source all `.fish` files in a directory
function source_directory
    set dir "$argv"
    if test -d "$dir"
        for file in $dir/*.fish
            if test (basename $file) != "init.fish"
                if test -f "$file" -a -r "$file"
                    source "$file"
                    if test $DEBUG = true
                        echo "Loaded: $file"
                    end
                else
                    echo "Warning: Unable to source $file" >&2
                end
            end
        end
    else
        echo "Warning: Directory $dir not found" >&2
    end
end

# Load base Fish configurations
source_directory "$HOME/.config/truvium/shells/fish"

# Load CLI tool configurations
source_directory "$HOME/.config/truvium/shells/fish/tools"

# Change to your preferred prompt: starship, omp
load_prompt "starship"
