################################
# Custom Startup Configuration #
################################

# Enable debug mode (set to "true" for verbose output, "false" to suppress messages)
DEBUG=false

# Start a new tmux session with a generated name if not already inside tmux
if [[ $- == *i* ]]; then
  if command -v tmux > /dev/null 2>&1 && [ -z "$TMUX" ]; then
    # Generate a unique session name
    SESSION_NAME="session-$(date +%s)"
    # Start a new tmux session or attach to an existing one
    tmux new-session -As "$SESSION_NAME"
    # Mark the session as temporary (not persistent)
    tmux set-option -t "$SESSION_NAME" @persistent 0
  fi
fi

# Function to load a prompt
load_prompt() {
    local prompt_path="$HOME/.config/truvium/shells/bash/prompts/$1.sh"
    if [ -f "$prompt_path" ]; then
        source "$prompt_path"
        $DEBUG && echo "DEBUG: Prompt loaded: $1 from $prompt_path"
    else
        echo "Error: Prompt $1 not found at $prompt_path" >&2
    fi
}

# TruVium welcome prompt for new tmux sessions
if [[ -n "$TMUX" ]]; then
  if [[ "$(tmux show-environment TMUX_WELCOME_SHOWN 2>/dev/null)" != "TMUX_WELCOME_SHOWN=1" ]]; then
    figlet TruVium | boxes | lolcat && fortune -s | lolcat
    tmux set-environment TMUX_WELCOME_SHOWN 1
  fi
fi

# Function to source all `.sh` files in a directory
source_directory() {
    local dir="$1"
    if [ -d "$dir" ]; then
        for file in "$dir"/*.sh; do
            [ "$(basename "$file")" = "init.sh" ] && continue
            if [ -f "$file" ] && [ -r "$file" ]; then
                source "$file"
                $DEBUG && echo "Loaded: $file"
            else
                echo "Warning: Unable to source $file" >&2
            fi
        done
    else
        echo "Warning: Directory $dir not found" >&2
    fi
}

# Load base Bash configurations
source_directory "$HOME/.config/truvium/shells/bash"

# Load CLI tool configurations
source_directory "$HOME/.config/truvium/shells/bash/tools"

# Change to your preferred prompt: starship, omp
load_prompt "omp"
