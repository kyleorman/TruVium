#!/bin/bash

# Exit immediately if a command exits with a non-zero status,
# if any undefined variable is used, and if any command in a pipeline fails
set -euo pipefail
IFS=$'\n\t'

# --- Configuration Variables ---
SCRIPT_DIR="/vagrant"  # Directory where the script is being executed
LOGFILE="/var/log/setup-script.log"
TMUX_VERSION="3.5"
TMP_DIR="/tmp/setup_script_install"
INSTALL_PREFIX="/usr/local"
NODE_VERSION="${NODE_VERSION:-22.x}"  # Default Node.js version
VIM_VERSION="${VIM_VERSION:-}"        # Optional: Specify Vim version, defaults to latest

# Determine the actual user (non-root)
if [ "${SUDO_USER:-}" ]; then
    ACTUAL_USER="$SUDO_USER"
    USER_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
else
    echo "This script must be run with sudo."
    exit 1
fi

# Redirect all output to LOGFILE
exec > >(tee -a "$LOGFILE") 2>&1

# --- Trap for Cleanup ---
cleanup() {
    echo "Cleaning up temporary directories..."
    rm -rf "$TMP_DIR" /tmp/gtkwave /tmp/ghdl
}
trap cleanup EXIT

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

# Function to remove existing Vim installations (Optional)
remove_system_vim() {
    echo "Removing any existing Vim installations to prevent conflicts..."
    apt-get remove -y vim vim-runtime gvim vim-tiny vim-common || { echo "Failed to remove existing Vim installations"; exit 1; }
    echo "Existing Vim installations removed successfully."
}

# Function to remove outdated tmux if present
remove_outdated_tmux() {
    echo "Checking for existing tmux installation..."
    if command -v tmux &> /dev/null; then
        CURRENT_VERSION=$(tmux -V | awk '{print $2}')
        if [ "$CURRENT_VERSION" != "$TMUX_VERSION" ]; then
            echo "Outdated tmux version $CURRENT_VERSION found. Removing it..."
            apt-get remove -y --purge tmux || { echo "Failed to remove tmux"; exit 1; }
        else
            echo "tmux $TMUX_VERSION is already installed."
            return 0
        fi
    else
        echo "tmux is not installed."
    fi
}

# Function to install tmux from Git
install_tmux_from_git() {
    echo "Starting installation of tmux version $TMUX_VERSION from Git..."

    # Check if tmux is already installed and at the desired version
    if command -v tmux &>/dev/null; then
        INSTALLED_VERSION=$(tmux -V | awk '{print $2}')
        if [[ "$INSTALLED_VERSION" == "$TMUX_VERSION" ]]; then
            echo "tmux version $TMUX_VERSION is already installed. Skipping installation."
            return 0
        else
            echo "tmux version $INSTALLED_VERSION is installed. Proceeding to install version $TMUX_VERSION."
        fi
    else
        echo "tmux is not installed. Proceeding with installation."
    fi

    # Ensure the correct temporary directory exists and navigate there
    mkdir -p "$TMP_DIR"
    cd "$TMP_DIR" || { echo "Failed to access temporary directory $TMP_DIR"; exit 1; }

    echo "Updating package lists and installing dependencies..."
    apt-get update -y
    apt-get install -y --no-install-recommends \
        autoconf \
        automake \
        pkg-config \
        libevent-dev \
        ncurses-dev \
        build-essential \
        git \
        bison \
        ninja-build || { echo "Failed to install dependencies"; exit 1; }

    # Clone the tmux repository if not already cloned
    if [[ ! -d "tmux" ]]; then
        echo "Cloning tmux repository from GitHub..."
        git clone https://github.com/tmux/tmux.git
    fi

    cd tmux || { echo "Failed to navigate to tmux directory"; exit 1; }

    echo "Fetching latest changes..."
    git fetch --all

    echo "Checking out tmux version $TMUX_VERSION..."
    git checkout "tags/$TMUX_VERSION" || { echo "Failed to checkout version $TMUX_VERSION"; exit 1; }

    # Autogen, configure, make, and install steps
    if [ ! -f "configure" ]; then
        echo "Running autogen to generate configure script..."
        sh autogen.sh || { echo "Failed to run autogen.sh"; exit 1; }
    fi

    echo "Configuring tmux build with prefix $INSTALL_PREFIX..."
    ./configure --prefix="$INSTALL_PREFIX" || { echo "Configuration failed"; exit 1; }

    echo "Building tmux using $(nproc) parallel jobs..."
    make -j"$(nproc)" || { echo "Build failed"; exit 1; }

    echo "Installing tmux..."
    make install || { echo "Installation failed"; exit 1; }

    # Ensure /usr/local/bin is in PATH
    if [[ ":$PATH:" != *":/usr/local/bin:"* ]]; then
        export PATH="/usr/local/bin:$PATH"
        echo "Updated PATH to include /usr/local/bin."
    fi

    # Verify installation using full path
    if /usr/local/bin/tmux -V | grep -q "$TMUX_VERSION"; then
        echo "tmux $TMUX_VERSION successfully installed from Git."
    else
        echo "tmux installation from Git failed."
        exit 1
    fi

    # Fix permissions (if necessary)
    echo "Fixing ownership of user home directory and /tmp..."
    chown -R "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME" || echo "Failed to change ownership of $USER_HOME"
    chown -R "$ACTUAL_USER:$ACTUAL_USER" /tmp || echo "Failed to change ownership of /tmp"

    echo "tmux installation process completed successfully."
}

