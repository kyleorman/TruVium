#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

# --- Configuration Variables ---
SCRIPT_DIR="/vagrant"  # Directory where the script is being executed
USER_HOME=$(eval echo ~$SUDO_USER)
LOGFILE="/var/log/setup-script.log"
TMUX_VERSION="3.5"
TMP_DIR="/tmp/tmux_install"
INSTALL_PREFIX="/usr/local"

# Redirect all output to LOGFILE
exec > >(tee -a "$LOGFILE") 2>&1

# --- Function Definitions ---

# Function to remove outdated tmux if present
remove_outdated_tmux() {
    echo "Checking for existing tmux installation..."
    if command -v tmux &> /dev/null; then
        CURRENT_VERSION=$(tmux -V | awk '{print $2}')
        if [ "$CURRENT_VERSION" != "$TMUX_VERSION" ]; then
            echo "Outdated tmux version $CURRENT_VERSION found. Removing it..."
            sudo apt-get remove -y --purge tmux || { echo "Failed to remove tmux"; exit 1; }
        else
            echo "tmux $TMUX_VERSION is already installed."
            return 0
        fi
    else
        echo "tmux is not installed."
    fi
}

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

    # Create a cleanup function to remove temporary files on exit
    cleanup() {
        echo "Cleaning up temporary directory..."
        rm -rf "$TMP_DIR"
    }
    trap cleanup EXIT

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
        bison

    # Clone the tmux repository if not already cloned
    if [[ ! -d "tmux" ]]; then
        echo "Cloning tmux repository from GitHub..."
        git clone https://github.com/tmux/tmux.git
    else
        echo "tmux repository already cloned. Fetching latest changes..."
        cd tmux || { echo "Failed to navigate to tmux directory"; exit 1; }
        git fetch --all
    fi

    cd tmux || { echo "Failed to navigate to tmux directory"; exit 1; }

    echo "Checking out tmux version $TMUX_VERSION..."
    git checkout "tags/$TMUX_VERSION" || git checkout "$TMUX_VERSION" || { echo "Failed to checkout version $TMUX_VERSION"; exit 1; }

    # Autogen, configure, make, and install steps
    echo "Running autogen to generate configure script..."
    sh autogen.sh || { echo "Failed to run autogen.sh"; exit 1; }

    echo "Configuring tmux build with prefix $INSTALL_PREFIX..."
    ./configure --prefix="$INSTALL_PREFIX" || { echo "Configuration failed"; exit 1; }

    echo "Building tmux using $(nproc) parallel jobs..."
    make -j"$(nproc)" || { echo "Build failed"; exit 1; }

    echo "Installing tmux..."
    make install || { echo "Installation failed"; exit 1; }

    # Verify installation
    if tmux -V | grep -q "$TMUX_VERSION"; then
        echo "tmux $TMUX_VERSION successfully installed from Git."
    else
        echo "tmux installation from Git failed."
        exit 1
    fi

    # Fix permissions (if necessary)
    echo "Fixing ownership of user home directory and /tmp..."
    chown -R "$SUDO_USER:$SUDO_USER" "$USER_HOME" || echo "Failed to change ownership of $USER_HOME"
    chown -R "$SUDO_USER:$SUDO_USER" /tmp || echo "Failed to change ownership of /tmp"

    echo "tmux installation process completed successfully."
}


# Ensure no tmux session is running during Oh My Zsh installation
kill_tmux_sessions() {
    echo "Killing any running tmux sessions before Oh My Zsh installation..."
    if tmux ls &> /dev/null; then
        sudo -u "$SUDO_USER" tmux kill-server
        echo "tmux server stopped."
    else
        echo "No tmux sessions were running."
    fi
}

