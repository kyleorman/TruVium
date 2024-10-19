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
NEOVIM_VERSION="${NEOVIM_VERSION:-}"   # Optional: Specify Neovim version, defaults to latest stable
EMACS_VERSION="${EMACS_VERSION:-}"     # Optional: Specify Emacs version, defaults to latest

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
    
    # Remove GTKWAVE and GHDL build directories
    for dir in /tmp/gtkwave /tmp/ghdl /tmp/lemminx /tmp/nerd-fonts /tmp/doxygen; do
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
    
    # Remove Neovim source directory if it exists
    NEOVIM_SRC_DIR="$TMP_DIR/neovim"
    if [ -d "$NEOVIM_SRC_DIR" ]; then
        echo "Removing Neovim source directory: $NEOVIM_SRC_DIR"
        rm -rf "$NEOVIM_SRC_DIR" || echo "Failed to remove $NEOVIM_SRC_DIR"
    else
        echo "Neovim source directory $NEOVIM_SRC_DIR does not exist. Skipping."
    fi

    # Remove Emacs source directory if it exists
    EMACS_SRC_DIR="$TMP_DIR/emacs"
    if [ -d "$EMACS_SRC_DIR" ]; then
        echo "Removing Emacs source directory: $EMACS_SRC_DIR"
        rm -rf "$EMACS_SRC_DIR" || echo "Failed to remove $EMACS_SRC_DIR"
    else
        echo "Emacs source directory $EMACS_SRC_DIR does not exist. Skipping."
    fi

    # Remove MATLAB Language Server directory if it exists
    MATLAB_LS_DIR="$TMP_DIR/MATLAB-language-server"
    if [ -d "$MATLAB_LS_DIR" ]; then
        echo "Removing MATLAB Language Server directory: $MATLAB_LS_DIR"
        rm -rf "$MATLAB_LS_DIR" || echo "Failed to remove $MATLAB_LS_DIR"
    else
        echo "MATLAB Language Server directory $MATLAB_LS_DIR does not exist. Skipping."
    fi

    # Remove TexLab installation directory if it exists
    TEXLAB_INSTALL_DIR="$TMP_DIR/texlab_install"
    if [ -d "$TEXLAB_INSTALL_DIR" ]; then
        echo "Removing TexLab installation directory: $TEXLAB_INSTALL_DIR"
        rm -rf "$TEXLAB_INSTALL_DIR" || echo "Failed to remove $TEXLAB_INSTALL_DIR"
    else
        echo "TexLab installation directory $TEXLAB_INSTALL_DIR does not exist. Skipping."
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
    #chown -R "$ACTUAL_USER:$ACTUAL_USER" /tmp || echo "Failed to change ownership of /tmp"

    echo "tmux installation process completed successfully."
}

# Function to start tmux server and create default session
start_tmux_server() {
    echo "Starting tmux server and creating default session..."
    tmux start-server
    tmux new-session -d -s default || echo "Default tmux session already exists."
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
    #chown -R "$ACTUAL_USER:$ACTUAL_USER" /tmp || echo "Failed to change ownership of /tmp"

    echo "Vim installation process completed successfully."

    # Optionally, remove Vim source directory to save space
    # Uncomment the following lines if you wish to remove the source
    # echo "Cleaning up Vim source files..."
    # rm -rf "$VIM_SRC_DIR"
}