# Function to install Vim from Source with Dynamic Version Detection
install_vim_from_source() {
    echo "Installing Vim from source with extensive feature support..."

    # Define variables
    VIM_SRC_DIR="$TMP_DIR/vim"
    VIM_INSTALL_PREFIX="$INSTALL_PREFIX"

    # Install additional dependencies for Vim
    echo "Installing additional dependencies for Vim..."
    apt-get install -y --no-install-recommends \
        liblua5.3-dev \
        libperl-dev \
        libpython3-dev \
        libncurses5-dev \
        libtinfo-dev \
        libx11-dev \
        libgtk-3-dev \
        libatk1.0-dev \
        libcairo2-dev \
        libxpm-dev \
        libxt-dev || { echo "Failed to install Vim build dependencies"; exit 1; }

    # Create temporary directory for Vim source
    mkdir -p "$VIM_SRC_DIR"
    cd "$VIM_SRC_DIR" || { echo "Failed to access Vim source directory"; exit 1; }

    # Clone Vim repository if not already cloned
    if [ ! -d "vim" ]; then
        echo "Cloning Vim repository..."
        git clone https://github.com/vim/vim.git || { echo "Failed to clone Vim repository"; exit 1; }
    fi

    cd vim || { echo "Failed to navigate to Vim directory"; exit 1; }

    # Fetch all tags from the repository
    echo "Fetching all Vim tags..."
    git fetch --all --tags --prune || { echo "Failed to fetch Vim tags"; exit 1; }

    # Determine the Vim version to install
    if [ -z "$VIM_VERSION" ]; then
        # Determine the latest stable Vim version tag
        echo "Determining the latest stable Vim tag..."
        VIM_VERSION_TAG=$(git tag -l "v*" --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)*$' | head -n1)
        if [ -z "$VIM_VERSION_TAG" ]; then
            echo "Error: Unable to determine the latest stable Vim version tag."
            exit 1
        fi
        VIM_VERSION="${VIM_VERSION_TAG#v}"  # Remove the 'v' prefix
    else
        # Use the specified VIM_VERSION
        VIM_VERSION_TAG="v$VIM_VERSION"
        echo "Using specified Vim version tag: $VIM_VERSION_TAG"
    fi

    echo "Selected Vim version tag: $VIM_VERSION_TAG"
    echo "Expected Vim version string: $VIM_VERSION"

    # Check if the desired version is already checked out
    CURRENT_CHECKOUT=$(git describe --tags --exact-match 2>/dev/null || echo "")
    if [ "$CURRENT_CHECKOUT" = "$VIM_VERSION_TAG" ]; then
        echo "Vim is already checked out at version $VIM_VERSION_TAG."
    else
        # Checkout the desired Vim version
        echo "Checking out Vim version $VIM_VERSION_TAG..."
        git checkout "tags/$VIM_VERSION_TAG" || { echo "Failed to checkout Vim version $VIM_VERSION_TAG"; exit 1; }
    fi

    # Autogen, configure, make, and install steps
    if [ ! -f "configure" ]; then
        echo "Running autogen to generate configure script..."
        sh autogen.sh || { echo "Failed to run autogen.sh"; exit 1; }
    else
        echo "Configure script already exists."
    fi

    echo "Configuring Vim build with prefix $VIM_INSTALL_PREFIX and features=huge..."
    ./configure --prefix="$VIM_INSTALL_PREFIX" \
                --with-features=huge \
                --enable-multibyte \
                --enable-rubyinterp=yes \
                --enable-python3interp=yes \
                --with-python3-config-dir=$(python3-config --configdir) \
                --enable-perlinterp=yes \
                --enable-luainterp=yes \
                --enable-gui=gtk3 \
                --enable-cscope || { echo "Vim configuration failed"; exit 1; }

    echo "Building Vim using $(nproc) parallel jobs..."
    make -j"$(nproc)" || { echo "Vim build failed"; exit 1; }

    echo "Installing Vim..."
    make install || { echo "Vim installation failed"; exit 1; }

    # Ensure /usr/local/bin is in PATH
    if [[ ":$PATH:" != *":/usr/local/bin:"* ]]; then
        export PATH="/usr/local/bin:$PATH"
        echo "Updated PATH to include /usr/local/bin."
    fi

    # Verify installation using full path
    echo "Verifying Vim installation..."
    INSTALLED_VIM_VERSION=$(/usr/local/bin/vim --version | head -n1 | awk '{print $5}')
    echo "Installed Vim version: $INSTALLED_VIM_VERSION"
    if [ "$INSTALLED_VIM_VERSION" = "$VIM_VERSION" ]; then
        echo "Vim $VIM_VERSION successfully installed from source."
    else
        echo "Vim installation verification failed."
        echo "Expected version: $VIM_VERSION, but found version: $INSTalled_VIM_VERSION"
        exit 1
    fi

    # Fix permissions (if necessary)
    echo "Fixing ownership of user home directory and /tmp..."
    chown -R "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME" || echo "Failed to change ownership of $USER_HOME"
    chown -R "$ACTUAL_USER:$ACTUAL_USER" /tmp || echo "Failed to change ownership of /tmp"

    echo "Vim installation process completed successfully."

    # Optionally, remove Vim source directory to save space
    # Uncomment the following lines if you wish to remove the source
    # echo "Cleaning up Vim source files..."
    # rm -rf "$VIM_SRC_DIR"
}