setup_zsh() {
    local user_home=$(eval echo ~$SUDO_USER)

    echo "Changing shell to zsh for $SUDO_USER..."

    # Change default shell to zsh for the actual user
    if chsh -s /bin/zsh "$SUDO_USER"; then
        echo "Shell successfully changed to zsh for $SUDO_USER."
    else
        echo "Failed to change shell for $SUDO_USER."
        return 1
    fi

    echo "Installing Oh My Zsh for $SUDO_USER..."

    # Install Oh My Zsh using the official unattended method
    if sudo -u "$SUDO_USER" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; then
        echo "Oh My Zsh installed successfully."
    else
        echo "Oh My Zsh installation failed."
        return 1
    fi

    # Backup existing .zshrc if it exists
    if [ -f "$user_home/.zshrc" ]; then
        cp "$user_home/.zshrc" "$user_home/.zshrc.bak"
        echo "Existing .zshrc backed up to $user_home/.zshrc.bak"
    fi

    # Append new configuration to .zshrc
    echo "Setting up .zshrc for $SUDO_USER..."
    {
        echo 'export TERM="xterm-256color"'
        echo 'export PATH="$HOME/.local/bin:$PATH"'
        echo 'export PATH="/usr/bin:$PATH"'
        echo 'export PATH="$HOME/go/bin:$PATH"'
        echo 'export PATH="/usr/local/bin:$PATH"'
        echo 'export ZDOTDIR="$HOME/.zsh"'
        echo ''
        echo 'if command -v tmux &> /dev/null && [ -z "$TMUX" ]; then'
        echo '  tmux attach-session -t default || tmux new-session -s default'
        echo 'fi'
        echo ''
        echo '# Fix tmux startup issues with non-existent directories'
        echo 'if [ ! -d "$PWD" ]; then'
        echo '  cd $HOME'
        echo 'fi'
    } >> "$user_home/.zshrc"
    sudo -u "$SUDO_USER" bash -c "source $user_home/.zshrc"
    echo ".zshrc setup complete for $SUDO_USER."
}


# --- Main Script ---

# Ensure the script is run with sudo
if [ -z "${SUDO_USER:-}" ]; then
    echo "This script must be run with sudo."
    exit 1
fi

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

# Function to ensure TPM is installed
ensure_tpm_installed() {
    echo "Verifying Tmux Plugin Manager (TPM) installation..."
    TPM_DIR="$USER_HOME/.tmux/plugins/tpm"
    if [ ! -d "$TPM_DIR" ]; then
        echo "Cloning Tmux Plugin Manager (TPM)..."
        sudo -u "$SUDO_USER" git clone https://github.com/tmux-plugins/tpm "$TPM_DIR" || {
            echo "Failed to clone TPM."
            exit 1
        }
    else
        echo "TPM is already installed."
    fi
}

# Function to ensure Tmux server is running
ensure_tmux_server() {
    echo "Ensuring Tmux server is running for $SUDO_USER..."

    if sudo -u "$SUDO_USER" tmux has-session -t default &>/dev/null; then
        echo "Tmux server is already running for $SUDO_USER."
    else
        echo "Starting a new Tmux session for $SUDO_USER."
        sudo -u "$SUDO_USER" tmux new-session -d -s default || {
            echo "Failed to start Tmux session for $SUDO_USER."
            exit 1
        }
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

    # Determine the Tmux prefix
    TMUX_PREFIX=$(grep '^set-option -g prefix' "$USER_HOME/.tmux.conf" | awk '{print $3}' | tr -d '"') || TMUX_PREFIX=""
    if [ -z "$TMUX_PREFIX" ]; then
        TMUX_PREFIX="C-b" # Default Tmux prefix
        echo "No custom prefix found. Using default prefix 'C-b'."
    else
        echo "Detected Tmux prefix: $TMUX_PREFIX"
    fi

    # Start a detached tmux session named 'plugin_install' running an interactive shell
    sudo -u "$SUDO_USER" tmux new-session -d -s plugin_install "bash" || {
        echo "Failed to create 'plugin_install' session."
        return 1
    }

    # Wait until the session is ready
    attempts=0
    max_attempts=5
    while ! sudo -u "$SUDO_USER" tmux has-session -t plugin_install &>/dev/null; do
        sleep 1
        attempts=$((attempts + 1))
        if [ "$attempts" -ge "$max_attempts" ]; then
            echo "Timeout waiting for 'plugin_install' session to be ready."
            return 1
        fi
    done

    echo "'plugin_install' session exists."

    # Send the key sequence to install plugins: <prefix> + I
    sudo -u "$SUDO_USER" tmux send-keys -t plugin_install:0.0 "$TMUX_PREFIX" "I" C-m || {
        echo "Failed to send keys to 'plugin_install' session."
        return 1
    }

    # Wait for the installation to complete
    sleep 5

    # Kill the 'plugin_install' session
    sudo -u "$SUDO_USER" tmux kill-session -t plugin_install || {
        echo "Failed to kill 'plugin_install' session."
        return 1
    }

    echo "Tmux plugins installation triggered."
}