# Function to install Neovim from source with optional version
install_neovim_from_source() {
    echo "Installing Neovim from source..."

    # Define variables
    NEOVIM_SRC_DIR="$TMP_DIR/neovim"

    # Install dependencies
    echo "Installing Neovim build dependencies..."
    apt-get update -y
    apt-get install -y --no-install-recommends \
        ninja-build \
        gettext \
        libtool \
        libtool-bin \
        autoconf \
        automake \
        cmake \
        g++ \
        pkg-config \
        unzip \
        curl \
        doxygen || { echo "Failed to install Neovim build dependencies"; exit 1; }

    # Clone Neovim repository
    mkdir -p "$NEOVIM_SRC_DIR"
    cd "$NEOVIM_SRC_DIR" || { echo "Failed to access Neovim source directory"; exit 1; }

    if [ ! -d "neovim" ]; then
        echo "Cloning Neovim repository..."
        git clone https://github.com/neovim/neovim.git || { echo "Failed to clone Neovim repository"; exit 1; }
    fi

    cd neovim || { echo "Failed to navigate to Neovim directory"; exit 1; }

    # Fetch all tags from the repository
    echo "Fetching all Neovim tags..."
    git fetch --all --tags --prune || { echo "Failed to fetch Neovim tags"; exit 1; }

    # Determine the Neovim version to install
    if [ -z "$NEOVIM_VERSION" ]; then
        # Determine the latest stable Neovim version tag
        echo "Determining the latest stable Neovim tag..."
        NEOVIM_VERSION_TAG=$(git tag -l "v*" --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+(\.[0-9]+)?$' | head -n1)
        echo "Latest Neovim tag detected: $NEOVIM_VERSION_TAG"
        if [ -z "$NEOVIM_VERSION_TAG" ]; then
            echo "Error: Unable to determine the latest stable Neovim version tag."
            exit 1
        fi
        NEOVIM_VERSION="${NEOVIM_VERSION_TAG#v}"  # Remove the 'v' prefix
    else
        # Use the specified NEOVIM_VERSION
        NEOVIM_VERSION_TAG="v$NEOVIM_VERSION"
        echo "Using specified Neovim version tag: $NEOVIM_VERSION_TAG"
    fi

    echo "Selected Neovim version tag: $NEOVIM_VERSION_TAG"
    echo "Expected Neovim version string: v$NEOVIM_VERSION"

    # Check if the desired version is already checked out
    CURRENT_CHECKOUT=$(git describe --tags --exact-match 2>/dev/null || echo "")
    if [ "$CURRENT_CHECKOUT" = "v$NEOVIM_VERSION_TAG" ]; then
        echo "Neovim is already checked out at version v$NEOVIM_VERSION_TAG."
    else
        # Checkout the desired Neovim version
        echo "Checking out Neovim version v$NEOVIM_VERSION_TAG..."
        git checkout "$NEOVIM_VERSION_TAG" || { echo "Failed to checkout Neovim version $NEOVIM_VERSION_TAG"; exit 1; }
    fi

    # Build Neovim
    echo "Building Neovim..."
    make CMAKE_BUILD_TYPE=RelWithDebInfo || { echo "Neovim build failed"; exit 1; }

    # Install Neovim
    echo "Installing Neovim..."
    make install || { echo "Neovim installation failed"; exit 1; }

    # Verify installation
    echo "Verifying Neovim installation..."
    INSTALLED_NVIM_VERSION=$(/usr/local/bin/nvim --version | head -n1 | awk '{print $2}')
    echo "Installed Neovim version: $INSTALLED_NVIM_VERSION"
    EXPECTED_NVIM_VERSION="v$NEOVIM_VERSION"
    echo "Expected Neovim version: $EXPECTED_NVIM_VERSION"

    # Extract major and minor versions for comparison
    INSTALLED_NVIM_MAIN_VERSION=$(echo "$INSTALLED_NVIM_VERSION" | awk -F. '{print $1"."$2}')
    EXPECTED_NVIM_MAIN_VERSION=$(echo "$EXPECTED_NVIM_VERSION" | awk -F. '{print $1"."$2}')

    echo "Installed Neovim main version: $INSTALLED_NVIM_MAIN_VERSION"
    echo "Expected Neovim main version: $EXPECTED_NVIM_MAIN_VERSION"

    if [ "$INSTALLED_NVIM_MAIN_VERSION" = "$EXPECTED_NVIM_MAIN_VERSION" ]; then
        echo "Neovim $EXPECTED_NVIM_VERSION successfully installed."
    else
        echo "Neovim installation verification failed."
        echo "Expected main version: $EXPECTED_NVIM_MAIN_VERSION, but found main version: $INSTALLED_NVIM_MAIN_VERSION"
        # You can choose to exit or continue
        # exit 1
    fi

    # Fix permissions
    echo "Fixing ownership of user home directory and /tmp..."
    chown -R "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME" || echo "Failed to change ownership of $USER_HOME"
    #chown -R "$ACTUAL_USER:$ACTUAL_USER" /tmp || echo "Failed to change ownership of /tmp"

    echo "Neovim installation process completed successfully."
}

# LazyVim setup (Optional)
install_lazyvim() {
    echo "Installing LazyVim..."

    # Ensure Neovim 0.9 or higher is installed
    if ! command -v nvim &> /dev/null || ! nvim --version | awk 'NR==1 {exit ($2 < 0.9)}'; then
        echo "Neovim 0.9 or higher is not installed. Please install it before proceeding."
        return 1
    fi

    # Ensure git is installed
    apt-get update && apt-get install -y git || { echo "Failed to install git"; exit 1; }

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


# Function to install Emacs from source
install_emacs_from_source() {
    echo "Installing Emacs from source..."

    # Define variables
    EMACS_SRC_DIR="$TMP_DIR/emacs"
    EMACS_INSTALL_PREFIX="$INSTALL_PREFIX"

    # Install dependencies
    echo "Installing Emacs build dependencies..."
    apt-get update -y
    apt-get install -y --no-install-recommends \
        build-essential \
        texinfo \
        libgtk-3-dev \
        libjpeg-dev \
        libpng-dev \
        libgif-dev \
        libtiff-dev \
        libxpm-dev \
        libncurses-dev \
        libgnutls28-dev \
        libxml2-dev \
        libjansson-dev \
        libharfbuzz-dev \
        libsystemd-dev \
        libsqlite3-dev \
        autoconf \
        automake \
        libmagickwand-dev \
        libgpm-dev \
        libdbus-1-dev \
        libm17n-dev \
        libotf-dev \
        librsvg2-dev \
        liblcms2-dev \
        libwebkit2gtk-4.0-dev \
        libgccjit-11-dev \
        libtree-sitter-dev \
        libjansson-dev \
        mailutils || { echo "Failed to install Emacs build dependencies"; exit 1; }

    # Clone Emacs repository
    mkdir -p "$EMACS_SRC_DIR"
    cd "$EMACS_SRC_DIR" || { echo "Failed to access Emacs source directory"; exit 1; }

    if [ ! -d "emacs" ]; then
        echo "Cloning Emacs repository..."
        git clone https://github.com/emacs-mirror/emacs.git || { echo "Failed to clone Emacs repository"; exit 1; }
    fi

    cd emacs || { echo "Failed to navigate to Emacs directory"; exit 1; }

    # Fetch all tags from the repository
    echo "Fetching all Emacs tags..."
    git fetch --all --tags --prune || { echo "Failed to fetch Emacs tags"; exit 1; }

    # Determine the Emacs version to install
    if [ -z "$EMACS_VERSION" ]; then
        # Determine the latest stable Emacs version tag
        echo "Determining the latest stable Emacs tag..."
        EMACS_VERSION_TAG=$(git tag -l | grep '^emacs-[0-9]' | sort -V | tail -n1)
        echo "Latest Emacs tag detected: $EMACS_VERSION_TAG"
        if [ -z "$EMACS_VERSION_TAG" ]; then
            echo "Error: Unable to determine the latest stable Emacs version tag."
            exit 1
        fi
        EMACS_VERSION="${EMACS_VERSION_TAG#emacs-}"  # Remove the 'emacs-' prefix
    else
        # Use the specified EMACS_VERSION
        EMACS_VERSION_TAG="emacs-$EMACS_VERSION"
        echo "Using specified Emacs version tag: $EMACS_VERSION_TAG"
    fi

    echo "Selected Emacs version tag: $EMACS_VERSION_TAG"
    echo "Expected Emacs version string: $EMACS_VERSION"

    # Checkout the desired Emacs version
    echo "Checking out Emacs version $EMACS_VERSION_TAG..."
    git checkout "$EMACS_VERSION_TAG" || { echo "Failed to checkout Emacs version $EMACS_VERSION_TAG"; exit 1; }

    # Clean any previous build artifacts
    make clean || true
    git clean -fdx || true

    # Build Emacs
    echo "Building Emacs..."
    ./autogen.sh || { echo "autogen.sh failed"; exit 1; }
    ./configure --prefix="$EMACS_INSTALL_PREFIX" --with-json --with-native-compilation --with-mailutils || { echo "Emacs configuration failed"; exit 1; }
    make -j"$(nproc)" || { echo "Emacs build failed"; exit 1; }

    # Install Emacs
    echo "Installing Emacs..."
    make install || { echo "Emacs installation failed"; exit 1; }

    # Verify installation
    echo "Verifying Emacs installation..."
    INSTALLED_EMACS_VERSION=$(/usr/local/bin/emacs --version | head -n1 | awk '{print $3}')
    echo "Installed Emacs version: $INSTALLED_EMACS_VERSION"
    EXPECTED_EMACS_VERSION="$EMACS_VERSION"
    echo "Expected Emacs version: $EXPECTED_EMACS_VERSION"

    # Extract major and minor versions for comparison
    INSTALLED_EMACS_MAIN_VERSION=$(echo "$INSTALLED_EMACS_VERSION" | awk -F. '{print $1"."$2}')
    EXPECTED_EMACS_MAIN_VERSION=$(echo "$EXPECTED_EMACS_VERSION" | awk -F. '{print $1"."$2}')

    echo "Installed Emacs main version: $INSTALLED_EMACS_MAIN_VERSION"
    echo "Expected Emacs main version: $EXPECTED_EMACS_MAIN_VERSION"

    if [ "$INSTALLED_EMACS_MAIN_VERSION" = "$EXPECTED_EMACS_MAIN_VERSION" ]; then
        echo "Emacs $EXPECTED_EMACS_VERSION successfully installed."
    else
        echo "Emacs installation verification failed."
        echo "Expected main version: $EXPECTED_EMACS_MAIN_VERSION, but found main version: $INSTALLED_EMACS_MAIN_VERSION"
        # You can choose to exit or continue
        # exit 1
    fi

    # Fix permissions
    echo "Fixing ownership of user home directory and /tmp..."
    chown -R "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME" || echo "Failed to change ownership of $USER_HOME"
    #chown -R "$ACTUAL_USER:$ACTUAL_USER" /tmp || echo "Failed to change ownership of /tmp"

    echo "Emacs installation process completed successfully."
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
    apt-get update && apt-get install -y ripgrep fd-find || { echo "Failed to install dependencies"; exit 1; }

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

    # Add the all-the-icons configuration to config.el
    #CONFIG_FILE="$USER_HOME/.doom.d/config.el"
    #echo "Ensuring all-the-icons is loaded in config.el..."
    #if ! grep -q "(use-package! all-the-icons" "$CONFIG_FILE"; then
    #    su - "$ACTUAL_USER" bash -c "echo \"(use-package! all-the-icons :ensure t)\" >> \"$CONFIG_FILE\""
    #fi

    # Let Doom install its own configuration
    su - "$ACTUAL_USER" -c "$USER_HOME/.emacs.d/bin/doom install --force" || { echo "Doom Emacs installation failed"; exit 1; }

    # Fix ownership of .emacs.d and .doom.d directories
    echo "Fixing ownership of .emacs.d and .doom.d directories..."
    chown -R "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME/.emacs.d" "$USER_HOME/.doom.d" || echo "Failed to change ownership of $USER_HOME/.emacs.d or $USER_HOME/.doom.d"

    # Sync Doom Emacs packages to ensure all-the-icons is installed
    echo "Syncing Doom Emacs packages..."
    su - "$ACTUAL_USER" -c "$USER_HOME/.emacs.d/bin/doom sync" || { echo "Doom Emacs package sync failed"; exit 1; }

    # Install all-the-icons fonts for Doom Emacs
    #echo "Installing all-the-icons fonts for Doom Emacs..."
    #su - "$ACTUAL_USER" emacs --batch --eval '(progn (require '\''all-the-icons) (all-the-icons-install-fonts t))' || { echo "Failed to install all-the-icons fonts"; exit 1; }

    # Add Doom's bin directory to PATH
    if ! grep -q "export PATH=\"$HOME/.emacs.d/bin:\$PATH\"" "$USER_HOME/.zshrc"; then
    echo 'Adding Doom Emacs to PATH...'
    echo "export PATH=\"$HOME/.emacs.d/bin:\$PATH\"" >> "$USER_HOME/.zshrc"
    fi

    # Optional: Run Doom doctor non-interactively
    #echo "Running Doom Emacs doctor to diagnose potential issues (output will be logged)..."
    #su - "$ACTUAL_USER" -c "$USER_HOME/.emacs.d/bin/doom doctor &> $USER_HOME/doom_doctor.log" || echo "Doom Emacs doctor reported issues (check doom_doctor.log)."

    echo "Doom Emacs installed successfully."
}

install_nerd_fonts() {
    echo "Installing all Nerd Fonts..."

    # Ensure the necessary dependencies are installed (e.g., curl, unzip)
    apt-get update && apt-get install -y curl unzip || { echo "Failed to install dependencies"; exit 1; }

    # Download Nerd Fonts repository
    TEMP_DIR="/tmp/nerd-fonts"
    if [ ! -d "$TEMP_DIR" ]; then
        echo "Cloning Nerd Fonts repository..."
        su - "$ACTUAL_USER" -c "git clone --depth 1 https://github.com/ryanoasis/nerd-fonts.git '$TEMP_DIR'" || { echo "Failed to clone Nerd Fonts"; exit 1; }
    else
        echo "Nerd Fonts repository already exists in $TEMP_DIR"
    fi

    # Install all fonts
    echo "Installing all Nerd Fonts..."
    cd "$TEMP_DIR" || { echo "Failed to enter Nerd Fonts directory"; exit 1; }
    ./install.sh || { echo "Failed to install Nerd Fonts"; exit 1; }

    # Clean up temporary directory
    echo "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"

    # Verify installation
    if fc-list | grep -i "nerd"; then
        echo "Nerd Fonts installed successfully!"
    else
        echo "Nerd Fonts installation failed."
        exit 1
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

# Function to restart tmux server
restart_tmux_server() {
    echo "Restarting tmux server to apply shell changes..."
    tmux kill-server || true
    tmux start-server
    tmux new-session -d -s default || echo "Default tmux session already exists."
    echo "tmux server restarted with default session."
}

# Function to ensure TPM (Tmux Plugin Manager) is installed
ensure_tpm_installed() {
    echo "Verifying Tmux Plugin Manager (TPM) installation..."
    TPM_DIR="$USER_HOME/.tmux/plugins/tpm"
    if [ ! -d "$TPM_DIR" ]; then
        echo "Cloning Tmux Plugin Manager (TPM)..."
			git clone https://github.com/tmux-plugins/tpm "$TPM_DIR" || {
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
    tmux new-session -d -s tpm_install "/usr/local/bin/tmux source ~/.tmux.conf && ~/.tmux/plugins/tpm/bin/install_plugins && /usr/local/bin/tmux source ~/.tmux.conf &&  ~/.tmux/plugins/tpm/bin/update_plugins all && /usr/local/bin/tmux source ~/.tmux.conf"
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
        su - "$ACTUAL_USER" bash -c "cd '$COC_DIR' && npm ci" || {
            echo "Error: Failed to install dependencies for coc.nvim."
            exit 1
        }
        echo "Dependencies for coc.nvim installed successfully."

        echo "Installing global npm packages for language servers..."

        NPM_PACKAGES=(
            bash-language-server
            @imc-trading/svlangserver
            yaml-language-server
            vscode-langservers-extracted
            typescript
            typescript-language-server
            pyright
        )

        for package in "${NPM_PACKAGES[@]}"; do
            echo "Installing $package..."
            npm install -g "$package" || {
                echo "Error: Failed to install $package."
                exit 1
            }
        done

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
        su - "$ACTUAL_USER" -c "git clone --depth 1 https://github.com/junegunn/fzf.git '$USER_HOME/.fzf'" || { echo "FZF clone failed"; exit 1; }

        # Ensure .zshrc is owned by the actual user and writable
        chown "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME/.zshrc"
        chmod 644 "$USER_HOME/.zshrc"

        su - "$ACTUAL_USER" bash -c "cd '$USER_HOME/.fzf' && ./install --all" || { echo "FZF installation failed"; exit 1; }
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

# Function to install GTKWAVE
install_gtkwave() {
    echo "Cloning GTKWAVE repository..."
    if ! git clone https://github.com/gtkwave/gtkwave.git /tmp/gtkwave; then
        echo "GTKWAVE clone failed"
        exit 1
    fi

    cd /tmp/gtkwave || { echo "Failed to navigate to /tmp/gtkwave"; exit 1; }

    echo "Building GTKWAVE..."
    if ! meson setup build; then
        echo "GTKWAVE build setup failed"
        exit 1
    fi

    if ! meson compile -C build; then
        echo "GTKWAVE compilation failed"
        exit 1
    fi

    if ! meson install -C build; then
        echo "GTKWAVE installation failed"
        exit 1
    fi

    cd ~ || { echo "Failed to navigate to home directory"; exit 1; }
}

# Function to install GHDL
install_ghdl() {
    echo "Cloning GHDL repository..."
    if ! git clone https://github.com/ghdl/ghdl.git /tmp/ghdl; then
        echo "GHDL clone failed"
        exit 1
    fi

    cd /tmp/ghdl || { echo "Failed to navigate to /tmp/ghdl"; exit 1; }

    echo "Building and installing GHDL..."
    if ! ./configure --prefix=/usr/local; then
        echo "GHDL configuration failed"
        exit 1
    fi

    if ! make; then
        echo "GHDL build failed"
        exit 1
    fi

    if ! make install; then
        echo "GHDL installation failed"
        exit 1
    fi

    cd ~ || { echo "Failed to navigate to home directory"; exit 1; }
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
	echo "Installing Tmux Plugin Manager (TPM) and tmux plugins..."
    ensure_tpm_installed
    automate_tpm_install
    check_tpm_installation
	echo "Tmux Plugin Manager and plugins installed successfully."
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
	ncurses-term \
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
    su - "$ACTUAL_USER" -c "git clone https://github.com/mathworks/MATLAB-language-server.git '$TMP_DIR/MATLAB-language-server'" || { echo 'Failed to clone MATLAB Language Server'; exit 1; }


    # Build the language server
    cd "$TMP_DIR/MATLAB-language-server" || { echo "Failed to access MATLAB Language Server directory"; exit 1; }

    # Set MATLAB_HOME during the build
    su - "$ACTUAL_USER" bash -c "export MATLAB_HOME='$MATLAB_HOME'; ./gradlew installDist" || { echo "Failed to build MATLAB Language Server"; exit 1; }

    # Copy the built server to /usr/local/share
    mkdir -p /usr/local/share/matlab-language-server
    cp -r "$TMP_DIR/MATLAB-language-server/build/install/matlab-language-server/." /usr/local/share/matlab-language-server/ || { echo "Failed to copy MATLAB Language Server"; exit 1; }

    echo "MATLAB Language Server installed successfully."
}

# Function to install Verilator from source
install_verilator() {
    echo "Installing Verilator..."

    # Install required dependencies, including help2man
    echo "Installing dependencies..."
    apt-get update && apt-get install -y git autoconf flex bison make \
        libfl-dev g++ help2man perl python3 || { echo "Failed to install dependencies"; exit 1; }

    # Clone Verilator repository
    echo "Cloning Verilator repository..."
    git clone https://github.com/verilator/verilator.git /tmp/verilator || { echo "Failed to clone Verilator repository"; exit 1; }

    cd /tmp/verilator || { echo "Failed to enter Verilator directory"; exit 1; }

    # Check out the stable branch
    echo "Checking out stable branch..."
    git checkout stable || { echo "Failed to checkout stable branch"; exit 1; }

    # Build and install Verilator
    echo "Building and installing Verilator..."
    autoconf && ./configure && make -j"$(nproc)" && make install || { echo "Failed to build and install Verilator"; exit 1; }

    echo "Verilator installed successfully."
}

# Function to install Icarus Verilog from source
install_iverilog() {
    echo "Installing Icarus Verilog..."

    # Install required dependencies
    echo "Installing dependencies..."
    apt-get update && apt-get install -y git autoconf g++ flex bison libreadline-dev gperf || { echo "Failed to install dependencies"; exit 1; }

    # Clone Icarus Verilog repository
    echo "Cloning Icarus Verilog repository..."
    git clone https://github.com/steveicarus/iverilog.git /tmp/iverilog || { echo "Failed to clone Icarus Verilog repository"; exit 1; }

    cd /tmp/iverilog || { echo "Failed to enter Icarus Verilog directory"; exit 1; }

    # Prepare the build system
    echo "Preparing build system..."
    sh autoconf.sh || { echo "Failed to run autoconf.sh"; exit 1; }

    # Configure the build
    echo "Configuring build..."
    ./configure || { echo "Configuration failed"; exit 1; }

    # Build and install
    echo "Building Icarus Verilog..."
    make -j"$(nproc)" || { echo "Icarus Verilog build failed"; exit 1; }

    echo "Installing Icarus Verilog..."
    make install || { echo "Icarus Verilog installation failed"; exit 1; }

    echo "Icarus Verilog installed successfully."
}

install_bazel_from_source() {
    echo "Installing Bazel..."

    # Install necessary dependencies
    echo "Installing Bazel dependencies..."
    apt-get update -y
    apt-get install -y apt-transport-https curl gnupg lsb-release || { echo "Failed to install dependencies"; exit 1; }

    # Add Bazel distribution URI as a package source
    echo "Adding Bazel distribution URI..."
    curl -fsSL https://bazel.build/bazel-release.pub.gpg | gpg --dearmor | tee /usr/share/keyrings/bazel-archive-keyring.gpg > /dev/null || { echo "Failed to fetch Bazel GPG key"; exit 1; }

    # Determine Ubuntu distribution codename
    UBUNTU_CODENAME=$(lsb_release -sc)

    echo "Adding Bazel repository to sources list..."
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/bazel-archive-keyring.gpg] https://storage.googleapis.com/bazel-apt stable jdk1.8" | tee /etc/apt/sources.list.d/bazel.list

    # Update package list and install Bazel
    echo "Installing Bazel..."
    apt-get update -y && apt-get install -y bazel || { echo "Failed to install Bazel"; exit 1; }

    # Verify installation
    if bazel --version; then
        echo "Bazel installed successfully."
    else
        echo "Bazel installation failed."
        exit 1
    fi
}

install_verible_from_source() {
    echo "Installing Verible from source..."

    # Ensure the temporary directory exists
    mkdir -p "$TMP_DIR"
    cd "$TMP_DIR" || { echo "Failed to access temporary directory $TMP_DIR"; exit 1; }

    # Install Bazel if it's not already installed
    if ! command -v bazel &>/dev/null; then
        echo "Bazel not found, installing Bazel first..."
        install_bazel_from_source || { echo "Failed to install Bazel"; exit 1; }
    fi

    # Install Verible dependencies
    echo "Installing Verible dependencies..."
    apt-get install -y git autoconf flex bison g++ make libfl-dev curl || { echo "Failed to install dependencies"; exit 1; }

    # Clone Verible repository
    echo "Cloning Verible repository..."
    git clone https://github.com/chipsalliance/verible.git /tmp/verible || { echo "Failed to clone Verible repository"; exit 1; }
    cd /tmp/verible || { echo "Failed to navigate to Verible directory"; exit 1; }

    # Build Verible using Bazel
    echo "Building Verible..."
    bazel build //... || { echo "Failed to build Verible"; exit 1; }

    # Install binaries
    echo "Installing Verible binaries..."
    cp bazel-bin/verilog/tools/syntax/verible-verilog-syntax /usr/local/bin/
    cp bazel-bin/verilog/tools/formatter/verible-verilog-format /usr/local/bin/
    cp bazel-bin/verilog/tools/lint/verible-verilog-lint /usr/local/bin/

    # Verify installation
    if verible-verilog-format --version; then
        echo "Verible installed successfully."
    else
        echo "Verible installation failed."
        exit 1
    fi
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
    
    JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
    if [[ -z "$JAVA_VERSION" || ! "$JAVA_VERSION" =~ ^11 ]]; then
        echo "Java 11 is required. Installing OpenJDK 11..."
        apt-get install -y openjdk-11-jdk || { echo "Failed to install OpenJDK 11"; exit 1; }
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
    echo "alias lemminx='java -jar /usr/local/bin/lemminx.jar'" >> "$USER_HOME/.zshrc"
    chown "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME/.zshrc"

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

install_doxygen() {
    echo "Installing Doxygen..."

    # Install dependencies
    echo "Installing Doxygen dependencies..."
    apt-get update -y
    apt-get install -y build-essential cmake flex bison graphviz git || { echo "Failed to install dependencies"; exit 1; }

    # Check if Doxygen is already installed and its version
    if command -v doxygen &>/dev/null; then
        INSTALLED_VERSION=$(doxygen --version)
        echo "Doxygen version $INSTALLED_VERSION is already installed. Skipping installation."
        return 0
    fi

    # Ensure the temporary directory exists
    mkdir -p "$TMP_DIR"
    cd "$TMP_DIR" || { echo "Failed to access temporary directory $TMP_DIR"; exit 1; }

    # Clone the Doxygen repository
    echo "Cloning Doxygen repository..."
    git clone https://github.com/doxygen/doxygen.git || { echo "Failed to clone Doxygen repository"; exit 1; }

    cd doxygen || { echo "Failed to enter Doxygen source directory"; exit 1; }

    # Optionally, checkout a specific version or tag
    # For example, to checkout version 1.9.8:
    # echo "Checking out Doxygen version 1.9.8..."
    # git checkout Release_1_9_8 || { echo "Failed to checkout Doxygen version 1.9.8"; exit 1; }

    # Build and install Doxygen
    echo "Building Doxygen..."
    mkdir build && cd build || { echo "Failed to create build directory"; exit 1; }
    cmake -G "Unix Makefiles" .. || { echo "CMake configuration failed"; exit 1; }
    make -j"$(nproc)" || { echo "Doxygen build failed"; exit 1; }

    echo "Installing Doxygen..."
    make install || { echo "Doxygen installation failed"; exit 1; }

    # Verify installation
    if command -v doxygen &>/dev/null; then
        INSTALLED_VERSION=$(doxygen --version)
        echo "Doxygen version $INSTALLED_VERSION installed successfully."
    else
        echo "Doxygen installation failed."
        exit 1
    fi
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

# Function to ensure /tmp has correct permissions
ensure_tmp_permissions() {
    echo "Ensuring /tmp has correct permissions and ownership..."

    # Check current permissions and ownership
    TMP_PERMISSIONS=$(stat -c "%a" /tmp)
    TMP_OWNER=$(stat -c "%u:%g" /tmp)

    echo "Current /tmp permissions: $TMP_PERMISSIONS"
    echo "Current /tmp ownership: $TMP_OWNER"

    # Set permissions to 1777 if they are not correct
    if [ "$TMP_PERMISSIONS" != "1777" ]; then
        echo "Setting /tmp permissions to 1777..."
        chmod 1777 /tmp || { echo "Failed to set permissions on /tmp"; exit 1; }
    else
        echo "/tmp permissions are already set to 1777."
    fi

    # Set ownership to root:root if not correct
    if [ "$TMP_OWNER" != "0:0" ]; then
        echo "Setting /tmp ownership to root:root..."
        chown root:root /tmp || { echo "Failed to set ownership on /tmp"; exit 1; }
    else
        echo "/tmp ownership is already root:root."
    fi

    echo "/tmp permissions and ownership ensured."
}


# --- Main Script Execution ---

echo "----- Starting Setup Script -----"

# Execute the internet check
check_internet_connection

# Ensure /tmp has correct permissions
ensure_tmp_permissions

# Install essential packages
install_dependencies

# Copy configuration files
copy_config_files

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

# Install Tmux Plugin Manager and tmux plugins
install_tpm

# Start tmux server and create default session
#start_tmux_server

# Install Vim from source with dynamic version detection
install_vim_from_source

# Install Node.js
install_nodejs

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

# Install Doxygen
install_doxygen

# Install additional language servers
#install_matlab_language_server
install_perl_language_server
install_texlab
install_lemminx
install_go_language_server
install_verilator
install_iverilog
install_bazel_from_source
install_verible_from_source

# Install GTKWAVE
install_gtkwave

# Install GHDL
install_ghdl

# Verify GHDL installation
verify_ghdl

# Install and configure Zsh and Oh My Zsh
kill_tmux_sessions
setup_zsh
clone_zsh_plugins

# Restart tmux server to apply changes
#restart_tmux_server

# Install Neovim from source
install_neovim_from_source

# Install LazyVim
install_lazyvim

# Install Emacs from source
install_emacs_from_source

# Install Doom Emacs
install_doom_emacs

# Install Nerd Fonts
install_nerd_fonts

# Ensure home directory ownership is correct
ensure_home_ownership

# Clean up package manager cache
echo "Cleaning up package manager cache..."
apt-get autoremove -y && apt-get clean

echo "----- Setup Completed Successfully! -----"

# Remove the trap to prevent cleanup from running again
trap - ERR EXIT

echo "----- Setup Script Finished -----"

# --- End of Script ---
