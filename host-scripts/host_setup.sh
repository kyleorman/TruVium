#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

# --- Configuration Variables ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_HOME=$(eval echo ~${SUDO_USER:-$USER})
LOGFILE="/var/log/setup-script.log"
VERBOSE=false  # Set to true for verbose logging

# Redirect all output to LOGFILE
exec > >(tee -a "$LOGFILE") 2>&1

# --- Function Definitions ---

# Function to log messages
log() {
    if [ "$VERBOSE" = true ]; then
        echo "$1"
    fi
}

# Function to check for sudo
check_sudo() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "This script must be run with sudo."
        exit 1
    fi
}

# Function to check internet connection
check_internet_connection() {
    echo "Checking for an active internet connection..."
    if ! ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        echo "Internet connection required. Please check your network."
        exit 1
    else
        echo "Internet connection is active."
    fi
}

# Function to parse .conf config file
parse_conf_config() {
    CONFIG_FILE="$1"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Configuration file $CONFIG_FILE not found!"
        exit 1
    fi

    # Source the config file
    source "$CONFIG_FILE"
}

# Function to ensure tmux is installed
ensure_tmux_installed() {
    echo "Verifying tmux installation..."
    if ! command -v tmux &>/dev/null; then
        echo "Tmux is not installed. Installing tmux..."
        apt-get install -y tmux || { echo "Failed to install tmux." ; exit 1; }
    else
        echo "Tmux is already installed."
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

# Function to display the enhanced text-based menu
display_menu() {
    echo "Select components to install by entering their numbers separated by spaces (e.g., 1 3 5):"
    echo "1) VirtualBox - Virtualization software"
    echo "2) Vagrant - VM environment management"
    echo "3) Zsh - Zsh shell and Oh My Zsh"
    echo "4) Vim - Vim editor and plugins"
    echo "5) Tmux - Terminal multiplexer and plugins"
    echo "6) Docker - Containerization platform"
    echo "7) Flameshot - Screenshot tool"
    echo "8) Variety - Wallpaper changer"
    echo "9) Guake - Drop-down terminal"
    echo "10) Terminator - Terminal emulator with multiple panels"
    echo "11) Chromium - Web browser"
    echo "12) Gnome Tweaks - Advanced settings tool"
    echo "13) Synaptic - Graphical package manager"
    echo "14) VLC - Multimedia player"
    echo "15) GIMP - Image editor"
    echo "16) Timeshift - System backup and restore"
    echo "17) RDP - Remote Desktop Protocol support"
    echo "18) OpenSSH - Remote access via SSH"
    echo "19) Flatpak - Universal app installation"
    echo "20) Snap - Alternative app installation"
    echo "21) BleachBit - System cleaner and privacy tool"
    echo "22) Redshift - Adjust screen color temperature"
    echo "23) KeePassXC - Password manager"
    echo "24) htop - Interactive process viewer"
    echo "25) Git - Version control system"
    echo "26) Network Tools - nmap, net-tools"
    echo "27) GParted - Disk partition editor"
    echo "28) All of the above"
    echo "29) Exit"

    # Initialize installation flags
    declare -A INSTALL_OPTIONS
    for i in {1..27}; do
        INSTALL_OPTIONS[$i]="no"
    done

    # Prompt user for choices
    while true; do
        read -rp "Enter your choices: " choices
        valid_input=true
        for choice in $choices; do
            if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt 29 ]; then
                echo "Invalid choice: $choice"
                valid_input=false
            fi
        done
        if [ "$valid_input" = true ]; then
            break
        else
            echo "Please enter valid choices from the list."
        fi
    done

    # Process selections
    for choice in $choices; do
        case $choice in
        1)
            INSTALL_VIRTUALBOX="yes"
            ;;
        2)
            INSTALL_VAGRANT="yes"
            ;;
        3)
            INSTALL_ZSH="yes"
            ;;
        4)
            INSTALL_VIM="yes"
            ;;
        5)
            INSTALL_TMUX="yes"
            ;;
        6)
            INSTALL_DOCKER="yes"
            ;;
        7)
            INSTALL_FLAMESHOT="yes"
            ;;
        8)
            INSTALL_VARIETY="yes"
            ;;
        9)
            INSTALL_GUAKE="yes"
            ;;
        10)
            INSTALL_TERMINATOR="yes"
            ;;
        11)
            INSTALL_CHROMIUM="yes"
            ;;
        12)
            INSTALL_GNOME_TWEAKS="yes"
            ;;
        13)
            INSTALL_SYNAPTIC="yes"
            ;;
        14)
            INSTALL_VLC="yes"
            ;;
        15)
            INSTALL_GIMP="yes"
            ;;
        16)
            INSTALL_TIMESHIFT="yes"
            ;;
        17)
            INSTALL_RDP="yes"
            ;;
        18)
            INSTALL_SSH_SERVER="yes"
            ;;
        19)
            INSTALL_FLATPAK="yes"
            ;;
        20)
            INSTALL_SNAPS="yes"
            ;;
        21)
            INSTALL_BLEACHBIT="yes"
            ;;
        22)
            INSTALL_REDSHIFT="yes"
            ;;
        23)
            INSTALL_KEEPASSXC="yes"
            ;;
        24)
            INSTALL_HTOP="yes"
            ;;
        25)
            INSTALL_GIT="yes"
            ;;
        26)
            INSTALL_NETWORK_TOOLS="yes"
            ;;
        27)
            INSTALL_GPARTED="yes"
            ;;
        28)
            # Set all installation flags to "yes"
            INSTALL_VIRTUALBOX="yes"
            INSTALL_VAGRANT="yes"
            INSTALL_ZSH="yes"
            INSTALL_VIM="yes"
            INSTALL_TMUX="yes"
            INSTALL_DOCKER="yes"
            INSTALL_FLAMESHOT="yes"
            INSTALL_VARIETY="yes"
            INSTALL_GUAKE="yes"
            INSTALL_TERMINATOR="yes"
            INSTALL_CHROMIUM="yes"
            INSTALL_GNOME_TWEAKS="yes"
            INSTALL_SYNAPTIC="yes"
            INSTALL_VLC="yes"
            INSTALL_GIMP="yes"
            INSTALL_TIMESHIFT="yes"
            INSTALL_RDP="yes"
            INSTALL_SSH_SERVER="yes"
            INSTALL_FLATPAK="yes"
            INSTALL_SNAPS="yes"
            INSTALL_BLEACHBIT="yes"
            INSTALL_REDSHIFT="yes"
            INSTALL_KEEPASSXC="yes"
            INSTALL_HTOP="yes"
            INSTALL_GIT="yes"
            INSTALL_NETWORK_TOOLS="yes"
            INSTALL_GPARTED="yes"
            ;;
        29)
            echo "Exiting."
            exit 0
            ;;
        esac
    done

    confirm_installation
}

