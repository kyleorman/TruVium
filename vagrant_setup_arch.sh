#!/bin/bash

# Exit immediately if a command exits with a non-zero status,
# if any undefined variable is used, and if any command in a pipeline fails
set -eEuo pipefail
IFS=$'\n\t'

# --- Configuration Variables ---
SCRIPT_DIR="/vagrant"  # Directory where the script is being executed
LOGFILE="/var/log/setup-script.log"
TMP_DIR="/tmp/setup_script_install"
INSTALL_PREFIX="/usr/local"

# Determine the actual user (non-root)
if [ "${SUDO_USER:-}" ]; then
    ACTUAL_USER="$SUDO_USER"
    USER_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
else
    echo "This script must be run with sudo."
    exit 1
fi

# Export environment variable to indicate the setup script is running
export ACTUAL_USER
export SETUP_SCRIPT_RUNNING=true

# Redirect all output to LOGFILE with timestamps
exec > >(while IFS= read -r line; do echo "$(date '+%Y-%m-%d %H:%M:%S') - $line"; done | tee -a "$LOGFILE") 2>&1

# --- Trap for Cleanup ---
cleanup() {
    echo "----- Cleaning Up Temporary Directories and Files -----"
    
    # Remove general temporary installation directory
    if [ -d "$TMP_DIR" ]; then
        echo "Removing temporary directory: $TMP_DIR"
        rm -rf "$TMP_DIR" || echo "Failed to remove $TMP_DIR"
    else
        echo "Temporary directory $TMP_DIR does not exist. Skipping."
    fi
    
    # Unset the environment variable after setup
    unset SETUP_SCRIPT_RUNNING

    echo "----- Cleanup Completed -----"
}
trap cleanup ERR EXIT

# --- Function Definitions ---

# Function to check internet connection
check_internet_connection() {
    echo "Checking for an active internet connection..."
    local hosts=("8.8.8.8" "www.google.com" "www.github.com")
    local success=false

    for host in "${hosts[@]}"; do
        if ping -c 1 -W 2 "$host" &>/dev/null; then
            echo "Successfully connected to $host."
            success=true
            break
        else
            echo "Failed to reach $host."
        fi
    done

    if ! $success; then
        echo "Internet connection required. Please check your network."
        exit 1
    else
        echo "Internet connection is active."
    fi
}

# Function to install essential packages
install_dependencies() {
    echo "Installing essential packages..."
    pacman -Syu --noconfirm
    pacman -S --noconfirm \
        autoconf \
        automake \
        pkgconf \
        libevent \
        ncurses \
        base-devel \
        git \
        bison \
        ninja \
        curl \
        wget \
        python \
        python-pip \
        python-pipenv \
        lua \
        cmake \
        zsh \
        perl \
        gcc-ada \
        zlib \
        gperf \
        flex \
        desktop-file-utils \
        gtk3 \
        gtk4 \
        judy \
        bzip2 \
        gobject-introspection \
        ctags \
        htop \
        vagrant \
        virtualbox-guest-utils \
        shellcheck \
        pandoc \
        ttf-powerline-symbols \
        grep \
        sed \
        bc \
        xclip \
        acpi \
        passwd \
        xorg-xauth \
        xorg-server \
        openbox \
        xdg-utils \
        python \
        lua \
        perl \
        ruby \
        clang \
        perl-app-cpanminus \
        jdk11-openjdk \
        maven \
        tree \
        copyq \
        ncurses \
        tcl \
        || { echo "Package installation failed"; exit 1; }
}

# Function to install tmux via pacman
install_tmux_via_pacman() {
    echo "Installing tmux via pacman..."
    pacman -S --noconfirm tmux
}

# Function to install Vim via pacman
install_vim_via_pacman() {
    echo "Installing Vim via pacman..."
    pacman -S --noconfirm vim
}

# Function to install Neovim via pacman
install_neovim_via_pacman() {
    echo "Installing Neovim via pacman..."
    pacman -S --noconfirm neovim
}

# Function to install Emacs via pacman
install_emacs_via_pacman() {
    echo "Installing Emacs via pacman..."
    pacman -S --noconfirm emacs
}

# Function to install Node.js via pacman
install_nodejs_via_pacman() {
    echo "Installing Node.js via pacman..."
    pacman -S --noconfirm nodejs npm
}

# Function to install Go via pacman
install_golang_via_pacman() {
    echo "Installing Go via pacman..."
    pacman -S --noconfirm go
}

