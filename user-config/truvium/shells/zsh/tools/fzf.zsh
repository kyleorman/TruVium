#######
# FZF #
#######

# [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
source <(fzf --zsh)

#--- setup fzf theme ---#
# Catppuccin Mocha colors
fg="#CDD6F4"
bg="#1E1E2E"
bg_highlight="#313244"
purple="#CBA6F7"
blue="#89B4FA"
cyan="#94E2D5"

# Apply colors to FZF
export FZF_DEFAULT_OPTS="--color=fg:${fg},bg:${bg},hl:${purple},fg+:${fg},bg+:${bg_highlight},hl+:${purple},info:${blue},prompt:${cyan},pointer:${cyan},marker:${cyan},spinner:${cyan},header:${cyan}"

#--- Use fd instead of find ---#
# Use fd (https://github.com/sharkdp/fd) for listing path candidates.

export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

# - The first argument to the function ($1) is the base path to start traversal
# - See the source code (completion.{bash,zsh}) for the details.
_fzf_compgen_path() {
  fd --hidden --exclude .git . "$1"
}

# Use fd to generate the list for directory completion
_fzf_compgen_dir() {
  fd --type=d --hidden --exclude .git . "$1"
}

source ~/fzf-git.sh/fzf-git.sh

# show_file_or_dir_preview="if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"

show_file_or_dir_preview="if [ -d {} ]; then
    eza --tree --color=always {} | head -200
elif file --mime-type {} | grep -q 'image/'; then
    if [ -n "$TMUX" ] && command -v kitty >/dev/null 2>&1; then
        convert {} -resize '800x800>' -resize '50%x50%>' - | kitty +kitten icat --transfer-mode=stream --align left --stdin yes --passthrough tmux 2>/dev/null
    elif command -v kitty >/dev/null 2>&1; then
        convert {} -resize '800x800>' -resize '50%x50%>' - | kitty +kitten icat --transfer-mode=memory --align left --stdin yes 2>/dev/null
    else
        file -b {}
    fi
else
    bat -n --color=always --line-range :500 {}
fi"

export FZF_CTRL_T_OPTS="--preview '$show_file_or_dir_preview'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"

# Advanced customization of fzf options via _fzf_comprun function
# - The first argument to the function is the name of the command.
# - You should make sure to pass the rest of the arguments to fzf.
_fzf_comprun() {
  local command=$1
  shift
  case "$command" in
    cd)           fzf --preview 'eza --tree --color=always {} | head -200' "$@" ;;
    export|unset) fzf --preview "eval 'echo \${}'"         "$@" ;;
    ssh)          fzf --preview 'dig {}'                   "$@" ;;
    *)            fzf --preview "$show_file_or_dir_preview" "$@" ;;
  esac
}
