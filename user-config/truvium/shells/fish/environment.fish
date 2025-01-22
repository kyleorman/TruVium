######################
# Custom Environment #
######################

# Set general environment variables here
# Tool-specific variables are within the tool's own file

#--- PATH ---#
set -gx PATH "$HOME/.local/bin" $PATH
set -gx PATH "/usr/bin" $PATH
set -gx PATH "$HOME/go/bin" $PATH
set -gx PATH "/usr/local/bin" $PATH
set -gx PATH $HOME/.cargo/bin $PATH

#--- DISPLAY ---#
if not set -q DISPLAY
    set -gx DISPLAY "localhost:10.0"
end

#--- EDITOR ---#
# set -gx EDITOR "vim"

#--- VISUAL ---#
# set -gx VISUAL "nvim"

#--- LANG ---#
# set -gx LANG "en_US.UTF-8"

#--- LC_ALL ---#
# set -gx LC_ALL "en_US.UTF-8"

#--- PAGER ---#
# set -gx PAGER "less"

#--- MANPAGER ---#
# set -gx MANPAGER "less -X"

#--- SHELL ---#
# set -gx SHELL "/usr/bin/fish"

#--- TERM ---#
# set -gx TERM "xterm-256color"

#--- HISTFILE ---#
# set -gx HISTFILE "~/.local/share/fish/fish_history"

#--- HISTSIZE ---#
# set -gx HISTSIZE 10000

#--- SAVEHIST ---#
# set -gx SAVEHIST 10000

#--- XDG_CONFIG_HOME ---#
set -gx XDG_CONFIG_HOME "$HOME/.config"

#--- TZ ---#
set -gx TZ "America/New_York"

#--- LESS ---#
set -gx LESS "-R"
