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

# Function to install Python tools via pacman, yay (AUR), and pipx as needed
install_python_tools() {
    echo "Starting installation of Python tools via pacman, yay (AUR), and pipx..."

    # List of Python packages to install
    PYTHON_PACKAGES=(
        flake8
        python-pylint
        python-black
        mypy
        autopep8
        python-jedi
        python-tox
        ipython
        jupyterlab
        python-pexpect
        meson
        python-doq
        python-vsg
    )

    MISSING_PACKAGES=()

    # Function to install a package via pacman
    install_via_pacman() {
        local package="$1"
        echo "Attempting to install '$package' via pacman..."
        if pacman -S --noconfirm --needed "$package"; then
            echo "Successfully installed '$package' via pacman."
            return 0
        else
            echo "Package '$package' not found in official repositories."
            return 1
        fi
    }

    # Function to check and install AUR packages via yay
    install_via_yay() {
        local package="$1"
        echo "Checking if '$package' is available in the AUR..."
        if su - "$ACTUAL_USER" -c "yay -Ss ^$package$" | grep -q "^aur/$package"; then
            echo "Installing '$package' from AUR..."
            local retry=3
            while (( retry > 0 )); do
                if su - "$ACTUAL_USER" -c "yay -S --noconfirm --needed $package"; then
                    echo "Successfully installed '$package' via yay."
                    return 0
                else
                    echo "Failed to install '$package' via yay. Retries left: $((retry-1))"
                    ((retry--))
                    sleep 2
                fi
            done
            echo "Failed to install '$package' from AUR after multiple attempts."
            return 1
        else
            echo "Package '$package' not found in AUR."
            return 1
        fi
    }

    # Function to install a package via pipx
    install_via_pipx() {
        local package="$1"
        # Remove 'python-' prefix if present for pipx installation
        local pipx_package="${package#python-}"
        echo "Installing '$pipx_package' via pipx..."
        if su - "$ACTUAL_USER" -c "pipx install $pipx_package"; then
            echo "Successfully installed '$pipx_package' via pipx."
            return 0
        else
            echo "Failed to install '$pipx_package' via pipx."
            return 1
        fi
    }

    # Iterate over each Python package
    for package in "${PYTHON_PACKAGES[@]}"; do
        if pacman -Qi "$package" &>/dev/null; then
            echo "Package '$package' is already installed via pacman."
        else
            if ! install_via_pacman "$package"; then
                MISSING_PACKAGES+=("$package")
            fi
        fi
    done

    # Attempt to install missing packages via AUR
    if [ ${#MISSING_PACKAGES[@]} -ne 0 ]; then
        AUR_PACKAGES=()
        for package in "${MISSING_PACKAGES[@]}"; do
            # Check if package is already installed via yay
            if su - "$ACTUAL_USER" -c "yay -Qi $package" &>/dev/null; then
                echo "Package '$package' is already installed via yay."
            else
                AUR_PACKAGES+=("$package")
            fi
        done

        # Clear MISSING_PACKAGES to re-evaluate after AUR installation attempts
        MISSING_PACKAGES=()

        for package in "${AUR_PACKAGES[@]}"; do
            if ! install_via_yay "$package"; then
                MISSING_PACKAGES+=("$package")
            fi
        done
    fi

    # Install remaining packages via pipx
    if [ ${#MISSING_PACKAGES[@]} -ne 0 ]; then
        echo "Attempting to install remaining packages via pipx: ${MISSING_PACKAGES[*]}"

        # Check if pipx is installed
        if ! command -v pipx &>/dev/null; then
            echo "pipx not found. Installing pipx..."
            if ! su - "$ACTUAL_USER" -c "python3 -m pip install --user pipx"; then
                echo "Failed to install pipx via pip. Falling back to virtual environment."
                install_python_tools_in_venv "${MISSING_PACKAGES[@]}"
                return
            fi
            if ! su - "$ACTUAL_USER" -c "python3 -m pipx ensurepath"; then
                echo "Failed to ensure pipx path. Falling back to virtual environment."
                install_python_tools_in_venv "${MISSING_PACKAGES[@]}"
                return
            fi
        fi

        # Install each missing package via pipx
        for package in "${MISSING_PACKAGES[@]}"; do
            if ! install_via_pipx "$package"; then
                echo "Attempting to install '$package' via pipx in a virtual environment as a last resort."
                install_python_tools_in_venv "$package"
            fi
        done
    fi

    echo "Python tools installation process completed."
}

# Fallback function to use virtual environment and pipx to install Python tools
install_python_tools_in_venv() {
    local packages=("$@")
    echo "Falling back to virtual environment for Python tools installation..."

    # Define virtual environment directory
    VENV_DIR="$USER_HOME/.venv"

    # Create a virtual environment if it doesn't exist
    if ! su - "$ACTUAL_USER" -c "test -d $VENV_DIR"; then
        echo "Creating virtual environment at '$VENV_DIR'..."
        su - "$ACTUAL_USER" -c "python3 -m venv $VENV_DIR" || {
            echo "Failed to create virtual environment."
            exit 1
        }
    else
        echo "Virtual environment already exists at '$VENV_DIR'."
    fi

    # Install pipx within the virtual environment
    echo "Installing pipx in the virtual environment..."
    su - "$ACTUAL_USER" -c "$VENV_DIR/bin/pip install pipx" || {
        echo "Failed to install pipx in the virtual environment."
        exit 1
    }

    # Activate the virtual environment and install the packages via pipx
    echo "Activating virtual environment and installing packages via pipx..."
    for package in "${packages[@]}"; do
        local pipx_package="${package#python-}"
        su - "$ACTUAL_USER" -c "source $VENV_DIR/bin/activate && pipx install $pipx_package" || {
            echo "Failed to install '$pipx_package' via pipx in the virtual environment."
            exit 1
        }
    done

    echo "Successfully installed packages via virtual environment."
}

# Install Verible
install_verible_from_source() {
    echo "Installing Verible from source..."

    # Ensure the temporary directory exists
    mkdir -p "$TMP_DIR"
    cd "$TMP_DIR" || { echo "Failed to access temporary directory $TMP_DIR"; exit 1; }

    # Install Verible dependencies
    echo "Installing Verible dependencies..."
	pacman -S --noconfirm --needed git autoconf flex bison gcc make libtool curl || { echo "Failed to install dependencies"; exit 1; }
	
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
    if grep -q "plugins=(" "$USER_HOME/.zshrc"; then
        # Check if the plugins already contain the necessary entries
        if ! grep -q "zsh-syntax-highlighting" "$USER_HOME/.zshrc"; then
	    sed -i 's/plugins=(/plugins=(zsh-syntax-highlighting /' "$USER_HOME/.zshrc"
        fi
        if ! grep -q "zsh-autosuggestions" "$USER_HOME/.zshrc"; then
	    sed -i 's/plugins=(/plugins=(zsh-autosuggestions /' "$USER_HOME/.zshrc"
        fi
    else
        # If no plugins line exists, add it
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
	if ! command -v nvim &> /dev/null || ! nvim --version | grep -q '^NVIM v0\.\([9-9]\|1[0-9]\)'; then
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

# Install hdl_checker
install_hdl_checker_with_pipx() {
    echo "Installing hdl_checker using pipx..."

    # Define a separate temporary directory for hdl_checker installation
    HCL_TMP_DIR="/tmp/hdl_checker_install"

    # Ensure the temporary directory exists
    mkdir -p "$HCL_TMP_DIR" || { echo "Failed to create temporary directory $HCL_TMP_DIR"; exit 1; }
    cd "$HCL_TMP_DIR" || { echo "Failed to access temporary directory $HCL_TMP_DIR"; exit 1; }

    # Install necessary dependencies using pacman
    echo "Installing dependencies for hdl_checker..."
    sudo pacman -S --noconfirm --needed python-setuptools python-pip python-wheel git base-devel python-pipx || {
        echo "Failed to install dependencies"; exit 1;
    }

    # Ensure pipx path as ACTUAL_USER
    echo "Ensuring pipx path..."
    su - "$ACTUAL_USER" -c "python3 -m pipx ensurepath" || { echo "Failed to ensure pipx path"; exit 1; }

    # Determine the user's shell and corresponding rc file
    USER_SHELL=$(getent passwd "$ACTUAL_USER" | cut -d: -f7)
    SHELL_RC=""

    case "$USER_SHELL" in
        */zsh)
            SHELL_RC="$USER_HOME/.zshrc"
            ;;
        */bash)
            SHELL_RC="$USER_HOME/.bashrc"
            ;;
        *)
            SHELL_RC="$USER_HOME/.bashrc"
            ;;
    esac

    # Add ~/.local/bin to PATH in the user's shell config if not already present
    if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$SHELL_RC"; then
        echo "Adding ~/.local/bin to PATH in $SHELL_RC..."
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
    fi

    # Clone the hdl_checker repository
    echo "Cloning hdl_checker repository..."
    git clone https://github.com/suoto/hdl_checker.git || { echo "Failed to clone hdl_checker repository"; exit 1; }
    cd hdl_checker || { echo "Failed to navigate to hdl_checker directory"; exit 1; }

    # Fix Git dubious ownership warning by marking the directory as safe
    echo "Marking the Git directory as safe..."
    git config --global --add safe.directory "$HCL_TMP_DIR/hdl_checker"

    # Ensure the user has ownership of the cloned repository
    echo "Fixing ownership of the cloned repository..."
    sudo chown -R "$ACTUAL_USER:$ACTUAL_USER" "$HCL_TMP_DIR/hdl_checker"

    # Apply patches if necessary
    echo "Checking if patches are required for versioneer.py..."
    if grep -q 'SafeConfigParser' versioneer.py || grep -q 'readfp' versioneer.py; then
        echo "Applying patches for Python 3 compatibility..."
        sed -i 's/SafeConfigParser/ConfigParser/g' versioneer.py
        sed -i 's/readfp/read_file/g' versioneer.py
    fi

    # Additional fix for escape sequence warning
    echo "Fixing escape sequences in versioneer.py..."
    sed -i 's/\\s/\\\\s/g' versioneer.py

    # Install hdl_checker using pipx as ACTUAL_USER
    echo "Installing hdl_checker using pipx..."
    su - "$ACTUAL_USER" -c "pipx install '$HCL_TMP_DIR/hdl_checker'" || { echo "Failed to install hdl_checker via pipx"; exit 1; }

    # Verify installation
    echo "Verifying hdl_checker installation..."
    su - "$ACTUAL_USER" -c "command -v hdl_checker" >/dev/null 2>&1 && echo "hdl_checker installed successfully." || { echo "hdl_checker installation failed."; exit 1; }

    # Clean up temporary directory
    echo "Cleaning up temporary files..."
    rm -rf "$HCL_TMP_DIR" || echo "Failed to remove temporary directory $HCL_TMP_DIR"
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
install_hdl_checker_with_pipx

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