# Function to check if TPM plugins are installed
check_tpm_installation() {
    echo "Checking if TPM plugins are installed..."

    # List installed plugins
    TMUX_PLUGINS_INSTALLED=$(sudo -u "$SUDO_USER" tmux list-plugins 2>/dev/null || echo "")

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
        vim -u NONE -c "helptags $doc_dir" -c "qall" || {
            echo "Warning: Failed to generate helptags for '$plugin_dir'."
        }
    fi
}

# --- Begin Script Execution ---

# Ensure the script is run with sudo
if [ -z "${SUDO_USER:-}" ]; then
    echo "This script must be run with sudo."
    exit 1
fi

# Redirect all output to LOGFILE is already handled at the top

# Execute the internet check
check_internet_connection

# Add Vim PPA before updating the system
echo "Adding Vim PPA..."
apt-get update -y
apt-get install -y software-properties-common
add-apt-repository -y ppa:jonathonf/vim

# Update system, upgrade, and fix broken packages
echo "Updating and upgrading system packages..."
apt-get update -y && apt-get upgrade -y
apt --fix-broken install -y || { echo "Failed to fix broken packages"; exit 1; }

# Install essential packages including Vim (removed desktop-related packages)
echo "Installing essential packages..."
apt-get install -y build-essential dkms linux-headers-$(uname -r) \
    software-properties-common curl wget git golang python3 python3-pip python3-venv ninja-build pkg-config pipenv \
    cmake zsh vim-gtk3 make gcc perl gnat zlib1g-dev gperf flex desktop-file-utils libgtk-3-dev libgtk-4-dev libjudy-dev \
    libbz2-dev libgirepository1.0-dev exuberant-ctags htop vagrant virtualbox-guest-utils shellcheck \
    pandoc fonts-powerline grep sed bc xclip acpi passwd xauth xorg openbox xdg-utils || { echo "Package installation failed"; exit 1; }

# Install VirtualBox Guest Additions utilities
echo "Installing VirtualBox Guest Additions utilities..."
apt-get install -y virtualbox-guest-utils virtualbox-guest-x11 || { echo "Failed to install VirtualBox guest additions"; exit 1; }

# Remove outdated tmux if necessary
remove_outdated_tmux

# Install tmux from git
install_tmux_from_git

kill_tmux_sessions

setup_zsh

echo "tmux setup complete."

# Ensure .vim folder exists before changing permissions
echo "Creating .vim directory..."
mkdir -p "$USER_HOME/.vim"
chown -R "$SUDO_USER:$SUDO_USER" "$USER_HOME/.vim"

# Backup existing .vimrc if it exists
if [ -f "$USER_HOME/.vimrc" ]; then
    cp "$USER_HOME/.vimrc" "$USER_HOME/.vimrc.bak"
    echo "Existing .vimrc backed up to .vimrc.bak"
fi