# Function to kill any running tmux sessions
kill_tmux_sessions() {
    echo "Killing any running tmux sessions before Oh My Zsh installation..."
    if tmux ls &> /dev/null; then
        sudo -u "$ACTUAL_USER" tmux kill-server
        echo "tmux server stopped."
    else
        echo "No tmux sessions were running."
    fi
}

# Function to set up Zsh and Oh My Zsh
setup_zsh() {
    echo "Changing shell to zsh for $ACTUAL_USER..."

    # Change default shell to zsh for the actual user
    if chsh -s /bin/zsh "$ACTUAL_USER"; then
        echo "Shell successfully changed to zsh for $ACTUAL_USER."
    else
        echo "Failed to change shell for $ACTUAL_USER."
        return 1
    fi

    echo "Installing Oh My Zsh for $ACTUAL_USER..."

    # Download Oh My Zsh install script
    OH_MY_ZSH_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
    OH_MY_ZSH_SCRIPT="/tmp/install_oh_my_zsh.sh"
    curl -fsSL "$OH_MY_ZSH_URL" -o "$OH_MY_ZSH_SCRIPT" || { echo "Failed to download Oh My Zsh installer"; exit 1; }

    # Install Oh My Zsh using the official unattended method
    sudo -u "$ACTUAL_USER" bash "$OH_MY_ZSH_SCRIPT" --unattended || { echo "Oh My Zsh installation failed"; return 1; }

    # Backup existing .zshrc if it exists
    if [ -f "$USER_HOME/.zshrc" ]; then
        cp "$USER_HOME/.zshrc" "$USER_HOME/.zshrc.bak"
        echo "Existing .zshrc backed up to $USER_HOME/.zshrc.bak"
    fi

    # Append new configuration to .zshrc with interactive shell check
    echo "Setting up .zshrc for $ACTUAL_USER..."
    {
        echo 'export TERM="xterm-256color"'
        echo 'export PATH="$HOME/.local/bin:$PATH"'
        echo 'export PATH="/usr/bin:$PATH"'
        echo 'export PATH="$HOME/go/bin:$PATH"'
        echo 'export PATH="/usr/local/bin:$PATH"'
        echo 'export PATH="$HOME/go/bin:$PATH"'
        echo ''
        echo 'if [[ $- == *i* ]]; then'  # Check if shell is interactive
        echo '  if command -v tmux &> /dev/null && [ -z "$TMUX" ]; then'
        echo '    tmux attach-session -t default || tmux new-session -s default'
        echo '  fi'
        echo 'fi'
    } >> "$USER_HOME/.zshrc"

    # Set ownership and permissions for .zshrc
    chown "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME/.zshrc"
    chmod 644 "$USER_HOME/.zshrc"

    sudo -u "$ACTUAL_USER" /usr/local/bin/tmux set-environment -g ZDOTDIR "$USER_HOME/.zsh"

    echo ".zshrc setup complete for $ACTUAL_USER."
}