# Function to install Doxygen via pacman
install_doxygen_via_pacman() {
    echo "Installing Doxygen via pacman..."
    pacman -S --noconfirm doxygen
}

# Function to install FZF via pacman
install_fzf_via_pacman() {
    echo "Installing FZF via pacman..."
    pacman -S --noconfirm fzf
}

# Function to install GTKWAVE via pacman
install_gtkwave_via_pacman() {
    echo "Installing GTKWAVE via pacman..."
    pacman -S --noconfirm gtkwave
}

# Function to install GHDL via pacman
install_ghdl_via_pacman() {
    echo "Installing GHDL via pacman..."
    pacman -S --noconfirm ghdl
}

# Function to install language servers
install_language_servers() {
    echo "Installing language servers..."

    npm install -g npm

    # Install npm-based language servers
    npm install -g bash-language-server @imc-trading/svlangserver yaml-language-server vscode-langservers-extracted typescript typescript-language-server pyright

    # Install TexLab via pacman
    pacman -S --noconfirm texlab

    # Install Perl Language Server
    echo "Installing Perl Language Server via cpanminus..."
    cpanm Perl::LanguageServer || { echo "Failed to install Perl::LanguageServer"; exit 1; }

    # Install Go Language Server
    echo "Installing Go Language Server (gopls)..."
    su - "$ACTUAL_USER" -c "go install golang.org/x/tools/gopls@latest" || { echo "Failed to install gopls"; exit 1; }
}

# Function to install Python tools
install_python_tools() {
    echo "Installing Python tools..."
    pip install --upgrade pip
    pip install flake8 pylint black mypy autopep8 jedi doq hdl-checker vsg tox ipython jupyter jupyter-console meson pexpect || { echo "Failed to install Python tools"; exit 1; }
}

# Function to install CheckMake via Go
install_checkmake() {
    echo "Installing CheckMake via Go..."
    su - "$ACTUAL_USER" -c "go install github.com/mrtazz/checkmake/cmd/checkmake@latest" || { echo "CheckMake installation failed"; exit 1; }
    echo 'export PATH="$HOME/go/bin:$PATH"' >> "$USER_HOME/.zshrc"
}

# Function to install Tmux Plugin Manager and tmux plugins
install_tpm() {
    echo "Installing Tmux Plugin Manager (TPM) and tmux plugins..."
    ensure_tpm_installed
    automate_tpm_install
    check_tpm_installation
    echo "Tmux Plugin Manager and plugins installed successfully."
}

# Function to ensure TPM (Tmux Plugin Manager) is installed
ensure_tpm_installed() {
    echo "Verifying Tmux Plugin Manager (TPM) installation..."
    TPM_DIR="$USER_HOME/.tmux/plugins/tpm"
    if [ ! -d "$TPM_DIR" ]; then
        echo "Cloning Tmux Plugin Manager (TPM)..."
        su - "$ACTUAL_USER" -c "git clone https://github.com/tmux-plugins/tpm '$TPM_DIR'" || {
            echo "Failed to clone TPM."
            exit 1
        }
    else
        echo "TPM is already installed."
    fi
}

# Function to automate TPM's plugin installation
automate_tpm_install() {
    echo "Automating TPM plugin installation..."

    # Initialize TPM in .tmux.conf if not already present
    if ! grep -q "run '~/.tmux/plugins/tpm/tpm'" "$USER_HOME/.tmux.conf"; then
        echo "Initializing TPM in .tmux.conf..."
        echo "run '~/.tmux/plugins/tpm/tpm'" >> "$USER_HOME/.tmux.conf"
    else
        echo "TPM initialization already present in .tmux.conf."
    fi

    # Reload tmux environment and install plugins using the absolute path to tmux
    tmux new-session -d -s tpm_install "/usr/bin/tmux source ~/.tmux.conf && ~/.tmux/plugins/tpm/bin/install_plugins && /usr/bin/tmux source ~/.tmux.conf &&  ~/.tmux/plugins/tpm/bin/update_plugins all && /usr/bin/tmux source ~/.tmux.conf"
    echo "TPM plugin installation triggered."
}

# Function to check if TPM plugins are installed
check_tpm_installation() {
    echo "Checking if TPM plugins are installed..."

    # Check if TPM plugin directory exists
    if [ -d "$USER_HOME/.tmux/plugins/tpm" ]; then
        echo "TPM and plugins seem to be installed."
    else
        echo "TPM is not installed. Please install TPM and press <prefix> + I to install plugins."
    fi
}