# Copy .vimrc to user's home directory
echo "Copying .vimrc to user home directory..."
if [ -f "$SCRIPT_DIR/vimrc" ]; then
    cp "$SCRIPT_DIR/vimrc" "$USER_HOME/.vimrc"
    chown "$SUDO_USER:$SUDO_USER" "$USER_HOME/.vimrc"
    chmod 644 "$USER_HOME/.vimrc"
    echo ".vimrc copied successfully."
else
    echo "Warning: .vimrc not found in $SCRIPT_DIR. Skipping copy."
fi

# --- Vim Plugin Management ---

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

# Backup existing .tmux.conf if it exists
if [ -f "$USER_HOME/.tmux.conf" ]; then
    cp "$USER_HOME/.tmux.conf" "$USER_HOME/.tmux.conf.bak"
    echo "Existing .tmux.conf backed up to .tmux.conf.bak"
fi

# Copy .tmux.conf to user's home directory
echo "Copying .tmux.conf to user home directory..."
if [ -f "$SCRIPT_DIR/tmux.conf" ]; then
    cp "$SCRIPT_DIR/tmux.conf" "$USER_HOME/.tmux.conf"
    chown "$SUDO_USER:$SUDO_USER" "$USER_HOME/.tmux.conf"
    chmod 644 "$USER_HOME/.tmux.conf"
    echo ".tmux.conf copied successfully."
else
    echo "Warning: .tmux.conf not found in $SCRIPT_DIR. Skipping copy."
fi

# Copy .tmux_keys.sh to user's home directory
echo "Copying .tmux_keys.sh to user home directory..."
if [ -f "$SCRIPT_DIR/tmux_keys.sh" ]; then
    cp "$SCRIPT_DIR/tmux_keys.sh" "$USER_HOME/.tmux_keys.sh"
    chown "$SUDO_USER:$SUDO_USER" "$USER_HOME/.tmux_keys.sh"
    chmod 644 "$USER_HOME/.tmux_keys.sh"
    echo ".tmux_keys.sh copied successfully."
else
    echo "Warning: .tmux_keys.sh not found in $SCRIPT_DIR. Skipping copy."
fi

# Copy yank to system bin directory
echo "Copying yank to system bin directory..."
if [ -f "$SCRIPT_DIR/yank" ]; then
    cp "$SCRIPT_DIR/yank" "/bin/yank"
    # Set proper ownership (root:root)
    chown root:root "/bin/yank"
    # Set permissions to make it executable
    chmod 755 "/bin/yank"
    echo "yank copied successfully to /bin."
else
    echo "Warning: yank not found in $SCRIPT_DIR. Skipping copy."
fi

# --- Tmux Plugin Manager (TPM) and Plugins Installation ---

echo "Installing Tmux Plugin Manager (TPM) and tmux plugins..."

# Define tmux plugins to install (including TPM itself)
TMUX_PLUGINS=(
    "tmux-plugins/tpm"                    # TPM itself
    "tmux-plugins/tmux-resurrect"         # Restore tmux sessions
    "tmux-plugins/tmux-continuum"         # Continuous tmux auto-saving
    "tmux-plugins/tmux-yank"              # Enhanced copy-paste
    "tmux-plugins/tmux-prefix-highlight"   # Highlight when prefix is pressed
    "tmux-plugins/tmux-copycat"           # Enhanced search in tmux
    "tmux-plugins/tmux-open"              # Open files/directories
    "tmux-plugins/tmux-battery"           # Display battery status
	"tmux-plugins/tmux-sensible"
    # Add more tmux plugins here as needed
)

# Function to clone tmux plugins
clone_tmux_plugin() {
    local plugin="$1"
    local plugin_name=$(basename "$plugin")
    local target_dir="$USER_HOME/.tmux/plugins/$plugin_name"

    if [ -d "$target_dir" ]; then
        echo "Tmux plugin '$plugin_name' already exists. Skipping clone."
    else
        echo "Cloning tmux plugin '$plugin_name' into '$target_dir'..."
        sudo -u "$SUDO_USER" git clone --depth=1 "https://github.com/$plugin.git" "$target_dir" || {
            echo "Error: Failed to clone tmux plugin '$plugin_name'."
            exit 1
        }
        echo "Successfully cloned tmux plugin '$plugin_name'."
    fi
}