# Function to ensure TPM (Tmux Plugin Manager) is installed
ensure_tpm_installed() {
    echo "Verifying Tmux Plugin Manager (TPM) installation..."
    TPM_DIR="$USER_HOME/.tmux/plugins/tpm"
    if [ ! -d "$TPM_DIR" ]; then
        echo "Cloning Tmux Plugin Manager (TPM)..."
        sudo -u "$ACTUAL_USER" git clone https://github.com/tmux-plugins/tpm "$TPM_DIR" || {
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

    # Ensure TPM is installed
    ensure_tpm_installed

    # Initialize TPM in .tmux.conf if not already present
    if ! grep -q "run '~/.tmux/plugins/tpm/tpm'" "$USER_HOME/.tmux.conf"; then
        echo "Initializing TPM in .tmux.conf..."
        echo "run '~/.tmux/plugins/tpm/tpm'" >> "$USER_HOME/.tmux.conf"
    else
        echo "TPM initialization already present in .tmux.conf."
    fi

    # Reload tmux environment and install plugins using the absolute path to tmux
    sudo -u "$ACTUAL_USER" /usr/local/bin/tmux new-session -d -s tpm_install "/usr/local/bin/tmux source ~/.tmux.conf && ~/.tmux/plugins/tpm/bin/install_plugins"
    echo "TPM plugin installation triggered."
}

# Function to check if TPM plugins are installed
check_tpm_installation() {
    echo "Checking if TPM plugins are installed..."

    # List installed plugins using the absolute path to tmux
    TMUX_PLUGINS_INSTALLED=$(sudo -u "$ACTUAL_USER" /usr/local/bin/tmux list-plugins 2>/dev/null || echo "")

    if [ -n "$TMUX_PLUGINS_INSTALLED" ]; then
        echo "Tmux plugins are installed successfully."
    else
        echo "Tmux plugins installation may have failed."
        echo "Please open a new tmux session and press <prefix> + I (e.g., Ctrl-b + I) to install the plugins manually."
    fi
}

