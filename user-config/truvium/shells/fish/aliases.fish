##################
# Custom Aliases #
##################

#--- Emacs ---#

# Emacs to run in terminal rather than GUI
alias emacs="emacs -nw"

#--- Eza (better ls) ---#

# Replace 'ls' with eza and add visually appealing defaults
alias ls="eza --group-directories-first --color=always --icons"

# Long listing format with human-readable sizes and clear separation
alias ll="eza -lh --group-directories-first --icons"

# Show all files, including hidden ones, with a detailed and readable layout
alias la="eza -lha --group-directories-first --icons"

# Tree view with 2-levels
alias lt="eza --tree --level=2 --icons"

# Full-depth tree, including hidden files
alias lta="eza --tree -a --icons"

# Shallow tree for quick overviews
alias lst="eza --tree --level=1 --icons"

#--- Zoxide (better cd) ---#

# Replace cd with z for directory memory
alias cd="z"

#--- The Fuck (command correction) ---#

# Sets the alias to fk
if command -q thefuck
    thefuck --alias | source
end
