#######
# FZF #
#######

#--- FZF Theme Setup ---#
let-env FZF_DEFAULT_OPTS = "--color=fg:#CDD6F4,bg:#1E1E2E,hl:#CBA6F7,fg+:#CDD6F4,bg+:#313244,hl+:#CBA6F7,info:#89B4FA,prompt:#94E2D5,pointer:#94E2D5,marker:#94E2D5,spinner:#94E2D5,header:#94E2D5"

#--- Use fd Instead of find ---#
let-env FZF_DEFAULT_COMMAND = "fd --hidden --strip-cwd-prefix --exclude .git"
let-env FZF_CTRL_T_COMMAND = $FZF_DEFAULT_COMMAND
let-env FZF_ALT_C_COMMAND = "fd --type=d --hidden --strip-cwd-prefix --exclude .git"

# Preview setup for files and directories
def show_file_or_dir_preview [path] {
    if (path | path type | str contains "Dir") {
        eza --tree --color=always $path | first 200
    } else if (open $path | metadata type | str contains "image/") {
        echo "Image preview not yet supported in NuShell"
    } else {
        bat -n --color=always --line-range :500 $path
    }
}

let-env FZF_CTRL_T_OPTS = "--preview 'show_file_or_dir_preview {}'"
let-env FZF_ALT_C_OPTS = "--preview 'eza --tree --color=always {} | head -200'"