# Clone each tmux plugin
for plugin in "${TMUX_PLUGINS[@]}"; do
    clone_tmux_plugin "$plugin"
done

# Set ownership and permissions for tmux plugins
echo "Setting ownership and permissions for tmux plugins..."
sudo chown -R "$SUDO_USER:$SUDO_USER" "$USER_HOME/.tmux/plugins" || {
    echo "Error: Failed to set ownership for tmux plugins."
    exit 1
}

echo "Tmux Plugin Manager and plugins installed successfully."

# --- Ensure Tmux Server is Running ---
ensure_tmux_server

# --- Automate TPM Plugin Installation ---
automate_tpm_install

# --- Check TPM Plugin Installation ---
check_tpm_installation

# Optional: Instruct the user to manually trigger installation if needed
echo "If plugins are not installed automatically, please start a new tmux session and press <prefix> + I (e.g., Ctrl-b + I) to install them."

# Parameterize Node.js version and check if Node.js is already installed
NODE_VERSION=${NODE_VERSION:-18.x}
if ! command -v node &> /dev/null; then
    echo "Installing Node.js $NODE_VERSION..."
    curl -fsSL https://deb.nodesource.com/setup_"$NODE_VERSION" | bash -
    apt-get install -y nodejs || { echo "Node.js installation failed"; exit 1; }
else
    echo "Node.js is already installed."
fi

npm install -g npm

echo "Installing dependencies for coc.nvim..."

COC_DIR="$START_PLUGIN_DIR/coc.nvim"

if [ -d "$COC_DIR" ]; then
    echo "Changing ownership of coc.nvim directory to $SUDO_USER..."
    sudo chown -R "$SUDO_USER:$SUDO_USER" "$COC_DIR"

    echo "Running 'npm ci' in coc.nvim directory..."
    sudo -u "$SUDO_USER" bash -c "cd '$COC_DIR' && npm ci" || {
        echo "Error: Failed to install dependencies for coc.nvim."
        exit 1
    }
    echo "Dependencies for coc.nvim installed successfully."
else
    echo "Error: coc.nvim directory not found at '$COC_DIR'."
    exit 1
fi

# Install FZF with path and error protection
echo "Installing FZF..."
if [ ! -d "$USER_HOME/.fzf" ]; then
    sudo -u "$SUDO_USER" git clone --depth 1 https://github.com/junegunn/fzf.git "$USER_HOME/.fzf" || { echo "FZF clone failed"; exit 1; }
    sudo -u "$SUDO_USER" bash -c "$USER_HOME/.fzf/install --all" || { echo "FZF installation failed"; exit 1; }
    echo "FZF installed successfully."
else
    echo "FZF is already installed."
fi

# --- Symbolic Links for ftdetect ---
FTDETECT_SRC_DIR="$USER_HOME/.vim/pack/plugins/start/ultisnips/ftdetect"
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

# Define the desired plugins
DESIRED_PLUGINS="plugins=(git zsh-syntax-highlighting zsh-autosuggestions)"

# Check if the plugins line exists in .zshrc
if grep -q "^plugins=" "$USER_HOME/.zshrc"; then
    # Replace the existing plugins line
    sed -i "s/^plugins=.*/$DESIRED_PLUGINS/" "$USER_HOME/.zshrc"
else
    # Add the plugins line after the line that sources oh-my-zsh.sh
    sed -i "/^source.*oh-my-zsh.sh/a $DESIRED_PLUGINS" "$USER_HOME/.zshrc"
fi

echo "Plugins configured in .zshrc."

# Ensure correct ownership and permissions
chown "$SUDO_USER:$SUDO_USER" "$USER_HOME/.zshrc"
chmod 644 "$USER_HOME/.zshrc"