# Function to confirm installation choices
confirm_installation() {
    echo "You have selected the following components for installation:"
    for var in "${!INSTALL_@}"; do
        if [ "${!var}" == "yes" ]; then
            component_name="${var#INSTALL_}"
            echo "- $component_name"
        fi
    done
    while true; do
        read -rp "Do you want to proceed with the installation? (yes/no): " confirmation
        case "$confirmation" in
            yes|y|Y)
                break
                ;;
            no|n|N)
                echo "Installation aborted."
                exit 0
                ;;
            *)
                echo "Please enter 'yes' or 'no'."
                ;;
        esac
    done
}

# Function to update and upgrade the system
system_update_upgrade() {
    echo "Updating and upgrading system packages..."
    apt-get update -y && apt-get upgrade -y
    apt --fix-broken install -y || { echo "Failed to fix broken packages"; exit 1; }
}

# Installation functions for each component
install_virtualbox() {
    echo "Installing VirtualBox..."
    apt-get install -y virtualbox || { echo "Failed to install VirtualBox"; exit 1; }
}

install_vagrant() {
    echo "Installing Vagrant..."
    apt-get install -y vagrant || { echo "Failed to install Vagrant"; exit 1; }
}

install_zsh() {
    echo "Installing Zsh..."
    apt-get install -y zsh

    echo "Changing shell to zsh for $SUDO_USER..."
    chsh -s /usr/bin/zsh "$SUDO_USER"

    echo "Installing Oh My Zsh..."
    sudo -u "$SUDO_USER" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

    echo "Configuring Zsh plugins..."
    sudo -u "$SUDO_USER" git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM:-$USER_HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" || true
    sudo -u "$SUDO_USER" git clone https://github.com/zsh-users/zsh-autosuggestions.git "${ZSH_CUSTOM:-$USER_HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" || true

    sed -i 's/plugins=(git)/plugins=(git zsh-syntax-highlighting zsh-autosuggestions)/' "$USER_HOME/.zshrc"

	echo "Setting up zshrc entries..."
	{
		echo 'export TERM="xterm-256color"'
		echo 'export PATH="$HOME/.local/bin:$PATH"'
		echo 'export PATH="/usr/bin:$PATH"'
		echo 'export PATH="$HOME/go/bin:$PATH"'
		echo ''
		echo 'if command -v tmux &> /dev/null && [ -z "$TMUX" ]; then'
		echo '  tmux attach-session -t default || tmux new-session -s default'
		echo 'fi'
	} >> "$USER_HOME/.zshrc"

	# Source .zshrc to apply changes
    sudo -u "$SUDO_USER" zsh -c "source $USER_HOME/.zshrc"
}

