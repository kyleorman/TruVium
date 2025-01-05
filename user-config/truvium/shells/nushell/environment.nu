######################
# Custom Environment #
######################

# Set general environment variables here
# Tool-specific variables are within the tool's own file

#--- PATH ---#
let-env PATH = ($nu.env.PATH | prepend ["~/.local/bin" "/usr/bin" "~/go/bin" "/usr/local/bin"])
source-env /home/vagrant/.cargo/env

#--- DISPLAY ---#
if not $nu.env.contains "DISPLAY" {
    let-env DISPLAY = "localhost:10.0"
}

#--- EDITOR ---#
# let-env EDITOR = "vim"

#--- VISUAL ---#
# let-env VISUAL = "nvim"

#--- LANG ---#
# let-env LANG = "en_US.UTF-8"

#--- LC_ALL ---#
# let-env LC_ALL = "en_US.UTF-8"

#--- PAGER ---#
# let-env PAGER = "less"

#--- MANPAGER ---#
# let-env MANPAGER = "less -X"

#--- SHELL ---#
# let-env SHELL = "/usr/bin/nu"

#--- TERM ---#
# let-env TERM = "xterm-256color"

#--- HISTSIZE ---#
# let-env HISTSIZE = "10000"

#--- SAVEHIST ---#
# let-env SAVEHIST = "10000"

#--- XDG_CONFIG_HOME ---#
let-env XDG_CONFIG_HOME = "~/.config"

#--- TZ ---#
let-env TZ = "America/New_York"

#--- LESS ---#
let-env LESS = "-R"