# Function to kill any running tmux sessions
kill_tmux_sessions() {
    echo "Killing any running tmux sessions before Oh My Zsh installation..."
    if tmux ls &> /dev/null; then
        tmux kill-server
        echo "tmux server stopped."
    else
        echo "No tmux sessions were running."
    fi
}

# Function to install oh-my-zsh
setup_zsh() {
    # Backup existing .zshrc if it exists
    if [ -f "$USER_HOME/.zshrc" ]; then
        cp "$USER_HOME/.zshrc" "$USER_HOME/.zshrc.bak"
        echo "Existing .zshrc backed up to $USER_HOME/.zshrc.bak"
    fi

    echo "Installing Oh My Zsh for $ACTUAL_USER..."

    # Download the Oh My Zsh install script into the user's home directory
    INSTALL_SCRIPT="$USER_HOME/install_oh_my_zsh.sh"
    curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o "$INSTALL_SCRIPT" || {
        echo "Failed to download Oh My Zsh install script"; exit 1;
    }
    chmod +x "$INSTALL_SCRIPT"
    chown "$ACTUAL_USER:$ACTUAL_USER" "$INSTALL_SCRIPT"

    # Run the install script as the actual user using su -
    su - "$ACTUAL_USER" -c "sh '$INSTALL_SCRIPT' --unattended" || {
        echo "Oh My Zsh installation failed"; return 1;
    }

    # Remove the install script
    rm "$INSTALL_SCRIPT"

    # Append new configuration to .zshrc with interactive shell check
    echo "Setting up .zshrc for $ACTUAL_USER..."
    {
        echo 'export PATH="$HOME/.local/bin:$PATH"'
        echo 'export PATH="/usr/bin:$PATH"'
        echo 'export PATH="$HOME/go/bin:$PATH"'
        echo 'export PATH="/usr/local/bin:$PATH"'
        echo 'export PATH="/usr/local/go/bin:$PATH"'
        echo 'alias emacs="emacs -nw"'
        echo '[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh'
        echo ''
        echo 'if [[ $- == *i* ]]; then'  # Check if the shell is interactive
        echo '  if command -v tmux > /dev/null 2>&1 && [ -z "$TMUX" ]; then'
        echo '    if tmux has-session -t default 2> /dev/null; then'
        echo '      tmux attach-session -t default'
        echo '    else'
        echo '      tmux new-session -s default'
        echo '    fi'
        echo '  fi'
        echo 'fi'
    } >> "$USER_HOME/.zshrc"

    # Ensure the .zshrc is owned by the actual user
    chown "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME/.zshrc"
}

# Function to clone Zsh plugins
clone_zsh_plugins() {
    echo "Cloning Zsh plugins..."
    ZSH_CUSTOM="${ZSH_CUSTOM:-$USER_HOME/.oh-my-zsh/custom}"

    su - "$ACTUAL_USER" -c "git clone https://github.com/zsh-users/zsh-syntax-highlighting.git '$ZSH_CUSTOM/plugins/zsh-syntax-highlighting'" || true
    su - "$ACTUAL_USER" -c "git clone https://github.com/zsh-users/zsh-autosuggestions.git '$ZSH_CUSTOM/plugins/zsh-autosuggestions'" || true

    # Update .zshrc plugins line
    DESIRED_PLUGINS='plugins=(git zsh-syntax-highlighting zsh-autosuggestions)'
    if grep -q "^plugins=" "$USER_HOME/.zshrc"; then
        sed -i "s/^plugins=.*/$DESIRED_PLUGINS/" "$USER_HOME/.zshrc"
    else
        sed -i "/^source .*oh-my-zsh.sh/a $DESIRED_PLUGINS" "$USER_HOME/.zshrc"
    fi

    echo "Plugins configured in .zshrc."

    # Ensure correct ownership and permissions
    chown "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME/.zshrc"
    chmod 644 "$USER_HOME/.zshrc"
}

# Function to install FZF via pacman
install_fzf_via_pacman() {
    echo "Installing FZF via pacman..."
    pacman -S --noconfirm fzf
}

# Function to install Vim plugins
install_vim_plugins_all() {
    install_vim_plugins
    setup_ftdetect_symlinks
}