# Function to clone a Git repository if it doesn't already exist
clone_plugin() {
    local repo="$1"
    local target_dir="$2"

    if [ -d "$target_dir" ]; then
        echo "Plugin '$repo' already exists at '$target_dir'. Skipping clone."
    else
        echo "Cloning '$repo' into '$target_dir'..."
        git clone --depth=1 "https://github.com/$repo.git" "$target_dir" || {
            echo "Error: Failed to clone '$repo'."
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

# Function to clone and install Vim plugins
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
    )

    OPTIONAL_PLUGINS=(
        "klen/python-mode"
        "suoto/hdl_checker"
        # Add more optional plugins here as needed
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
    mkdir -p "$START_PLUGIN_DIR"
    mkdir -p "$OPT_PLUGIN_DIR"
    mkdir -p "$COLOR_PLUGIN_DIR"

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
    for plugin in "${START_PLUGINS[@]}" "${OPTIONAL_PLUGINS[@]}" "${COLOR_SCHEMES[@]}"; do
        plugin_name=$(basename "$plugin")
        target_path="$START_PLUGIN_DIR/$plugin_name"

        # Adjust for optional plugins
        if [[ " ${OPTIONAL_PLUGINS[@]} " =~ " $plugin " ]]; then
            target_path="$OPT_PLUGIN_DIR/$plugin_name"
        fi

        # Adjust for color schemes
        if [[ " ${COLOR_SCHEMES[@]} " =~ " $plugin " ]]; then
            target_path="$COLOR_PLUGIN_DIR/$plugin_name"
        fi

        generate_helptags "$target_path"
    done

    echo "Vim plugins installed and helptags generated successfully."
}

# Function to clone Zsh plugins
clone_zsh_plugins() {
    echo "Cloning Zsh plugins..."
    ZSH_CUSTOM="${ZSH_CUSTOM:-$USER_HOME/.oh-my-zsh/custom}"

    sudo -u "$ACTUAL_USER" git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" || true
    sudo -u "$ACTUAL_USER" git clone https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_CUSTOM/plugins/zsh-autosuggestions" || true

    # Update .zshrc plugins line
    DESIRED_PLUGINS='plugins=(git zsh-syntax-highlighting zsh-autosuggestions)'
    if grep -q "^plugins=" "$USER_HOME/.zshrc"; then
        sed -i "s/^plugins=.*/$DESIRED_PLUGINS/" "$USER_HOME/.zshrc"
    else
        sed -i "/^source.*oh-my-zsh.sh/a $DESIRED_PLUGINS" "$USER_HOME/.zshrc"
    fi

    echo "Plugins configured in .zshrc."

    # Ensure correct ownership and permissions
    chown "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME/.zshrc"
    chmod 644 "$USER_HOME/.zshrc"
}

# Function to install Python tools
install_python_tools() {
    echo "Installing Python tools..."
    pip3 install --upgrade pip
    pip3 install flake8 pylint black mypy autopep8 jedi doq hdl-checker vsg tox ipython jupyter jupyter-console meson || { echo "Failed to install Python tools"; exit 1; }
}

# Function to install CheckMake via Go
install_checkmake() {
    echo "Installing CheckMake via Go..."
    sudo -u "$ACTUAL_USER" go install github.com/mrtazz/checkmake/cmd/checkmake@latest || { echo "CheckMake installation failed"; exit 1; }
    echo 'export PATH="$HOME/go/bin:$PATH"' >> "$USER_HOME/.zshrc"
}

# Function to install dependencies for coc.nvim
install_coc_dependencies() {
    echo "Installing dependencies for coc.nvim..."

    COC_DIR="$START_PLUGIN_DIR/coc.nvim"

    if [ -d "$COC_DIR" ]; then
        echo "Changing ownership of coc.nvim directory to $ACTUAL_USER..."
        chown -R "$ACTUAL_USER:$ACTUAL_USER" "$COC_DIR"

        echo "Running 'npm ci' in coc.nvim directory..."
        sudo -u "$ACTUAL_USER" bash -c "cd '$COC_DIR' && npm ci" || {
            echo "Error: Failed to install dependencies for coc.nvim."
            exit 1
        }
        echo "Dependencies for coc.nvim installed successfully."
    else
        echo "Error: coc.nvim directory not found at '$COC_DIR'."
        exit 1
    fi
}

# Function to install FZF
install_fzf() {
    echo "Installing FZF..."
    if [ ! -d "$USER_HOME/.fzf" ]; then
        sudo -u "$ACTUAL_USER" git clone --depth 1 https://github.com/junegunn/fzf.git "$USER_HOME/.fzf" || { echo "FZF clone failed"; exit 1; }

        # Ensure .zshrc is owned by the actual user and writable
        chown "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME/.zshrc"
        chmod 644 "$USER_HOME/.zshrc"

        sudo -u "$ACTUAL_USER" bash -c "cd '$USER_HOME/.fzf' && ./install --all" || { echo "FZF installation failed"; exit 1; }
        echo "FZF installed successfully."
    else
        echo "FZF is already installed."
    fi
}

# Function to create symbolic links for ftdetect
setup_ftdetect_symlinks() {
    FTDETECT_SRC_DIR="$START_PLUGIN_DIR/ultisnips/ftdetect"
    FTDETECT_DEST_DIR="$USER_HOME/.vim/ftdetect"

    echo "Setting up ftdetect symbolic links..."

    # Ensure the destination directory exists
    mkdir -p "$FTDETECT_DEST_DIR"

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

# Function to configure Git
configure_git() {
    GIT_SETUP_SCRIPT="$SCRIPT_DIR/git_setup.sh"
    GIT_SETUP_CONF="$SCRIPT_DIR/git_setup.conf"

    echo "Configuring Git..."

    if [ -f "$GIT_SETUP_SCRIPT" ] && [ -f "$GIT_SETUP_CONF" ]; then
        if sudo -u "$ACTUAL_USER" bash "$GIT_SETUP_SCRIPT" --config-file "$GIT_SETUP_CONF" --non-interactive; then
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

# Function to install GTKWAVE
install_gtkwave() {
    echo "Cloning GTKWAVE repository..."
    sudo -u "$ACTUAL_USER" git clone https://github.com/gtkwave/gtkwave.git /tmp/gtkwave || { echo "GTKWAVE clone failed"; exit 1; }

    cd /tmp/gtkwave || exit
    echo "Building GTKWAVE..."
    meson setup build && meson compile -C build || { echo "GTKWAVE build failed"; exit 1; }
    sudo meson install -C build || { echo "GTKWAVE installation failed"; exit 1; }
    cd ~
}

# Function to install GHDL
install_ghdl() {
    echo "Cloning GHDL repository..."
    sudo -u "$ACTUAL_USER" git clone https://github.com/ghdl/ghdl.git /tmp/ghdl || { echo "GHDL clone failed"; exit 1; }

    cd /tmp/ghdl || exit
    echo "Building and installing GHDL..."
    ./configure --prefix=/usr/local && make && sudo make install || { echo "GHDL build or installation failed"; exit 1; }
    cd ~
}

# Function to verify GHDL installation
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

# Function to copy configuration files
copy_config_files() {
    echo "Copying configuration files to user home directory..."

    # Declare an associative array of source and destination files
    declare -A CONFIG_FILES=(
        ["vimrc"]=".vimrc"
        ["tmux.conf"]=".tmux.conf"
        ["tmux_keys.sh"]=".tmux_keys.sh"
        ["coc-settings.json"]=".vim/coc-settings.json"
    )

    for src in "${!CONFIG_FILES[@]}"; do
        dest="${CONFIG_FILES[$src]}"
        src_path="$SCRIPT_DIR/$src"
        dest_path="$USER_HOME/$dest"

        # Ensure the destination directory exists
        dest_dir=$(dirname "$dest_path")
        mkdir -p "$dest_dir"

        if [ -f "$src_path" ]; then
            cp "$src_path" "$dest_path"
            chown "$ACTUAL_USER:$ACTUAL_USER" "$dest_path"
            chmod 644 "$dest_path"
            echo "$src copied successfully to $dest_path."
        else
            echo "Warning: $src not found in $SCRIPT_DIR. Skipping copy."
        fi
    done

    # Copy 'yank' to /usr/local/bin instead of /bin for better practices
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

# Function to install Vim plugins
install_vim_plugins_all() {
    install_vim_plugins
    setup_ftdetect_symlinks
}

# Function to install and configure TPM and tmux plugins
install_tpm() {
    ensure_tpm_installed
    automate_tpm_install
    check_tpm_installation
}

# Function to install all dependencies and tools
install_dependencies() {
    echo "Installing essential packages..."
    apt-get update -y
    apt-get install -y --no-install-recommends \
        autoconf \
        automake \
        pkg-config \
        libevent-dev \
        ncurses-dev \
        build-essential \
        git \
        bison \
        ninja-build \
        software-properties-common \
        curl \
        wget \
        golang \
        python3 \
        python3-pip \
        python3-venv \
        pipenv \
        cmake \
        zsh \
        make \
        gcc \
        perl \
        gnat \
        zlib1g-dev \
        gperf \
        flex \
        desktop-file-utils \
        libgtk-3-dev \
        libgtk-4-dev \
        libjudy-dev \
        libbz2-dev \
        libgirepository1.0-dev \
        exuberant-ctags \
        htop \
        vagrant \
        virtualbox-guest-utils \
        shellcheck \
        pandoc \
        fonts-powerline \
        grep \
        sed \
        bc \
        xclip \
        acpi \
        passwd \
        xauth \
        xorg \
        openbox \
        xdg-utils \
        tmux \
        virtualbox-guest-utils \
        virtualbox-guest-x11 || { echo "Package installation failed"; exit 1; }
}

# --- Main Script Execution ---

echo "----- Starting Setup Script -----"

# Execute the internet check
check_internet_connection

# Install essential packages
install_dependencies

# Install Python tools
install_python_tools

# Install CheckMake via Go
install_checkmake

# Remove existing Vim installations (Optional)
remove_system_vim

# Install tmux before setting up Zsh
remove_outdated_tmux
install_tmux_from_git

# Install Vim from source with dynamic version detection
install_vim_from_source

# Install Node.js if not installed
if ! command -v node &>/dev/null; then
    echo "Installing Node.js $NODE_VERSION..."
    curl -fsSL https://deb.nodesource.com/setup_"$NODE_VERSION" | bash - || { echo "Node.js setup script failed"; exit 1; }
    apt-get install -y nodejs || { echo "Node.js installation failed"; exit 1; }
else
    echo "Node.js is already installed."
fi

# Update npm to the latest version
npm install -g npm

# Install and configure Zsh and Oh My Zsh
kill_tmux_sessions
setup_zsh
clone_zsh_plugins

# Copy configuration files
copy_config_files

# Install FZF after ensuring Zsh is set up
install_fzf

# Install Vim plugins
install_vim_plugins_all

# Configure Git
configure_git

# Install coc.nvim dependencies
install_coc_dependencies

# Install GTKWAVE
install_gtkwave

# Install GHDL
install_ghdl

# Verify GHDL installation
verify_ghdl

echo "tmux setup complete."

# Install Tmux Plugin Manager and tmux plugins
echo "Installing Tmux Plugin Manager (TPM) and tmux plugins..."
install_tpm

echo "Tmux Plugin Manager and plugins installed successfully."

# Clean up package manager cache
echo "Cleaning up..."
apt-get autoremove -y && apt-get clean

echo "Setup completed successfully!"

# --- End of Script ---