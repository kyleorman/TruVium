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
    local prompt_path="$HOME/.config/truvium/shells/zsh/prompts/$1.zsh"
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
    figlet TruVium | boxes | lolcat && fortune -s /usr/share/fortune/computers /usr/share/fortune/wisdom-fr /usr/share/fortune/hitchhiker /usr/share/fortune/science /usr/share/fortune/riddles | lolcat
    tmux set-environment TMUX_WELCOME_SHOWN 1
  fi
fi

# Function to source all `.zsh` files in a directory
source_directory() {
    local dir="$1"
    if [ -d "$dir" ]; then
        for file in "$dir"/*.zsh; do
            # Skip the `init.zsh` file or other files you want to exclude
            [ "$(basename "$file")" = "init.zsh" ] && continue
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

# Load base Zsh configurations
source_directory "$HOME/.config/truvium/shells/zsh"

# Load CLI tool configurations
source_directory "$HOME/.config/truvium/shells/zsh/tools"

# Only start the tmux cleanup process on loading into TruVium
if [[ -o interactive ]] && [[ -z "$TMUX" ]]; then
    # Check if cleanup is already running before starting
    tmux_cmd check-cleanup | grep -q "No periodic cleanup loop is running" && tmux_cmd start-cleanup
fi

# Change to your preferred prompt
# Default options: omz, starship, powerlevel10k, spaceship, omp
load_prompt "omz"