# Function to install Vim plugins
install_vim_plugins() {
    echo "Starting Vim plugin installation..."

    # Define plugin arrays
    START_PLUGINS=(
        "preservim/nerdtree"
        "preservim/vimux"
        "christoomey/vim-tmux-navigator"
        "vim-airline/vim-airline"
        "vim-airline/vim-airline-themes"
        "junegunn/fzf"
        "junegunn/fzf.vim"
        "junegunn/vim-easy-align"
        "easymotion/vim-easymotion"
        "tpope/vim-fugitive"
        "tpope/vim-rhubarb"
        "dense-analysis/ale"
        "neoclide/coc.nvim"
        "tpope/vim-surround"
        "SirVer/ultisnips"
        "honza/vim-snippets"
        "preservim/tagbar"
        "preservim/nerdcommenter"
        "github/copilot.vim"
        "davidhalter/jedi-vim"
        "heavenshell/vim-pydocstring"
        "mrtazz/checkmake"
        "vim-syntastic/syntastic"
        "jpalardy/vim-slime"
        "lervag/vimtex"
        "pangloss/vim-javascript"
        "elzr/vim-json"
        "stephpy/vim-yaml"
        "vim-python/python-syntax"
        "liuchengxu/vim-which-key"
        "mkitt/tabline.vim"
        "edkolev/tmuxline.vim"
        "airblade/vim-gitgutter"
        "bling/vim-bufferline"
        "mbbill/undotree"
    )

    OPTIONAL_PLUGINS=(
        "klen/python-mode"
        "suoto/hdl_checker"
        "vim-perl/vim-perl"
        "octol/vim-cpp-enhanced-highlight"
        "nsf/gocode"
        "daeyun/vim-matlab"
    )

    COLOR_SCHEMES=(
        "altercation/vim-colors-solarized"
        "rafi/awesome-vim-colorschemes"
    )

    # Define plugin directories
    START_PLUGIN_DIR="$USER_HOME/.vim/pack/plugins/start"
    OPT_PLUGIN_DIR="$USER_HOME/.vim/pack/plugins/opt"
    COLOR_PLUGIN_DIR="$USER_HOME/.vim/pack/colors/start"

    # Ensure plugin directories exist
    su - "$ACTUAL_USER" -c "mkdir -p '$START_PLUGIN_DIR'"
    su - "$ACTUAL_USER" -c "mkdir -p '$OPT_PLUGIN_DIR'"
    su - "$ACTUAL_USER" -c "mkdir -p '$COLOR_PLUGIN_DIR'"

    # Clone essential start plugins
    echo "Cloning essential start plugins..."
    for plugin in "${START_PLUGINS[@]}"; do
        plugin_name=$(basename "$plugin")
        target_path="$START_PLUGIN_DIR/$plugin_name"
        clone_plugin "$plugin" "$target_path"
    done

    # Clone optional plugins
    echo "Cloning optional plugins..."
    for plugin in "${OPTIONAL_PLUGINS[@]}"; do
        plugin_name=$(basename "$plugin")
        target_path="$OPT_PLUGIN_DIR/$plugin_name"
        clone_plugin "$plugin" "$target_path"
    done

    # Clone color schemes
    echo "Cloning color schemes..."
    for color in "${COLOR_SCHEMES[@]}"; do
        color_name=$(basename "$color")
        target_path="$COLOR_PLUGIN_DIR/$color_name"
        clone_plugin "$color" "$target_path"
    done

    # Generate helptags for all plugins
    echo "Generating helptags for plugins..."

    # Generate helptags for start plugins
    for plugin in "${START_PLUGINS[@]}"; do
        plugin_name=$(basename "$plugin")
        target_path="$START_PLUGIN_DIR/$plugin_name"
        generate_helptags "$target_path"
    done

    # Generate helptags for optional plugins
    for plugin in "${OPTIONAL_PLUGINS[@]}"; do
        plugin_name=$(basename "$plugin")
        target_path="$OPT_PLUGIN_DIR/$plugin_name"
        generate_helptags "$target_path"
    done

    # Generate helptags for color schemes
    for plugin in "${COLOR_SCHEMES[@]}"; do
        plugin_name=$(basename "$plugin")
        target_path="$COLOR_PLUGIN_DIR/$plugin_name"
        generate_helptags "$target_path"
    done

    echo "Vim plugins installed and helptags generated successfully."
}

