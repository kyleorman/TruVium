#!/bin/bash

# Exit immediately if a command exits with a non-zero status,
# if any undefined variable is used, and if any command in a pipeline fails
set -eEuo pipefail
IFS=$'\n\t'

# --- Configuration Variables ---
SCRIPT_DIR="/vagrant"  # Directory where the script is being executed
LOGFILE="/var/log/setup-script.log"
TMUX_VERSION="3.5"
TMP_DIR="/tmp/setup_script_install"
INSTALL_PREFIX="/usr/local"
NODE_VERSION="${NODE_VERSION:-22.x}"  # Default Node.js version
VIM_VERSION="${VIM_VERSION:-9.1.0744}" # Optional: Specify Vim version, defaults to latest

# Determine the actual user (non-root)
if [ "${SUDO_USER:-}" ]; then
    ACTUAL_USER="$SUDO_USER"
    USER_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
else
    echo "This script must be run with sudo."
    exit 1
fi

# Export environment variable to indicate the setup script is running
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
    
    # Remove GTKWAVE and GHDL build directories
    for dir in /tmp/gtkwave /tmp/ghdl; do
        if [ -d "$dir" ]; then
            echo "Removing directory: $dir"
            rm -rf "$dir" || echo "Failed to remove $dir"
        else
            echo "Directory $dir does not exist. Skipping."
        fi
    done
    
    # Remove Vim source directory if it exists
    VIM_SRC_DIR="$TMP_DIR/vim"
    if [ -d "$VIM_SRC_DIR" ]; then
        echo "Removing Vim source directory: $VIM_SRC_DIR"
        rm -rf "$VIM_SRC_DIR" || echo "Failed to remove $VIM_SRC_DIR"
    else
        echo "Vim source directory $VIM_SRC_DIR does not exist. Skipping."
    fi
    
    # Remove Oh My Zsh installation script
    OH_MY_ZSH_SCRIPT="/tmp/install_oh_my_zsh.sh"
    if [ -f "$OH_MY_ZSH_SCRIPT" ]; then
        echo "Removing Oh My Zsh install script: $OH_MY_ZSH_SCRIPT"
        rm -f "$OH_MY_ZSH_SCRIPT" || echo "Failed to remove $OH_MY_ZSH_SCRIPT"
    else
        echo "Oh My Zsh install script $OH_MY_ZSH_SCRIPT does not exist. Skipping."
    fi
    
    # Remove Go tarball
    if [ -f "/tmp/go.tar.gz" ]; then
    	echo "Removing Go tarball..."
	rm /tmp/go.tar.gz || echo "Failed to remove Go tarball"
    fi
	    
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
		wget \
		gzip \
		tcl \
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

    # Terminfo Update Process
    echo "Starting terminfo update process..."

    # Define temporary paths
    TERMINFO_TMP_DIR="/tmp/terminfo_update"
    TERMINFO_SRC_GZ="$TERMINFO_TMP_DIR/terminfo.src.gz"
    TERMINFO_SRC="$TERMINFO_TMP_DIR/terminfo.src"

    # Create a temporary directory for terminfo operations
    mkdir -p "$TERMINFO_TMP_DIR"
    
    echo "Downloading the latest terminfo source file from the official ncurses repository..."
    wget -O "$TERMINFO_SRC_GZ" http://invisible-island.net/datafiles/current/terminfo.src.gz || { echo "Failed to download terminfo.src.gz"; exit 1; }
	
	#echo "Verifying the integrity of the downloaded terminfo.src.gz..."
	#echo "expected_checksum  $TERMINFO_SRC_GZ" | sha256sum -c - || { echo "Checksum verification failed"; exit 1; }

	echo "Backing up existing terminfo database..."
	mkdir -p "$TERMINFO_TMP_DIR/backup"
	cp -r ~/.terminfo "$TERMINFO_TMP_DIR/backup/" || echo "Failed to back up existing terminfo database"

    echo "Decompressing the terminfo source file..."
    gunzip -f "$TERMINFO_SRC_GZ" || { echo "Failed to decompress terminfo.src.gz"; exit 1; }

    echo "Compiling the terminfo source file..."
    tic "$TERMINFO_SRC" || { echo "Failed to compile terminfo.src"; exit 1; }

    echo "Terminfo update process completed successfully."

    # Optional: Clean up terminfo temporary files
    rm -rf "$TERMINFO_TMP_DIR"
	
    # Fix permissions (if necessary)
    echo "Fixing ownership of user home directory and /tmp..."
    chown -R "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME" || echo "Failed to change ownership of $USER_HOME"
    chown -R "$ACTUAL_USER:$ACTUAL_USER" /tmp || echo "Failed to change ownership of /tmp"

    echo "tmux installation process completed successfully."
}

