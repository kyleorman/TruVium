#!/bin/bash

# Exit immediately if a command exits with a non-zero status,
# if any undefined variable is used, and if any command in a pipeline fails
set -eEuo pipefail
IFS=$'\n\t'

# --- Configuration Variables ---
SCRIPT_DIR="/vagrant"  # Adjust this if needed
LOGFILE="/var/log/setup-script.log"
TMP_DIR="/tmp/setup_script_install"

# Determine the actual user (non-root)
if [ "${SUDO_USER:-}" ]; then
    ACTUAL_USER="$SUDO_USER"
    USER_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
else
    echo "This script must be run with sudo."
    exit 1
fi

# Export environment variables
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

# Enable community repo
ensure_community_repo_enabled() {
    echo "Ensuring that the [community] repository is enabled..."

    PACMAN_CONF="/etc/pacman.conf"

    # Backup the original pacman.conf if not already backed up
    if [ ! -f "${PACMAN_CONF}.bak" ]; then
        cp "$PACMAN_CONF" "${PACMAN_CONF}.bak"
        echo "Backup of pacman.conf created at ${PACMAN_CONF}.bak"
    fi

    # Check if [community] is already enabled
    if grep -q "^\[community\]" "$PACMAN_CONF"; then
        echo "[community] repository is already enabled."
        return
    fi

    # Add the [community] repository to the end of pacman.conf
    echo -e "\n[community]\nInclude = /etc/pacman.d/mirrorlist" >> "$PACMAN_CONF"

    # Verify the changes
    if grep -q "^\[community\]" "$PACMAN_CONF"; then
        echo "[community] repository has been enabled successfully."
        # Update package databases
        pacman -Syy
    else
        echo "Failed to enable [community] repository. Restoring original pacman.conf."
        mv "${PACMAN_CONF}.bak" "$PACMAN_CONF"
        exit 1
    fi
}

# Function to install essential packages
install_dependencies() {
    echo "Installing essential packages..."

    # Combined pacman installation
    pacman -Syu --noconfirm
    pacman -S --noconfirm --needed \
        base-devel \
        git \
        zsh \
        wget \
        curl \
        vim \
        neovim \
        tmux \
        python \
        python-pip \
        lua \
        cmake \
        perl \
        gcc \
        flex \
        bison \
        gperf \
        gtk3 \
        gtk4 \
        ctags \
        htop \
        shellcheck \
        pandoc \
        grep \
        sed \
        bc \
        xclip \
        acpi \
        xorg-xauth \
        xorg-server \
        openbox \
        xdg-utils \
        clang \
        tree \
        copyq \
        tcl \
        ripgrep \
        fd \
        fzf \
        npm \
        nodejs \
        go \
        jdk11-openjdk \  # Remove if not needed
        maven \          # Remove if not needed
        || { echo "Package installation failed"; exit 1; }
}

# Function to install AUR packages with retry mechanism
install_aur_packages() {
    echo "Installing AUR packages..."
    su - "$ACTUAL_USER" -c "command -v yay >/dev/null 2>&1 || (git clone https://aur.archlinux.org/yay.git $TMP_DIR/yay && cd $TMP_DIR/yay && makepkg -si --noconfirm)"
    
    # Define AUR packages to install
    AUR_PACKAGES=(
        nerd-fonts-complete
        perl-language-server
        ghdl
        gtkwave
        texlab
        verilator
        iverilog
        bazel
        lemminx
        emacs-nativecomp
    )
    
    # Install each AUR package with retries
    for package in "${AUR_PACKAGES[@]}"; do
        retry=3
        until su - "$ACTUAL_USER" -c "yay -S --noconfirm --needed $package"; do
            ((retry--))
            if [ $retry -le 0 ]; then
                echo "Failed to install AUR package: $package after multiple attempts."
                exit 1
            fi
            echo "Retrying installation of $package... ($retry attempts left)"
            sleep 2
        done
    done
}

