######################
# Custom Environment #
######################

# Set general environment variables here
# Tool-specific variables are within the tool's own file

#--- PATH ---#
export PATH="$HOME/.local/bin:$PATH"
export PATH="/usr/bin:$PATH"
export PATH="$HOME/go/bin:$PATH"
export PATH="/usr/local/bin:$PATH"
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

#--- DISPLAY ---#
if [ -z "$DISPLAY" ]; then
    export DISPLAY="localhost:10.0"
fi

#--- EDITOR ---#
# export EDITOR="vim"

#--- VISUAL ---#
# export VISUAL="nvim"

#--- LANG ---#
# export LANG="en_US.UTF-8"

#--- LC_ALL ---#
# export LC_ALL="en_US.UTF-8"

#--- PAGER ---#
# export PAGER="less"

#--- MANPAGER ---#
# export MANPAGER="less -X"

#--- SHELL ---#
# export SHELL="/usr/bin/bash"

#--- TERM ---#
# export TERM="xterm-256color"

#--- HISTFILE ---#
# export HISTFILE="$HOME/.bash_history"

#--- HISTSIZE ---#
# export HISTSIZE=10000

#--- SAVEHIST ---#
# export SAVEHIST=10000

#--- XDG_CONFIG_HOME ---#
export XDG_CONFIG_HOME="$HOME/.config"

#--- TZ ---#
export TZ="America/New_York"

#--- LESS ---#
export LESS="-R"
