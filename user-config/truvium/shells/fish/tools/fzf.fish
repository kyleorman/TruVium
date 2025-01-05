#######
# FZF #
#######

# Source fzf integration script
fzf --fish | source

#--- FZF Theme Setup ---#
# Catppuccin Mocha colors
set fg "#CDD6F4"
set bg "#1E1E2E"
set bg_highlight "#313244"
set purple "#CBA6F7"
set blue "#89B4FA"
set cyan "#94E2D5"

# Apply colors to FZF
set -gx FZF_DEFAULT_OPTS "--color=fg:$fg,bg:$bg,hl:$purple,fg+:$fg,bg+:$bg_highlight,hl+:$purple,info:$blue,prompt:$cyan,pointer:$cyan,marker:$cyan,spinner:$cyan,header:$cyan"

#--- Use fd Instead of find ---#
set -gx FZF_DEFAULT_COMMAND "fd --hidden --strip-cwd-prefix --exclude .git"
set -gx FZF_CTRL_T_COMMAND $FZF_DEFAULT_COMMAND
set -gx FZF_ALT_C_COMMAND "fd --type=d --hidden --strip-cwd-prefix --exclude .git"

# Preview setup for files and directories
function show_file_or_dir_preview
    if test -d $argv
        eza --tree --color=always $argv | head -200
    else if file --mime-type $argv | grep -q 'image/'
        if test -n "$TMUX" -a (which kitty >/dev/null)
            convert $argv -resize '800x800>' -resize '50%x50%>' - | kitty +kitten icat --transfer-mode=stream --align left --stdin yes --passthrough tmux 2>/dev/null
        else if which kitty >/dev/null
            convert $argv -resize '800x800>' -resize '50%x50%>' - | kitty +kitten icat --transfer-mode=memory --align left --stdin yes 2>/dev/null
        else
            file -b $argv
        end
    else
        bat -n --color=always --line-range :500 $argv
    end
end

set -gx FZF_CTRL_T_OPTS "--preview 'show_file_or_dir_preview {}'"
set -gx FZF_ALT_C_OPTS "--preview 'eza --tree --color=always {} | head -200'"