# Function to install Python tools via pacman, yay, and pipx
install_python_tools() {
    echo "Installing Python tools via pacman, yay, and pipx as needed..."

    # Ensure pipx is installed via pacman
    if ! pacman -Qi python-pipx &>/dev/null; then
        echo "Installing pipx..."
        pacman -S --noconfirm --needed python-pipx || { echo "Failed to install pipx"; exit 1; }
    else
        echo "pipx is already installed."
    fi

    # Ensure pipx binary directory is in PATH
    if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$USER_HOME/.zshrc"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$USER_HOME/.zshrc"
    fi

    # List of Python packages to install
    PYTHON_PACKAGES=(
        flake8
        pylint
        black
        mypy
        autopep8
        jedi
        tox
        ipython
        jupyterlab
        pexpect
        meson
        doq
        vsg
    )

    MISSING_PACKAGES=()

    # First, try to install packages via pacman
    for package in "${PYTHON_PACKAGES[@]}"; do
        if ! pacman -Qi "$package" &>/dev/null; then
            echo "Attempting to install $package via pacman..."
            if ! pacman -S --noconfirm --needed "$package"; then
                echo "Package $package not found in official repositories."
                MISSING_PACKAGES+=("$package")
            else
                echo "Package $package installed via pacman."
            fi
        else
            echo "Package $package is already installed."
        fi
    done

    # Attempt to install missing packages via yay (AUR)
    if [ ${#MISSING_PACKAGES[@]} -ne 0 ]; then
        AUR_PACKAGES=()
        for package in "${MISSING_PACKAGES[@]}"; do
            echo "Checking if $package is available in the AUR..."
            if su - "$ACTUAL_USER" -c "yay -Ss ^$package$" | grep -q "^aur/$package"; then
                AUR_PACKAGES+=("$package")
            else
                echo "Package $package not found in AUR."
            fi
        done

        if [ ${#AUR_PACKAGES[@]} -ne 0 ]; then
            echo "Installing packages from AUR: ${AUR_PACKAGES[*]}"
            for package in "${AUR_PACKAGES[@]}"; do
                retry=3
                until su - "$ACTUAL_USER" -c "yay -S --noconfirm --needed $package"; do
                    ((retry--))
                    if [ $retry -le 0 ]; then
                        echo "Failed to install AUR package: $package after multiple attempts."
                        exit 1
                    fi
                    echo "Retrying installation of $package... ($retry attempts left)"
                    sleep 2
                done
            done
        fi

        # Update MISSING_PACKAGES after attempting AUR installations
        NEW_MISSING_PACKAGES=()
        for package in "${MISSING_PACKAGES[@]}"; do
            if ! pacman -Qi "$package" &>/dev/null && ! su - "$ACTUAL_USER" -c "yay -Qi $package" &>/dev/null; then
                NEW_MISSING_PACKAGES+=("$package")
            fi
        done
        MISSING_PACKAGES=("${NEW_MISSING_PACKAGES[@]}")
    fi

    # Install remaining packages via pipx if necessary
    if [ ${#MISSING_PACKAGES[@]} -ne 0 ]; then
        echo "Installing remaining Python tools via pipx: ${MISSING_PACKAGES[*]}"
        for package in "${MISSING_PACKAGES[@]}"; do
            if [[ "$package" == "hdl-checker" ]]; then
                echo "Not Installing hdl-checker using pipx. Please install manually if needed."
            else
                # Remove 'python-' prefix if present for pipx installation
                pipx_package="${package#python-}"
                su - "$ACTUAL_USER" -c "pipx install $pipx_package" || {
                    echo "Failed to install $package via pipx"; exit 1;
                }
            fi
        done
    fi
}

# Install Verible
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



# Function to install CheckMake via Go
install_checkmake() {
    echo "Installing CheckMake via Go..."
    su - "$ACTUAL_USER" -c "go install github.com/mrtazz/checkmake/cmd/checkmake@latest" || { echo "CheckMake installation failed"; exit 1; }

    # Ensure GOPATH/bin is in PATH
    if ! grep -q 'export PATH="$HOME/go/bin:$PATH"' "$USER_HOME/.zshrc"; then
        echo 'export PATH="$HOME/go/bin:$PATH"' >> "$USER_HOME/.zshrc"
    fi
}

# Function to install Go language server
install_go_language_server() {
    echo "Installing Go language server..."
    # Go Language Server
    su - "$ACTUAL_USER" -c "go install golang.org/x/tools/gopls@latest" || { echo "Failed to install gopls"; exit 1; }
}

# Function to install Tmux Plugin Manager and tmux plugins
install_tpm() {
    echo "Installing Tmux Plugin Manager (TPM) and tmux plugins..."
    TPM_DIR="$USER_HOME/.tmux/plugins/tpm"
    if [ ! -d "$TPM_DIR" ]; then
        su - "$ACTUAL_USER" -c "git clone https://github.com/tmux-plugins/tpm '$TPM_DIR'" || { echo "Failed to clone TPM"; exit 1; }
    else
        echo "TPM is already installed."
    fi

    # Initialize TPM in .tmux.conf if not already present
    if ! grep -q "run -b '~/.tmux/plugins/tpm/tpm'" "$USER_HOME/.tmux.conf"; then
        echo "run -b '~/.tmux/plugins/tpm/tpm'" >> "$USER_HOME/.tmux.conf"
    fi

    # Install tmux plugins
    su - "$ACTUAL_USER" -c "tmux start-server && tmux new-session -d && ~/.tmux/plugins/tpm/bin/install_plugins && tmux kill-server" || { echo "Failed to install tmux plugins"; exit 1; }
}

# Function to install Vim plugins
install_vim_plugins() {
    echo "Installing Vim plugins..."
    PLUGIN_DIR="$USER_HOME/.vim/pack/plugins/start"
    su - "$ACTUAL_USER" -c "mkdir -p '$PLUGIN_DIR'"

    # List of plugins (removed 'ale' to avoid duplication with 'coc.nvim')
    PLUGINS=(
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

    for plugin in "${PLUGINS[@]}"; do
        plugin_name=$(basename "$plugin")
        plugin_path="$PLUGIN_DIR/$plugin_name"
        if [ ! -d "$plugin_path" ]; then
            su - "$ACTUAL_USER" -c "git clone https://github.com/$plugin.git '$plugin_path'" || { echo "Failed to clone $plugin"; exit 1; }
        else
            echo "Plugin $plugin is already installed."
        fi
    done

    # Generate helptags
    su - "$ACTUAL_USER" -c "vim -u NONE -c 'helptags ALL' -c q"

    # Install color schemes
    COLOR_PLUGIN_DIR="$USER_HOME/.vim/pack/colors/start"
    su - "$ACTUAL_USER" -c "mkdir -p '$COLOR_PLUGIN_DIR'"
    su - "$ACTUAL_USER" -c "git clone https://github.com/altercation/vim-colors-solarized.git '$COLOR_PLUGIN_DIR/vim-colors-solarized'" || echo "Failed to clone vim-colors-solarized."
    su - "$ACTUAL_USER" -c "git clone https://github.com/rafi/awesome-vim-colorschemes.git '$COLOR_PLUGIN_DIR/awesome-vim-colorschemes'" || echo "Failed to clone awesome-vim-colorschemes."
}

# Function to install and configure Zsh and Oh My Zsh
install_zsh() {
    echo "Installing Oh My Zsh..."
    su - "$ACTUAL_USER" -c "sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" --unattended"

    # Install Zsh plugins
    ZSH_CUSTOM="$USER_HOME/.oh-my-zsh/custom"
    su - "$ACTUAL_USER" -c "git clone https://github.com/zsh-users/zsh-syntax-highlighting.git '$ZSH_CUSTOM/plugins/zsh-syntax-highlighting'" || echo "Failed to clone zsh-syntax-highlighting."
    su - "$ACTUAL_USER" -c "git clone https://github.com/zsh-users/zsh-autosuggestions.git '$ZSH_CUSTOM/plugins/zsh-autosuggestions'" || echo "Failed to clone zsh-autosuggestions."

    # Update .zshrc plugins if not already updated
    if grep -q "plugins=(git" "$USER_HOME/.zshrc"; then
        sed -i 's/plugins=(git/plugins=(git zsh-syntax-highlighting zsh-autosuggestions)/' "$USER_HOME/.zshrc"
    else
        echo "plugins=(git zsh-syntax-highlighting zsh-autosuggestions)" >> "$USER_HOME/.zshrc"
    fi

    # Add custom PATH entries and aliases if not already present
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
}

# Function to install coc.nvim dependencies
install_coc_dependencies() {
    echo "Installing coc.nvim dependencies..."
    su - "$ACTUAL_USER" -c "cd '$USER_HOME/.vim/pack/plugins/start/coc.nvim' && npm install" || { echo "Failed to install coc.nvim dependencies"; exit 1; }
}

# Function to copy configuration files
copy_config_files() {
    echo "Copying configuration files..."
    CONFIG_FILES=(
        "vimrc"
        "tmux.conf"
        "tmux_keys.sh"
        "coc-settings.json"
        "hdl_checker.json"
        "airline_theme.conf"
        "color_scheme.conf"
    )

    for config in "${CONFIG_FILES[@]}"; do
        src="$SCRIPT_DIR/$config"
        dest="$USER_HOME/.$config"
        if [ -f "$src" ]; then
            # Backup existing config if it exists
            if [ -f "$dest" ]; then
                cp "$dest" "${dest}.bak"
                echo "Backup of existing $dest created at ${dest}.bak"
            fi
            cp "$src" "$dest"
            chown "$ACTUAL_USER:$ACTUAL_USER" "$dest"
            echo "Copied $config to $dest."
        else
            echo "Configuration file $src not found."
        fi
    done

    # Copy 'yank' to /usr/local/bin
    if [ -f "$SCRIPT_DIR/yank" ]; then
        cp "$SCRIPT_DIR/yank" "/usr/local/bin/yank"
        chmod +x "/usr/local/bin/yank"
        echo "Copied 'yank' script to /usr/local/bin."
    else
        echo "'yank' script not found."
    fi
}

# Function to configure Git
configure_git() {
    GIT_SETUP_SCRIPT="$SCRIPT_DIR/git_setup.sh"
    GIT_SETUP_CONF="$SCRIPT_DIR/git_setup.conf"

    echo "Configuring Git..."

    if [ -f "$GIT_SETUP_SCRIPT" ] && [ -f "$GIT_SETUP_CONF" ]; then
        su - "$ACTUAL_USER" -c "bash '$GIT_SETUP_SCRIPT' --config-file '$GIT_SETUP_CONF' --non-interactive" || { echo "Git configuration failed"; exit 1; }
    else
        echo "Git setup script or configuration file not found."
    fi
}

# Function to install LazyVim
install_lazyvim() {
    echo "Installing LazyVim..."

    # Ensure Neovim 0.9 or higher is installed
    if ! command -v nvim &> /dev/null || ! nvim --version | grep -q '^NVIM v0\.[9-9]'; then
        echo "Neovim 0.9 or higher is not installed. Please install it before proceeding."
        exit 1
    fi

    # Clone the LazyVim starter repository if not already present
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

    # Install Neovim plugin manager (lazy.nvim) if not already installed
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

    # Run LazyVim's sync command to install plugins
    echo "Running LazyVim's sync command..."
    su - "$ACTUAL_USER" -c "nvim --headless '+Lazy! sync' +qa" || echo "Check health reported issues."

    echo "LazyVim installed successfully."
}

# Function to install Doom Emacs
install_doom_emacs() {
    echo "Installing Doom Emacs..."

    # Check if Emacs is installed and version is 26.1 or higher
    if ! command -v emacs &>/dev/null || ! emacs --version | awk 'NR==1 {exit ($3 < 26.1)}'; then
        echo "Emacs 26.1 or higher is not installed. Please install it before proceeding."
        return 1
    fi

    # Ensure git, ripgrep, and fd are installed
    pacman -S --noconfirm --needed ripgrep fd || { echo "Failed to install dependencies"; exit 1; }

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
        su - "$ACTUAL_USER" -c "mkdir -p '$USER_HOME/.doom.d'"
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

# Function to install hdl-checker from source on Arch Linux
install_hdl_checker_from_source() {
    echo "Installing hdl-checker from source on Arch Linux..."

    # Ensure the temporary directory exists
    mkdir -p "$TMP_DIR"
    cd "$TMP_DIR" || { echo "Failed to access temporary directory $TMP_DIR"; exit 1; }

    # Install necessary dependencies using pacman
    echo "Installing dependencies for hdl-checker..."
    sudo pacman -S --noconfirm --needed python-setuptools python-pip python-wheel git base-devel || {
        echo "Failed to install dependencies"; exit 1;
    }

    # Clone the hdl-checker repository
    echo "Cloning hdl-checker repository..."
    git clone https://github.com/suoto/hdl-checker.git /tmp/hdl-checker || { echo "Failed to clone hdl-checker repository"; exit 1; }
    cd /tmp/hdl-checker || { echo "Failed to navigate to hdl-checker directory"; exit 1; }

    # Build and install hdl-checker
    echo "Building and installing hdl-checker..."
    python3 setup.py install --user || { echo "Failed to build and install hdl-checker"; exit 1; }

    # Verify installation
    if command -v hdl-checker &>/dev/null; then
        echo "hdl-checker installed successfully."
    else
        echo "hdl-checker installation failed."
        exit 1
    fi
}

# Function to ensure home directory ownership is correct
ensure_home_ownership() {
    echo "Ensuring home directory ownership is correct..."
    chown -R "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME"
}

# --- Main Script Execution ---

echo "----- Starting Setup Script -----"

# Execute the internet check
check_internet_connection

# Enable community repo
ensure_community_repo_enabled

# Install essential packages
install_dependencies

# Install AUR packages using yay with retry
install_aur_packages

# Copy configuration files
copy_config_files

# Install Python tools
install_python_tools

# Install CheckMake via Go
install_checkmake

# Install Verible
install_verible_from_source

# Install Tmux Plugin Manager and tmux plugins
install_tpm

# Install Vim plugins
install_vim_plugins

# Install Doom Emacs
install_doom_emacs

# Install LazyVim
install_lazyvim

# Install Go language server
install_go_language_server

# Install hdl_checker
install_hdl_checker_from_source

# Install and configure Zsh and Oh My Zsh
install_zsh

# Configure Git
configure_git

# Install coc.nvim dependencies
install_coc_dependencies

# Ensure home directory ownership is correct
ensure_home_ownership

# Clean up package manager cache
echo "Cleaning up package manager cache..."
pacman -Scc --noconfirm || true

echo "----- Setup Completed Successfully! -----"

# Remove the trap to prevent cleanup from running again
trap - ERR EXIT

echo "----- Setup Script Finished -----"

# --- End of Script ---