# Function to clone a Git repository if it doesn't already exist
clone_plugin() {
    local repo="$1"
    local target_dir="$2"

    if [ -d "$target_dir" ]; then
        echo "Plugin '$repo' already exists at '$target_dir'. Skipping clone."
    else
        echo "Cloning '$repo' into '$target_dir'..."
        su - "$ACTUAL_USER" -c "git clone --depth=1 https://github.com/$repo.git $target_dir" || {
            echo "Error: Failed to clone '$repo' into '$target_dir'."
            exit 1
        }
        echo "Successfully cloned '$repo'."
    fi
}

# Function to generate helptags for a Vim plugin
generate_helptags() {
    local plugin_dir="$1"
    local doc_dir="$plugin_dir/doc"

    if [ -d "$doc_dir" ]; then
        echo "Generating helptags for plugin at '$plugin_dir'..."
        vim -u NONE -c "helptags $doc_dir" -c "qa!" || {
            echo "Warning: Failed to generate helptags for '$plugin_dir'."
        }
    fi
}

# Function to set up ftdetect symlinks
setup_ftdetect_symlinks() {
    FTDETECT_SRC_DIR="$START_PLUGIN_DIR/ultisnips/ftdetect"
    FTDETECT_DEST_DIR="$USER_HOME/.vim/ftdetect"

    echo "Setting up ftdetect symbolic links..."

    # Ensure the destination directory exists
    su - "$ACTUAL_USER" -c "mkdir -p '$FTDETECT_DEST_DIR'"

    # Check if the source directory exists and contains files
    if [ -d "$FTDETECT_SRC_DIR" ] && [ "$(ls -A "$FTDETECT_SRC_DIR")" ]; then
        for src_file in "$FTDETECT_SRC_DIR"/*; do
            # Extract the filename
            filename="$(basename "$src_file")"
            dest_file="$FTDETECT_DEST_DIR/$filename"

            # Check if the destination symlink already exists
            if [ -L "$dest_file" ]; then
                echo "Symlink for $filename already exists. Skipping."
            elif [ -e "$dest_file" ]; then
                echo "A file named $filename exists and is not a symlink. Skipping to avoid overwriting."
            else
                # Create the symbolic link
                ln -s "$src_file" "$dest_file" && \
                    echo "Created symlink: $dest_file -> $src_file" || \
                    echo "Failed to create symlink for $filename"
            fi
        done
    else
        echo "No ftdetect files found in $FTDETECT_SRC_DIR. Skipping symlink creation."
    fi
}

# Function to copy configuration files
copy_config_files() {
    echo "Copying configuration files to user home directory..."

    # Declare an associative array of source and destination files
    declare -A CONFIG_FILES=(
        ["vimrc"]=".vimrc"
        ["tmux.conf"]=".tmux.conf"
        ["tmux_keys.sh"]=".tmux_keys.sh"
        ["coc-settings.json"]=".vim/coc-settings.json"
        ["hdl_checker.json"]=".vim/hdl_checker.json"
        ["airline_theme.conf"]=".vim/airline_theme.conf"
        ["color_scheme.conf"]=".vim/color_scheme.conf"
    )

    for src in "${!CONFIG_FILES[@]}"; do
        dest="${CONFIG_FILES[$src]}"
        src_path="$SCRIPT_DIR/$src"
        dest_path="$USER_HOME/$dest"
        
        if [ -f "$dest_path" ]; then
            mv "$dest_path" "${dest_path}.bak"
            echo "Existing $dest_path backed up to ${dest_path}.bak"
        fi
        
        # Ensure the destination directory exists
        dest_dir=$(dirname "$dest_path")
        su - "$ACTUAL_USER" -c "mkdir -p '$dest_dir'"

        if [ -f "$src_path" ]; then
            cp "$src_path" "$dest_path"
            chown "$ACTUAL_USER:$ACTUAL_USER" "$dest_path"
            chmod 644 "$dest_path"
            echo "$src copied successfully to $dest_path."
        else
            echo "Warning: $src not found in $SCRIPT_DIR. Skipping copy."
        fi
    done

    # Copy 'yank' to /usr/local/bin
    echo "Copying 'yank' to /usr/local/bin..."
    if [ -f "$SCRIPT_DIR/yank" ]; then
        cp "$SCRIPT_DIR/yank" "/usr/local/bin/yank"
        chown root:root "/usr/local/bin/yank"
        chmod 755 "/usr/local/bin/yank"
        echo "'yank' copied successfully to /usr/local/bin."
    else
        echo "Warning: 'yank' not found in $SCRIPT_DIR. Skipping copy."
    fi
}

# Function to configure Git
configure_git() {
    GIT_SETUP_SCRIPT="$SCRIPT_DIR/git_setup.sh"
    GIT_SETUP_CONF="$SCRIPT_DIR/git_setup.conf"

    echo "Configuring Git..."

    if [ -f "$GIT_SETUP_SCRIPT" ] && [ -f "$GIT_SETUP_CONF" ]; then
        if su - "$ACTUAL_USER" -c "bash '$GIT_SETUP_SCRIPT' --config-file '$GIT_SETUP_CONF' --non-interactive"; then
            echo "Git configured successfully."
        else
            echo "Git configuration failed."
            exit 1
        fi
    else
        echo "Error: Git setup scripts or configuration files are missing."
        exit 1
    fi
}

# Function to install coc.nvim dependencies
install_coc_dependencies() {
    echo "Installing dependencies for coc.nvim..."

    COC_DIR="$USER_HOME/.vim/pack/plugins/start/coc.nvim"

    if [ -d "$COC_DIR" ]; then
        echo "Changing ownership of coc.nvim directory to $ACTUAL_USER..."
        chown -R "$ACTUAL_USER:$ACTUAL_USER" "$COC_DIR"

        echo "Running 'npm ci' in coc.nvim directory..."
        su - "$ACTUAL_USER" bash -c "cd '$COC_DIR' && npm ci" || {
            echo "Error: Failed to install dependencies for coc.nvim."
            exit 1
        }
        echo "Dependencies for coc.nvim installed successfully."
    else
        echo "Error: coc.nvim directory not found at '$COC_DIR'."
        exit 1
    fi
}

# Function to ensure the home directory is owned by the actual user
ensure_home_ownership() {
    echo "----- Ensuring ownership of home directory -----"
    
    echo "Setting ownership of home directory to $ACTUAL_USER..."
    if chown -R "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME"; then
        echo "Ownership of $USER_HOME set to $ACTUAL_USER successfully."
    else
        echo "Error: Failed to set ownership for $USER_HOME."
        exit 1
    fi
    
    echo "----- Home directory ownership ensured -----"
}

# Function to install LazyVim
install_lazyvim() {
    echo "Installing LazyVim..."

    # Ensure Neovim 0.9 or higher is installed
    if ! command -v nvim &> /dev/null || ! nvim --version | awk 'NR==1 {exit ($2 < 0.9)}'; then
        echo "Neovim 0.9 or higher is not installed. Please install it before proceeding."
        return 1
    fi

    # Ensure git is installed
    pacman -S --noconfirm git || { echo "Failed to install git"; exit 1; }

    # Clone the LazyVim starter repository
    LAZYVIM_DIR="$USER_HOME/.config/nvim"
    if [ ! -d "$LAZYVIM_DIR" ]; then
        echo "Cloning LazyVim starter repository..."
        su - "$ACTUAL_USER" -c "git clone https://github.com/LazyVim/starter '$LAZYVIM_DIR'" || {
            echo "Failed to clone LazyVim starter repository"; 
            exit 1;
        }
    else
        echo "LazyVim starter repository is already cloned in $LAZYVIM_DIR."
    fi

    # Install Neovim plugin manager (lazy.nvim)
    if [ ! -d "$USER_HOME/.local/share/nvim/lazy" ]; then
        echo "Installing lazy.nvim plugin manager..."
        su - "$ACTUAL_USER" -c "git clone https://github.com/folke/lazy.nvim.git --branch=stable '$USER_HOME/.local/share/nvim/lazy'" || {
            echo "Failed to install lazy.nvim"; 
            exit 1;
        }
    else
        echo "lazy.nvim is already installed."
    fi

    # Ensure proper ownership of the Neovim directories
    chown -R "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME/.config/nvim" "$USER_HOME/.local/share/nvim"

    # Optional: Run LazyVim's check health command
    echo "Running :checkhealth to diagnose potential issues..."
    su - "$ACTUAL_USER" -c "nvim --headless '+Lazy! sync' +qa" || echo "Check health reported issues."

    echo "LazyVim installed successfully."
}

# Install Doom Emacs (optional)
install_doom_emacs() {
    echo "Installing Doom Emacs..."

    # Check if Emacs is installed and version is 26.1 or higher
    if ! command -v emacs &>/dev/null || ! emacs --version | awk 'NR==1 {exit ($3 < 26.1)}'; then
        echo "Emacs 26.1 or higher is not installed. Please install it before proceeding."
        return 1
    fi

    # Ensure git, ripgrep, and fd are installed
    pacman -S --noconfirm ripgrep fd || { echo "Failed to install dependencies"; exit 1; }

    # Clone Doom Emacs repository
    if [ ! -d "$USER_HOME/.emacs.d" ]; then
        echo "Cloning Doom Emacs repository..."
        su - "$ACTUAL_USER" -c "git clone --depth 1 https://github.com/doomemacs/doomemacs '$USER_HOME/.emacs.d'" || { echo "Failed to clone Doom Emacs"; exit 1; }
    else
        echo "Doom Emacs is already cloned in $USER_HOME/.emacs.d"
    fi

    # Create Doom configuration if it doesn't exist
    if [ ! -d "$USER_HOME/.doom.d" ]; then
        echo "Creating Doom configuration directory..."
        su - "$ACTUAL_USER" -c "mkdir -p $USER_HOME/.doom.d"
    fi

    # Let Doom install its own configuration
    su - "$ACTUAL_USER" -c "$USER_HOME/.emacs.d/bin/doom install --force" || { echo "Doom Emacs installation failed"; exit 1; }

    # Fix ownership of .emacs.d and .doom.d directories
    echo "Fixing ownership of .emacs.d and .doom.d directories..."
    chown -R "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME/.emacs.d" "$USER_HOME/.doom.d" || echo "Failed to change ownership of $USER_HOME/.emacs.d or $USER_HOME/.doom.d"

    # Sync Doom Emacs packages
    echo "Syncing Doom Emacs packages..."
    su - "$ACTUAL_USER" -c "$USER_HOME/.emacs.d/bin/doom sync" || { echo "Doom Emacs package sync failed"; exit 1; }

    echo "Doom Emacs installed successfully."
}

# Function to install Nerd Fonts
install_nerd_fonts() {
    echo "Installing Nerd Fonts..."

    # Install nerd-fonts via pacman
    pacman -S --noconfirm nerd-fonts-complete || { echo "Failed to install Nerd Fonts"; exit 1; }

    echo "Nerd Fonts installed successfully."
}

# --- Main Script Execution ---

echo "----- Starting Setup Script -----"

# Execute the internet check
check_internet_connection

# Install essential packages
install_dependencies

# Copy configuration files
copy_config_files

# Install Go via pacman
install_golang_via_pacman

# Install Python tools
install_python_tools

# Install CheckMake via Go
install_checkmake

# Install tmux via pacman
install_tmux_via_pacman

# Install Tmux Plugin Manager and tmux plugins
install_tpm

# Install Vim via pacman
install_vim_via_pacman

# Install Node.js via pacman
install_nodejs_via_pacman

# Install FZF via pacman
install_fzf_via_pacman

# Install Vim plugins
install_vim_plugins_all

# Configure Git
configure_git

# Install coc.nvim dependencies
install_coc_dependencies

# Install Doxygen via pacman
install_doxygen_via_pacman

# Install additional language servers
install_language_servers

# Install GTKWAVE via pacman
install_gtkwave_via_pacman

# Install GHDL via pacman
install_ghdl_via_pacman

# Verify GHDL installation
verify_ghdl() {
    echo "Verifying GHDL installation..."
    if command -v ghdl &>/dev/null; then
        ghdl --version || { echo "GHDL verification failed"; exit 1; }
        echo "GHDL verified successfully."
    else
        echo "GHDL command not found after installation."
        exit 1
    fi
}
verify_ghdl

# Install and configure Zsh and Oh My Zsh
kill_tmux_sessions
setup_zsh
clone_zsh_plugins

# Install Neovim via pacman
install_neovim_via_pacman

# Install LazyVim
install_lazyvim

# Install Emacs via pacman
install_emacs_via_pacman

# Install Doom Emacs
install_doom_emacs

# Install Nerd Fonts
install_nerd_fonts

# Ensure home directory ownership is correct
ensure_home_ownership

# Clean up package manager cache
echo "Cleaning up package manager cache..."
pacman -Scc --noconfirm

echo "----- Setup Completed Successfully! -----"

# Remove the trap to prevent cleanup from running again
trap - ERR EXIT

echo "----- Setup Script Finished -----"

# --- End of Script ---