install_vim() {
	echo "Adding Vim PPA..."
	apt-get update -y
	apt-get install -y software-properties-common
	add-apt-repository -y ppa:jonathonf/vim
	system_update_upgrade

    echo "Installing Vim..."

    apt-get install -y vim-gtk3

	# Ensure .vim folder exists before changing permissions
	echo "Creating .vim directory..."
	mkdir -p "$USER_HOME/.vim"
	chown -R "$SUDO_USER:$SUDO_USER" "$USER_HOME/.vim"

    echo "Configuring Vim..."
    if [ -f "$SCRIPT_DIR/vimrc" ]; then
        cp "$SCRIPT_DIR/vimrc" "$USER_HOME/.vimrc"
        chown "$SUDO_USER:$SUDO_USER" "$USER_HOME/.vimrc"
    else
        echo "vimrc not found in $SCRIPT_DIR"
    fi

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

	# Install Python linters, formatters, and hdl-checker
	echo "Installing Python tools..."
	pip3 install --upgrade pip
	pip3 install flake8 pylint black mypy autopep8 jedi doq hdl-checker meson vsg tox || { echo "Failed to install Python tools"; exit 1; }

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

	echo "Vim plugins installed and helptags generated successfully."
}

install_tmux() {
    echo "Installing Tmux..."
    apt-get install -y tmux

    echo "Configuring Tmux..."
    if [ -f "$SCRIPT_DIR/tmux.conf" ]; then
        cp "$SCRIPT_DIR/tmux.conf" "$USER_HOME/.tmux.conf"
        chown "$SUDO_USER:$SUDO_USER" "$USER_HOME/.tmux.conf"
    else
        echo "tmux.conf not found in $SCRIPT_DIR"
    fi

    # Install Tmux Plugin Manager and plugins
    # Add your plugin installation steps here

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
}

install_docker() {
    echo "Installing Docker..."
    apt-get remove -y docker docker-engine docker.io containerd runc || true
    apt-get update -y
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

    add-apt-repository \
        "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable"

    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io

    echo "Adding $SUDO_USER to docker group..."
    usermod -aG docker "$SUDO_USER"
}

install_flameshot() {
    echo "Installing Flameshot..."
    apt-get install -y flameshot || { echo "Failed to install Flameshot"; exit 1; }
    configure_flameshot_shortcuts
}

configure_flameshot_shortcuts() {
    echo "Configuring Flameshot keyboard shortcuts..."
    sudo -u "$SUDO_USER" dbus-launch gsettings set org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/custom0/ name 'Flameshot'
    sudo -u "$SUDO_USER" dbus-launch gsettings set org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/custom0/ command 'flameshot gui'
    sudo -u "$SUDO_USER" dbus-launch gsettings set org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/custom0/ binding "['<Shift><Print>']"
}

install_variety() {
    echo "Installing Variety..."
    apt-get install -y variety || { echo "Failed to install Variety"; exit 1; }
    enable_variety_autostart
}

enable_variety_autostart() {
    echo "Enabling Variety autostart..."
    sudo -u "$SUDO_USER" mkdir -p "$USER_HOME/.config/autostart"
    cp /usr/share/applications/variety.desktop "$USER_HOME/.config/autostart/"
    chown "$SUDO_USER:$SUDO_USER" "$USER_HOME/.config/autostart/variety.desktop"
}

install_guake() {
    echo "Installing the latest version of Guake..."
    add-apt-repository -y ppa:linuxuprising/guake
    apt-get update -y
    apt-get install -y guake || { echo "Failed to install Guake"; exit 1; }
}

install_terminator() {
    echo "Installing Terminator..."
    apt-get install -y terminator || { echo "Failed to install Terminator"; exit 1; }
}

install_chromium() {
    echo "Installing Chromium browser..."
    apt-get install -y chromium-browser || { echo "Failed to install Chromium"; exit 1; }
}

install_gnome_tweaks() {
    echo "Installing Gnome Tweaks..."
    apt-get install -y gnome-tweaks || { echo "Failed to install Gnome Tweaks"; exit 1; }
}

install_synaptic() {
    echo "Installing Synaptic Package Manager..."
    apt-get install -y synaptic || { echo "Failed to install Synaptic"; exit 1; }
}

install_vlc() {
    echo "Installing VLC Media Player..."
    apt-get install -y vlc || { echo "Failed to install VLC"; exit 1; }
}

install_gimp() {
    echo "Installing GIMP..."
    apt-get install -y gimp || { echo "Failed to install GIMP"; exit 1; }
}

install_timeshift() {
    echo "Installing Timeshift..."
    apt-get install -y timeshift || { echo "Failed to install Timeshift"; exit 1; }
}

install_rdp() {
    echo "Installing Remote Desktop Protocol (RDP) support..."
    apt-get install -y xrdp || { echo "Failed to install xrdp"; exit 1; }
    systemctl enable xrdp
    systemctl start xrdp
}