# Clone Zsh plugins as the user
echo "Cloning Zsh plugins..."
sudo -u "$SUDO_USER" git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM:-$USER_HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" || true
sudo -u "$SUDO_USER" git clone https://github.com/zsh-users/zsh-autosuggestions.git "${ZSH_CUSTOM:-$USER_HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" || true



# Install Python linters, formatters, and hdl-checker
echo "Installing Python tools..."
pip3 install --upgrade pip
pip3 install flake8 pylint black mypy autopep8 jedi doq hdl-checker meson vsg tox ipython jupyter jupyter-console || { echo "Failed to install Python tools"; exit 1; }

# Install CheckMake via Go (as apt version has issues)
echo "Installing CheckMake via Go..."
sudo -u "$SUDO_USER" go install github.com/mrtazz/checkmake/cmd/checkmake@latest || { echo "CheckMake installation failed"; exit 1; }

echo "Setting up Python docstrings..."

PYDOCSTRING_DIR="$USER_HOME/.vim/pack/plugins/start/vim-pydocstring"

if [ -d "$PYDOCSTRING_DIR" ]; then
    # Ensure correct permissions for the plugin directory
    sudo chown -R "$SUDO_USER:$SUDO_USER" "$PYDOCSTRING_DIR"

    # Run the installation command as the user
    sudo -u "$SUDO_USER" bash -c "
        cd '$PYDOCSTRING_DIR' || exit
        make install || true
    "
else
    echo "Error: vim-pydocstring directory not found."
fi

# Copy coc-settings.json to the user's .vim directory
echo "Copying coc-settings.json to the .vim directory..."
if [ -f "$SCRIPT_DIR/coc-settings.json" ]; then
    cp "$SCRIPT_DIR/coc-settings.json" "$USER_HOME/.vim/coc-settings.json"
    chown "$SUDO_USER:$SUDO_USER" "$USER_HOME/.vim/coc-settings.json"
    chmod 644 "$USER_HOME/.vim/coc-settings.json"
    echo "coc-settings.json copied successfully."
else
    echo "Warning: coc-settings.json not found in $SCRIPT_DIR. Skipping copy."
fi

# --- GTKWAVE Installation ---
# Clone the GTKWAVE repository and install it using meson
echo "Cloning GTKWAVE repository..."
sudo -u "$SUDO_USER" git clone https://github.com/gtkwave/gtkwave.git /tmp/gtkwave || { echo "GTKWAVE clone failed"; exit 1; }

cd /tmp/gtkwave || exit
echo "Building GTKWAVE..."
meson setup build && meson compile -C build || { echo "GTKWAVE build failed"; exit 1; }
sudo meson install -C build || { echo "GTKWAVE installation failed"; exit 1; }
cd ~

# --- GHDL Installation ---
# Clone the GHDL repository and install it from source
echo "Cloning GHDL repository..."
sudo -u "$SUDO_USER" git clone https://github.com/ghdl/ghdl.git /tmp/ghdl || { echo "GHDL clone failed"; exit 1; }

cd /tmp/ghdl || exit
echo "Building and installing GHDL..."
./configure --prefix=/usr/local && make && sudo make install || { echo "GHDL build or installation failed"; exit 1; }
cd ~

# Verify the installation
echo "Verifying GHDL installation..."
ghdl --version || { echo "GHDL verification failed"; exit 1; }

# Configuring Git
echo "Configuring Git..."
if sudo -u "$SUDO_USER" bash /vagrant/git_setup.sh --config-file /vagrant/git_setup.conf --non-interactive; then
    echo "Git configured successfully."
else
    echo "Git configuration failed."
    exit 1
fi

# Clean up package manager cache
echo "Cleaning up..."
rm -rf /tmp/gtkwave /tmp/ghdl
apt-get autoremove -y && apt-get clean

echo "Setup completed successfully!"
