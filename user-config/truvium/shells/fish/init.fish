#########################################
# Custom Startup Configuration for fish #
#########################################

# Enable debug mode (set to "true" for verbose output, "false" to suppress messages)
set -g DEBUG false

# Start a new tmux session with a generated name if not already inside tmux
if status is-interactive
    and not set -q TMUX
    and command -v tmux >/dev/null 2>&1
    # Generate a unique session name
    set -l SESSION_NAME "session-"(date +%s)"-"$fish_pid
    # Start a new tmux session or attach to an existing one
    tmux new-session -As "$SESSION_NAME"
    # Mark the session as temporary (not persistent)
    tmux set-option -t "$SESSION_NAME" @persistent 0
end

# Function to load a prompt
function load_prompt
    set -l prompt_path "$HOME/.config/truvium/shells/fish/prompts/$argv[1].fish"
    if test -f "$prompt_path"
        source "$prompt_path"
        test "$DEBUG" = true; and echo "DEBUG: Prompt loaded: $argv[1] from $prompt_path"
    else
        echo "Error: Prompt $argv[1] not found at $prompt_path" >&2
    end
end

# TruVium welcome prompt for new tmux sessions
if set -q TMUX
    set -l tmux_welcome (tmux show-environment TMUX_WELCOME_SHOWN 2>/dev/null)
    if test "$tmux_welcome" != "TMUX_WELCOME_SHOWN=1"
        figlet TruVium | boxes | lolcat
        and fortune -s /usr/share/fortune/computers /usr/share/fortune/wisdom-fr /usr/share/fortune/hitchhiker /usr/share/fortune/science /usr/share/fortune/riddles | lolcat
        tmux set-environment TMUX_WELCOME_SHOWN 1
    end
end

# Function to source all `.fish` files in a directory
function source_directory
    set -l dir $argv[1]
    if test -d "$dir"
        for file in "$dir"/*.fish
            # Skip the `init.fish` file or other files you want to exclude
            test (basename "$file") = "init.fish"; and continue
            if test -f "$file"; and test -r "$file"
                source "$file"
                test "$DEBUG" = true; and echo "Loaded: $file"
            else
                echo "Warning: Unable to source $file" >&2
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

# Only start the tmux cleanup process on loading into TruVium
if status is-interactive; and not set -q TMUX
    # Check if cleanup is already running before starting
    if tmux_cmd check-cleanup | grep -q "No periodic cleanup loop is running"
        tmux_cmd start-cleanup
    end
end

# Change to your preferred prompt
# Default options: starship, omp
load_prompt "omp"