install_ssh_server() {
    echo "Installing OpenSSH Server..."
    apt-get install -y openssh-server || { echo "Failed to install OpenSSH Server"; exit 1; }
    systemctl enable ssh
    systemctl start ssh
}

install_flatpak() {
    echo "Installing Flatpak..."
    apt-get install -y flatpak || { echo "Failed to install Flatpak"; exit 1; }
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
}

install_snaps() {
    echo "Installing Snap support..."
    apt-get install -y snapd || { echo "Failed to install Snap support"; exit 1; }
}

install_bleachbit() {
    echo "Installing BleachBit..."
    apt-get install -y bleachbit || { echo "Failed to install BleachBit"; exit 1; }
}

install_redshift() {
    echo "Installing Redshift..."
    apt-get install -y redshift-gtk || { echo "Failed to install Redshift"; exit 1; }
}

install_keepassxc() {
    echo "Installing KeePassXC..."
    apt-get install -y keepassxc || { echo "Failed to install KeePassXC"; exit 1; }
}

install_htop() {
    echo "Installing htop..."
    apt-get install -y htop || { echo "Failed to install htop"; exit 1; }
}

install_git() {
    echo "Installing Git..."
    apt-get install -y git || { echo "Failed to install Git"; exit 1; }
}

install_network_tools() {
    echo "Installing network tools..."
    apt-get install -y nmap net-tools || { echo "Failed to install network tools"; exit 1; }
}

install_gparted() {
    echo "Installing GParted..."
    apt-get install -y gparted || { echo "Failed to install GParted"; exit 1; }
}

install_fonts() {
    echo "Installing additional fonts..."
    apt-get install -y fonts-powerline fonts-firacode || { echo "Failed to install fonts"; exit 1; }
}

system_update() {
    echo "Updating system packages..."
    apt-get update -y
}

# --- Begin Script Execution ---

check_sudo
check_internet_connection

# Parse config or display menu
if [ $# -eq 2 ] && [ "$1" == "--config-file" ]; then
    CONFIG_FILE="$2"
    parse_conf_config "$CONFIG_FILE"
    confirm_installation
else
    display_menu
fi

system_update_upgrade

# Install selected components
[ "${INSTALL_VIRTUALBOX:-no}" == "yes" ] && install_virtualbox
[ "${INSTALL_VAGRANT:-no}" == "yes" ] && install_vagrant
[ "${INSTALL_ZSH:-no}" == "yes" ] && install_zsh
[ "${INSTALL_VIM:-no}" == "yes" ] && install_vim
[ "${INSTALL_TMUX:-no}" == "yes" ] && install_tmux
[ "${INSTALL_DOCKER:-no}" == "yes" ] && install_docker
[ "${INSTALL_FLAMESHOT:-no}" == "yes" ] && install_flameshot
[ "${INSTALL_VARIETY:-no}" == "yes" ] && install_variety
[ "${INSTALL_GUAKE:-no}" == "yes" ] && install_guake && system_update
[ "${INSTALL_TERMINATOR:-no}" == "yes" ] && install_terminator
[ "${INSTALL_CHROMIUM:-no}" == "yes" ] && install_chromium
[ "${INSTALL_GNOME_TWEAKS:-no}" == "yes" ] && install_gnome_tweaks
[ "${INSTALL_SYNAPTIC:-no}" == "yes" ] && install_synaptic
[ "${INSTALL_VLC:-no}" == "yes" ] && install_vlc
[ "${INSTALL_GIMP:-no}" == "yes" ] && install_gimp
[ "${INSTALL_TIMESHIFT:-no}" == "yes" ] && install_timeshift
[ "${INSTALL_RDP:-no}" == "yes" ] && install_rdp
[ "${INSTALL_SSH_SERVER:-no}" == "yes" ] && install_ssh_server
[ "${INSTALL_FLATPAK:-no}" == "yes" ] && install_flatpak
[ "${INSTALL_SNAPS:-no}" == "yes" ] && install_snaps
[ "${INSTALL_BLEACHBIT:-no}" == "yes" ] && install_bleachbit
[ "${INSTALL_REDSHIFT:-no}" == "yes" ] && install_redshift
[ "${INSTALL_KEEPASSXC:-no}" == "yes" ] && install_keepassxc
[ "${INSTALL_HTOP:-no}" == "yes" ] && install_htop
[ "${INSTALL_GIT:-no}" == "yes" ] && install_git
[ "${INSTALL_NETWORK_TOOLS:-no}" == "yes" ] && install_network_tools
[ "${INSTALL_GPARTED:-no}" == "yes" ] && install_gparted

# Install additional fonts
install_fonts

echo "Setup completed successfully!"