# Function to start tmux server and create default session
start_tmux_server() {
    echo "Starting tmux server and creating default session..."
    sudo -u "$ACTUAL_USER" tmux start-server
    sudo -u "$ACTUAL_USER" tmux new-session -d -s default || echo "Default tmux session already exists."
    echo "tmux server started with default session."
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
        VIM_VERSION_TAG=$(git tag -l "v*" --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+(\.[0-9]+)*$' | head -n1)
        echo "Latest Vim tag detected: $VIM_VERSION_TAG"
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
        git checkout "$VIM_VERSION_TAG" || { echo "Failed to checkout Vim version $VIM_VERSION_TAG"; exit 1; }
    fi

    # Autogen, configure, make, and install steps
    if [ ! -f "configure" ]; then
        echo "Running autogen to generate configure script..."
        sh autogen.sh || { echo "Failed to run autogen.sh"; exit 1; }
    else
        echo "Configure script already exists."
    fi

    # Verify that python3-config returns a valid directory
    PYTHON_CONFIG_DIR=$(python3-config --configdir)
    if [ -z "$PYTHON_CONFIG_DIR" ]; then
        echo "Error: python3-config did not return a valid config directory."
        exit 1
    fi
    echo "python3-config detected config directory: $PYTHON_CONFIG_DIR"

    echo "Configuring Vim build with prefix $VIM_INSTALL_PREFIX and features=huge..."
    ./configure --prefix="$VIM_INSTALL_PREFIX" \
                --with-features=huge \
                --enable-multibyte \
		--enable-rubyinterp=dynamic \
		--enable-tclinterp=yes \
                --enable-python3interp=dynamic \
                --with-python3-command=python3 \
                --with-python3-config-dir="$PYTHON_CONFIG_DIR" \
                --enable-perlinterp=yes \
                --enable-luainterp=dynamic \
                --with-lua-prefix=/usr \
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
    echo "Expected Vim version: $VIM_VERSION"

    # Extract major and minor versions for comparison
    INSTALLED_VIM_MAIN_VERSION=$(echo "$INSTALLED_VIM_VERSION" | awk -F. '{print $1"."$2}')
    EXPECTED_VIM_MAIN_VERSION=$(echo "$VIM_VERSION" | awk -F. '{print $1"."$2}')

    echo "Installed Vim main version: $INSTALLED_VIM_MAIN_VERSION"
    echo "Expected Vim main version: $EXPECTED_VIM_MAIN_VERSION"

    if [ "$INSTALLED_VIM_MAIN_VERSION" = "$EXPECTED_VIM_MAIN_VERSION" ]; then
        echo "Vim $VIM_VERSION successfully installed from source."
    else
        echo "Vim installation verification failed."
        echo "Expected main version: $EXPECTED_VIM_MAIN_VERSION, but found main version: $INSTALLED_VIM_MAIN_VERSION"
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

# Function to restart tmux server
restart_tmux_server() {
    echo "Restarting tmux server to apply shell changes..."
    sudo -u "$ACTUAL_USER" tmux kill-server || true
    sudo -u "$ACTUAL_USER" tmux start-server
    sudo -u "$ACTUAL_USER" tmux new-session -d -s default
    echo "tmux server restarted with default session."
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
        echo 'export PATH="$HOME/.local/bin:$PATH"'
        echo 'export PATH="/usr/bin:$PATH"'
        echo 'export PATH="$HOME/go/bin:$PATH"'
        echo 'export PATH="/usr/local/bin:$PATH"'
        echo 'export PATH="/usr/local/go/bin:$PATH"'
        echo ''
        echo 'if [[ $- == *i* ]]; then'  # Check if shell is interactive
        echo '  if [ -z "$SETUP_SCRIPT_RUNNING" ]; then'  # Check if setup script is not running
        echo '    if command -v tmux &> /dev/null && [ -z "$TMUX" ]; then'
        echo '      if tmux ls &> /dev/null; then'
        echo '        tmux attach-session -t default'
        echo '      else'
        echo '        tmux new-session -s default'
        echo '      fi'
        echo '    fi'
        echo '  fi'
        echo 'fi'
    } >> "$USER_HOME/.zshrc"

    # Set ownership and permissions for .zshrc
    chown "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME/.zshrc"
    chmod 644 "$USER_HOME/.zshrc"

    sudo -u "$ACTUAL_USER" /usr/local/bin/tmux set-environment -g ZDOTDIR "$USER_HOME/.zsh"

    echo ".zshrc setup complete for $ACTUAL_USER."

    # Unset the environment variable after setup
    unset SETUP_SCRIPT_RUNNING
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
		"lervag/vimtex"
		"pangloss/vim-javascript"
		"elzr/vim-json"
		"stephpy/vim-yaml"
		"vim-python/python-syntax"
    )

    OPTIONAL_PLUGINS=(
        "klen/python-mode"
        "suoto/hdl_checker"
		"vim-perl/vim-perl"
		"octol/vim-cpp-enhanced-highlight"
		"nsf/gocode"
		"daeyun/vim-matlab"
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
        sed -i "/^source .*oh-my-zsh.sh/a $DESIRED_PLUGINS" "$USER_HOME/.zshrc"
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
    pip3 install flake8 pylint black mypy autopep8 jedi doq hdl-checker vsg tox ipython jupyter jupyter-console meson pexpect || { echo "Failed to install Python tools"; exit 1; }
}

# Function to install CheckMake via Go
install_checkmake() {
    echo "Installing CheckMake via Go..."
    go install github.com/mrtazz/checkmake/cmd/checkmake@latest || { echo "CheckMake installation failed"; exit 1; }
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

        echo "Installing global npm packages for language servers..."

        # Install bash-language-server
        echo "Installing bash-language-server..."
        npm install -g bash-language-server || {
            echo "Error: Failed to install bash-language-server."
            exit 1
        }

        # Install svlangserver
        echo "Installing svlangserver..."
        npm install -g @imc-trading/svlangserver || {
            echo "Error: Failed to install svlangserver."
            exit 1
        }

        # Install yaml-language-server
        echo "Installing yaml-language-server..."
        npm install -g yaml-language-server || {
            echo "Error: Failed to install yaml-language-server."
            exit 1
        }

        # Install vscode-langservers-extracted (for HTML, CSS, JSON language servers)
        echo "Installing vscode-langservers-extracted..."
        npm install -g vscode-langservers-extracted || {
            echo "Error: Failed to install vscode-langservers-extracted."
            exit 1
        }

        # Install typescript-language-server and typescript
        echo "Installing typescript-language-server and typescript..."
        npm install -g typescript typescript-language-server || {
            echo "Error: Failed to install typescript-language-server and typescript."
            exit 1
        }

        # Install pyright (Python language server)
        echo "Installing pyright..."
        npm install -g pyright || {
            echo "Error: Failed to install pyright."
            exit 1
        }

        echo "Global npm packages for language servers installed successfully."
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
		["hdl_checker.json"]=".vim/hdl_checker.json"
		["airline_theme.conf"]=".vim/airline_theme.conf"
		["color_scheme.conf"]=".vim/color_scheme.conf"
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
        python3 \
        python3-pip \
        python3-venv \
        pipenv \
	lua5.4 \
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
        virtualbox-guest-x11 \
        python3-dev \
        liblua5.4-dev \
        libperl-dev \
        ruby-dev \
	clangd \
	openjdk-11-jre \
	cpanminus \
	openjdk-11-jre-headless \
	openjdk-11-jdk \
	maven \
	tree \
	copyq \
        tcl-dev || { echo "Package installation failed"; exit 1; }
}

# Function to install Node.js
install_nodejs() {
    echo "----- Installing Node.js -----"

    # Change directory to user's home to prevent 'getcwd()' issues
    echo "Changing directory to user's home to avoid 'getcwd()' errors during cleanup..."
    cd "$USER_HOME" || { echo "Error: Failed to change directory to $USER_HOME"; exit 1; }

    # Check if Node.js is already installed
    if ! command -v node &>/dev/null; then
        echo "Node.js is not installed. Proceeding with installation..."

        echo "Installing Node.js version $NODE_VERSION..."
        # Download and execute the NodeSource setup script for the specified Node.js version
        curl -fsSL https://deb.nodesource.com/setup_"$NODE_VERSION" | bash - || { echo "Error: Node.js setup script failed"; exit 1; }

        echo "Installing Node.js package..."
        apt-get install -y nodejs || { echo "Error: Node.js installation failed"; exit 1; }

        echo "Node.js version $(node -v) installed successfully."
    else
        echo "Node.js is already installed. Version: $(node -v)"
    fi

    echo "----- Node.js Installation Completed -----"

    # Update npm to the latest version
    echo "----- Updating npm to the latest version -----"
    npm install -g npm
}

# Function to install Perl Language Server
install_perl_language_server() {
    echo "Installing Perl Language Server..."

    # Install cpanminus if not already installed
    if ! command -v cpanm &>/dev/null; then
        echo "Installing cpanminus..."
        apt-get install -y cpanminus || { echo "Failed to install cpanminus"; exit 1; }
    fi

    # Install Perl::LanguageServer
    echo "Installing Perl::LanguageServer via cpanminus..."
    cpanm Perl::LanguageServer || { echo "Failed to install Perl::LanguageServer"; exit 1; }

    echo "Perl Language Server installed successfully."
}

# Function to install MATLAB Language Server
install_matlab_language_server() {
    echo "Installing MATLAB Language Server..."

    # Ensure Java 11+ is installed
    JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
    JAVA_MAJOR_VERSION=$(echo "$JAVA_VERSION" | awk -F. '{print $1}')
    if [ -z "$JAVA_MAJOR_VERSION" ] || [ "$JAVA_MAJOR_VERSION" -lt 11 ]; then
        echo "Java 11+ is required. Installing OpenJDK 17..."
        apt-get install -y openjdk-17-jdk || { echo "Failed to install OpenJDK 17"; exit 1; }
    fi

    # Ensure MATLAB is installed
    if [ -z "${MATLAB_HOME:-}" ] || [ ! -d "$MATLAB_HOME" ]; then
        echo "MATLAB_HOME is not set or does not point to a valid directory."
        echo "Please install MATLAB R2019a or newer and set the MATLAB_HOME environment variable."
        exit 1
    fi

    # Clone the MATLAB Language Server repository
    sudo -u "$ACTUAL_USER" git clone https://github.com/mathworks/MATLAB-language-server.git "$TMP_DIR/MATLAB-language-server" || { echo "Failed to clone MATLAB Language Server"; exit 1; }

    # Build the language server
    cd "$TMP_DIR/MATLAB-language-server" || { echo "Failed to access MATLAB Language Server directory"; exit 1; }

    # Set MATLAB_HOME during the build
    sudo -u "$ACTUAL_USER" bash -c "export MATLAB_HOME='$MATLAB_HOME'; ./gradlew installDist" || { echo "Failed to build MATLAB Language Server"; exit 1; }

    # Copy the built server to /usr/local/share
    mkdir -p /usr/local/share/matlab-language-server
    cp -r "$TMP_DIR/MATLAB-language-server/build/install/matlab-language-server/." /usr/local/share/matlab-language-server/ || { echo "Failed to copy MATLAB Language Server"; exit 1; }

    echo "MATLAB Language Server installed successfully."
}

install_matlab() {
    echo "Starting MATLAB installation..."

    # Define variables
    MATLAB_INSTALLER="/path/to/matlab_installer.zip"  # Update this path
    INSTALLER_INPUT="/path/to/installer_input.txt"    # Update this path
    MATLAB_INSTALL_DIR="/usr/local/MATLAB/R2023a"     # Update version as needed

    # Check if MATLAB is already installed
    if [ -d "$MATLAB_INSTALL_DIR" ]; then
        echo "MATLAB is already installed at $MATLAB_INSTALL_DIR."
        export MATLAB_HOME="$MATLAB_INSTALL_DIR"
        return 0
    fi

    # Unzip MATLAB installer if it's zipped
    if [ -f "$MATLAB_INSTALLER" ]; then
        echo "Extracting MATLAB installer..."
        unzip -q "$MATLAB_INSTALLER" -d "$TMP_DIR/matlab_installer" || { echo "Failed to extract MATLAB installer"; exit 1; }
    else
        echo "MATLAB installer not found at $MATLAB_INSTALLER."
        exit 1
    fi

    # Run the installer silently
    echo "Running MATLAB silent installation..."
    "$TMP_DIR/matlab_installer/install" -inputFile "$INSTALLER_INPUT" || { echo "MATLAB installation failed"; exit 1; }

    # Set MATLAB_HOME environment variable
    export MATLAB_HOME="$MATLAB_INSTALL_DIR"

    echo "MATLAB installed successfully."
}

# Function to install LaTeX Language Server (TexLab)
install_texlab() {
    echo "Installing LaTeX Language Server (TexLab)..."

    # Check if texlab is already installed
    if ! command -v texlab &>/dev/null; then
        echo "TexLab is not installed. Proceeding with installation..."

        # Create temporary directory for download
        mkdir -p "$TMP_DIR/texlab_install"
        cd "$TMP_DIR/texlab_install" || { echo "Failed to access temporary directory"; exit 1; }

        # Determine system architecture
        ARCH=$(uname -m)
        if [[ "$ARCH" == "x86_64" ]]; then
            TEXLAB_ARCH="x86_64"
        elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
            TEXLAB_ARCH="aarch64"
        else
            echo "Unsupported architecture: $ARCH"
            exit 1
        fi

        # Get the latest release information from GitHub API
        echo "Fetching the latest TexLab release information..."
        RELEASE_DATA=$(curl -s https://api.github.com/repos/latex-lsp/texlab/releases/latest)
        if [ -z "$RELEASE_DATA" ]; then
            echo "Failed to fetch release data from GitHub."
            exit 1
        fi

        # Extract the tag name
        LATEST_RELEASE=$(echo "$RELEASE_DATA" | grep -Po '"tag_name": "\K.*?(?=")')
        if [ -z "$LATEST_RELEASE" ]; then
            echo "Failed to determine the latest release tag."
            exit 1
        fi

        echo "Latest TexLab release: $LATEST_RELEASE"

        # List all available asset URLs for debugging
        echo "Available assets:"
        echo "$RELEASE_DATA" | grep -Po '"browser_download_url": "\K.*?(?=")'

        # Build the expected asset filename
        ASSET_FILENAME="texlab-${TEXLAB_ARCH}-linux.tar.gz"

        # Find the asset download URL matching our architecture
        ASSET_URL=$(echo "$RELEASE_DATA" | grep -Po '"browser_download_url": "\K.*?(?=")' | grep "$ASSET_FILENAME")
        if [ -z "$ASSET_URL" ]; then
            echo "Failed to find a compatible TexLab asset to download."
            exit 1
        fi

        echo "Selected asset URL: $ASSET_URL"

        echo "Downloading TexLab from $ASSET_URL..."
        wget -O "texlab.tar.gz" "$ASSET_URL" || { echo "Failed to download TexLab"; exit 1; }

        # Extract the binary
        echo "Extracting TexLab..."
        tar -xzf "texlab.tar.gz" || { echo "Failed to extract TexLab"; exit 1; }

        # Move the binary to /usr/local/bin
        echo "Installing TexLab to /usr/local/bin..."
        mv "texlab" /usr/local/bin/ || { echo "Failed to move TexLab binary"; exit 1; }
        chmod +x /usr/local/bin/texlab

        # Clean up temporary files
        cd ~
        rm -rf "$TMP_DIR/texlab_install"

        echo "TexLab installed successfully."
    else
        echo "TexLab is already installed."
    fi
}

install_lemminx() {
    echo "Installing XML Language Server (LemMinX)..."

    # Install necessary dependencies
    if ! command -v mvn &>/dev/null; then
        echo "Maven is not installed. Installing Maven..."
        apt-get update
        apt-get install -y maven || { echo "Failed to install Maven"; exit 1; }
    fi
    if ! command -v java &>/dev/null; then
        echo "Java is not installed. Installing Java (GraalVM)..."
        apt-get install -y graalvm-ce-java11 || { echo "Failed to install GraalVM"; exit 1; }
    fi

    # Clone the LemMinX repository
    if [ ! -d "/tmp/lemminx" ]; then
        git clone https://github.com/eclipse/lemminx.git /tmp/lemminx || { echo "Failed to clone LemMinX repository"; exit 1; }
    fi

    # Build LemMinX
    cd /tmp/lemminx
    mvn package -DskipTests || { echo "Failed to build LemMinX"; exit 1; }

    # Install the JAR file
    cp org.eclipse.lemminx/target/org.eclipse.lemminx-uber.jar /usr/local/bin/lemminx.jar || { echo "Failed to install LemMinX"; exit 1; }

    # Add an alias to your .zshrc
    echo "alias lemminx='java -jar /usr/local/bin/lemminx.jar'" >> ~/.zshrc

    echo "LemMinX installed successfully. Restart your terminal or run 'source ~/.zshrc' to use it."
}

# Function to install Go Language Server
install_go_language_server() {
    echo "Installing Go Language Server (gopls)..."
    go install golang.org/x/tools/gopls@latest || { echo "Failed to install gopls"; exit 1; }
    echo "Go Language Server installed successfully."
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

install_golang() {
    echo "Installing the latest stable version of Go Programming Language..."

    # Fetch the latest stable Go version
    LATEST_GO_VERSION=$(curl -s https://go.dev/VERSION?m=text | tr -d '\n' | grep -oP '^go\d+\.\d+(\.\d+)?')
    GO_ARCH="linux-amd64"

    # Check if Go is already installed and at the correct version
    if command -v go &>/dev/null; then
        INSTALLED_GO_VERSION=$(go version | awk '{print $3}')
        if [[ "$INSTALLED_GO_VERSION" == "$LATEST_GO_VERSION" ]]; then
            echo "Go $LATEST_GO_VERSION is already installed. Skipping installation."
            return 0
        else
            echo "Updating Go from $INSTALLED_GO_VERSION to $LATEST_GO_VERSION."
        fi
    else
        echo "Go is not installed. Proceeding with installation."
    fi

    # Download Go tarball
    wget "https://go.dev/dl/$LATEST_GO_VERSION.$GO_ARCH.tar.gz" -O /tmp/go.tar.gz || { echo "Failed to download Go"; exit 1; }

    # Remove previous Go installation, if it exists
    rm -rf /usr/local/go

    # Install Go by extracting the tarball
    tar -C /usr/local -xzf /tmp/go.tar.gz || { echo "Failed to extract Go"; exit 1; }

    # Temporarily add /usr/local/go/bin to the PATH for both user and sudo
    export PATH="/usr/local/go/bin:$PATH"
    sudo bash -c "export PATH='/usr/local/go/bin:$PATH'"

    # Ensure /usr/local/go/bin is in the PATH for future sessions
    echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee -a /root/.bashrc
    echo 'export PATH=$PATH:/usr/local/go/bin' >> "$USER_HOME/.zshrc"
    echo 'export PATH=$PATH:/usr/local/go/bin' >> "$USER_HOME/.bashrc"

    # Verify installation
    if go version | grep -q "$LATEST_GO_VERSION"; then
        echo "Go $LATEST_GO_VERSION successfully installed."
    else
        echo "Go installation failed."
        exit 1
    fi
}


# --- Main Script Execution ---

echo "----- Starting Setup Script -----"

# Execute the internet check
check_internet_connection

# Install essential packages
install_dependencies

# Install GO
install_golang

# Install Python tools
install_python_tools

# Install CheckMake via Go
install_checkmake

# Remove existing Vim installations (Optional)
remove_system_vim

# Install tmux from Git
remove_outdated_tmux
install_tmux_from_git

# Start tmux server and create default session
start_tmux_server

# Install Vim from source with dynamic version detection
install_vim_from_source

# Install Node.js
install_nodejs

# Install and configure Zsh and Oh My Zsh
kill_tmux_sessions
setup_zsh
clone_zsh_plugins

# Restart tmux server to apply changes
restart_tmux_server

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

# Install MATLAB
#install_matlab

# Install additional language servers
install_perl_language_server
#install_matlab_language_server
install_texlab
install_lemminx
install_go_language_server

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

# Ensure home directory ownership is correct
ensure_home_ownership

# Clean up package manager cache
echo "Cleaning up package manager cache..."
apt-get autoremove -y && apt-get clean

echo "----- Setup Completed Successfully! -----"

# --- Final Cleanup ---
cleanup

# Remove the trap to prevent cleanup from running again
trap - ERR EXIT

echo "----- Setup Script Finished -----"

# --- End of Script ---
