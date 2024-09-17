#!/bin/bash

# Enhanced Git Configuration and Software Installation Script
# This script sets up your global Git configuration and installs selected software tools.
# It supports both interactive and non-interactive modes with configuration options.
# Includes enhanced features like logging, dry-run mode, and more.

# -----------------------------
# Configuration Variables
# -----------------------------

# Default values (can be overridden by command-line options, config file, or environment variables)
GIT_NAME=""
GIT_EMAIL=""
GIT_EDITOR=""
ENABLE_COLOR_UI="yes"
CONFIGURE_LINE_ENDINGS="yes"
LINE_END_CHOICE=""
SET_PUSH_BEHAVIOR="yes"
SET_GIT_ALIASES="yes"
GIT_ALIASES=("co=checkout" "br=branch" "ci=commit" "st=status" "lg=log --oneline --graph --decorate --all")
SET_GLOBAL_GITIGNORE="yes"
GITIGNORE_PATH="$HOME/.gitignore_global"
SET_MERGE_TOOL="yes"
MERGE_TOOL_CHOICE=""
ENABLE_GPG_SIGNING="no"
GPG_KEY=""
OPTIMIZE_GIT_PERFORMANCE="yes"
SET_CREDENTIAL_HELPER="yes"
CREDENTIAL_HELPER_CHOICE=""
ENABLE_REBASE_AUTO_STASH="yes"
CUSTOMIZE_GIT_PAGER="yes"
SET_COMMIT_TEMPLATE="yes"
COMMIT_TEMPLATE_PATH="$HOME/.git_commit_template.txt"
NON_INTERACTIVE_MODE="no"
CONFIG_FILE=""
DRY_RUN_MODE="no"
ADDITIONAL_PACKAGES=()
LOG_FILE=""
FORCE_MODE="no"
GENERATE_SSH_KEY="no"
SSH_KEY_TYPE="rsa"
SSH_KEY_BITS="4096"
SSH_KEY_COMMENT=""
SSH_KEY_PASSPHRASE=""
PROXY_SETTINGS=""

# -----------------------------
# Function Definitions
# -----------------------------

# Function to display messages with colors and log them
function echo_info() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
    log_info "$1"
}

function echo_warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
    log_warning "$1"
}

function echo_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
    log_error "$1"
}

# Logging functions
function log_info() {
    [[ -n "$LOG_FILE" ]] && echo "[INFO] $1" >> "$LOG_FILE"
}

function log_warning() {
    [[ -n "$LOG_FILE" ]] && echo "[WARNING] $1" >> "$LOG_FILE"
}

function log_error() {
    [[ -n "$LOG_FILE" ]] && echo "[ERROR] $1" >> "$LOG_FILE"
}

# Function to backup existing gitconfig
function backup_gitconfig() {
    if [ -f "$HOME/.gitconfig" ]; then
        local backup_file="$HOME/.gitconfig.backup_$(date +%Y%m%d%H%M%S)"
        if [[ "$DRY_RUN_MODE" == "yes" ]]; then
            echo_info "Would backup existing .gitconfig to $backup_file"
        else
            cp "$HOME/.gitconfig" "$backup_file"
            echo_info "Existing .gitconfig backed up to $backup_file"
        fi
    fi
}

# Function to set Git configuration
function set_git_config() {
    local key=$1
    local value=$2
    if [[ "$DRY_RUN_MODE" == "yes" ]]; then
        echo_info "Would set $key to '$value'"
    else
        git config --global "$key" "$value"
        if [ $? -eq 0 ]; then
            echo_info "Set $key to '$value'"
        else
            echo_error "Failed to set $key"
        fi
    fi
}

# Function to prompt yes/no questions
function prompt_yes_no() {
    local prompt_message=$1
    local default_answer=$2
    local user_input

    if [[ "$NON_INTERACTIVE_MODE" == "yes" ]]; then
        echo "$default_answer"
        return
    fi

    while true; do
        read -p "$prompt_message (y/n): " user_input
        user_input=${user_input:-$default_answer}
        case "${user_input,,}" in
            y|yes ) echo "yes"; return;;
            n|no ) echo "no"; return;;
            * ) echo "Please answer yes (y) or no (n).";;
        esac
    done
}

# Function to detect OS and set package manager
function detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -x "$(command -v apt)" ]; then
            echo "apt"
        elif [ -x "$(command -v yum)" ]; then
            echo "yum"
        elif [ -x "$(command -v dnf)" ]; then
            echo "dnf"
        elif [ -x "$(command -v pacman)" ]; then
            echo "pacman"
        else
            echo "unknown"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        if [ -x "$(command -v brew)" ]; then
            echo "brew"
        else
            echo "unknown"
        fi
    elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]]; then
        if [ -x "$(command -v choco)" ]; then
            echo "choco"
        else
            echo "unknown"
        fi
    else
        echo "unknown"
    fi
}

# Function to check if a command exists
function command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install software with check
function install_software() {
    local pkg_manager=$1
    local package=$2
    local install_cmd

    # Check if the software is already installed
    if command_exists "$package"; then
        echo_info "$package is already installed. Skipping installation."
        return
    fi

    case "$pkg_manager" in
        apt)
            if [[ "$DRY_RUN_MODE" == "yes" ]]; then
                echo_info "Would run 'sudo apt-get update' and install $package"
            else
                sudo apt-get update
                install_cmd="sudo apt-get install -y $package"
            fi
            ;;
        yum)
            install_cmd="sudo yum install -y $package"
            ;;
        dnf)
            install_cmd="sudo dnf install -y $package"
            ;;
        pacman)
            install_cmd="sudo pacman -S --noconfirm $package"
            ;;
        brew)
            install_cmd="brew install $package"
            ;;
        choco)
            install_cmd="choco install -y $package"
            ;;
        *)
            echo_warning "Package manager '$pkg_manager' not supported. Please install '$package' manually."
            return
            ;;
    esac

    if [[ "$DRY_RUN_MODE" == "yes" ]]; then
        echo_info "Would install $package using $pkg_manager"
    else
        echo_info "Installing $package..."
        eval "$install_cmd"
        if [ $? -eq 0 ]; then
            echo_info "$package installed successfully."
        else
            echo_error "Failed to install $package. Please install it manually."
        fi
    fi
}

# Function to install VS Code on Debian/Ubuntu
function install_vscode_debian() {
    # Check if 'code' command exists after adding the repository
    if command_exists "code"; then
        echo_info "Visual Studio Code is already installed. Skipping installation."
        return
    fi

    if [[ "$DRY_RUN_MODE" == "yes" ]]; then
        echo_info "Would install Visual Studio Code on Debian/Ubuntu"
        return
    fi

    # Install dependencies
    sudo apt-get update
    sudo apt-get install -y software-properties-common apt-transport-https wget gnupg

    # Import the Microsoft GPG key
    wget -q https://packages.microsoft.com/keys/microsoft.asc -O- | sudo apt-key add -

    # Enable the Visual Studio Code repository
    sudo add-apt-repository "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main"

    # Update package lists
    sudo apt-get update

    # Install Visual Studio Code
    install_software "apt" "code"
}

# Function to parse command-line options
function parse_options() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name)
                GIT_NAME="$2"
                shift 2
                ;;
            --email)
                GIT_EMAIL="$2"
                shift 2
                ;;
            --editor)
                GIT_EDITOR="$2"
                shift 2
                ;;
            --no-color-ui)
                ENABLE_COLOR_UI="no"
                shift
                ;;
            --no-line-endings)
                CONFIGURE_LINE_ENDINGS="no"
                shift
                ;;
            --line-ending-choice)
                LINE_END_CHOICE="$2"
                shift 2
                ;;
            --no-push-behavior)
                SET_PUSH_BEHAVIOR="no"
                shift
                ;;
            --no-aliases)
                SET_GIT_ALIASES="no"
                shift
                ;;
            --aliases)
                IFS=',' read -ra GIT_ALIASES <<< "$2"
                shift 2
                ;;
            --no-gitignore)
                SET_GLOBAL_GITIGNORE="no"
                shift
                ;;
            --gitignore-path)
                GITIGNORE_PATH="$2"
                shift 2
                ;;
            --no-merge-tool)
                SET_MERGE_TOOL="no"
                shift
                ;;
            --merge-tool)
                MERGE_TOOL_CHOICE="$2"
                shift 2
                ;;
            --enable-gpg-signing)
                ENABLE_GPG_SIGNING="yes"
                shift
                ;;
            --gpg-key)
                GPG_KEY="$2"
                shift 2
                ;;
            --no-git-performance)
                OPTIMIZE_GIT_PERFORMANCE="no"
                shift
                ;;
            --no-credential-helper)
                SET_CREDENTIAL_HELPER="no"
                shift
                ;;
            --credential-helper)
                CREDENTIAL_HELPER_CHOICE="$2"
                shift 2
                ;;
            --no-rebase-auto-stash)
                ENABLE_REBASE_AUTO_STASH="no"
                shift
                ;;
            --no-custom-pager)
                CUSTOMIZE_GIT_PAGER="no"
                shift
                ;;
            --no-commit-template)
                SET_COMMIT_TEMPLATE="no"
                shift
                ;;
            --commit-template-path)
                COMMIT_TEMPLATE_PATH="$2"
                shift 2
                ;;
            --non-interactive)
                NON_INTERACTIVE_MODE="yes"
                shift
                ;;
            --config-file)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN_MODE="yes"
                shift
                ;;
            --log-file)
                LOG_FILE="$2"
                shift 2
                ;;
            --force)
                FORCE_MODE="yes"
                shift
                ;;
            --additional-packages)
                IFS=',' read -ra ADDITIONAL_PACKAGES <<< "$2"
                shift 2
                ;;
            --generate-ssh-key)
                GENERATE_SSH_KEY="yes"
                shift
                ;;
            --ssh-key-type)
                SSH_KEY_TYPE="$2"
                shift 2
                ;;
            --ssh-key-bits)
                SSH_KEY_BITS="$2"
                shift 2
                ;;
            --ssh-key-comment)
                SSH_KEY_COMMENT="$2"
                shift 2
                ;;
            --ssh-key-passphrase)
                SSH_KEY_PASSPHRASE="$2"
                shift 2
                ;;
            --proxy)
                PROXY_SETTINGS="$2"
                shift 2
                ;;
            -h|--help)
                display_help
                exit 0
                ;;
            *)
                echo_error "Unknown option: $1"
                display_help
                exit 1
                ;;
        esac
    done
}

# Function to display help message
function display_help() {
    cat <<EOL
Usage: $0 [OPTIONS]

Options:
  --name NAME                  Set Git user name.
  --email EMAIL                Set Git user email.
  --editor EDITOR              Set preferred Git editor (vim, nano, code, emacs, etc.).
  --no-color-ui                Disable colored Git output.
  --no-line-endings            Skip line ending configuration.
  --line-ending-choice CHOICE  Set line ending handling (windows, unix).
  --no-push-behavior           Do not set default push behavior.
  --no-aliases                 Do not set up Git aliases.
  --aliases ALIASES            Set custom Git aliases (e.g., co=checkout,br=branch).
  --no-gitignore               Do not set up global .gitignore.
  --gitignore-path PATH        Set path for global .gitignore file.
  --no-merge-tool              Do not set up a merge tool.
  --merge-tool TOOL            Set merge tool (meld, kdiff3, vimdiff, bc, etc.).
  --enable-gpg-signing         Enable GPG commit signing.
  --gpg-key KEY_ID             Set GPG key ID for signing commits.
  --no-git-performance         Do not optimize Git performance settings.
  --no-credential-helper       Do not set up a credential helper.
  --credential-helper HELPER   Set credential helper (cache, store, osxkeychain, wincred).
  --no-rebase-auto-stash       Do not enable automatic stashing during rebases.
  --no-custom-pager            Do not customize Git's pager settings.
  --no-commit-template         Do not set up a commit message template.
  --commit-template-path PATH  Set path for commit message template.
  --non-interactive            Run script in non-interactive mode.
  --config-file FILE           Use configuration options from a file.
  --dry-run                    Simulate actions without making changes.
  --log-file FILE              Log output to a specified file.
  --force                      Force actions without confirmation.
  --additional-packages PKGS   Install additional packages (comma-separated).
  --generate-ssh-key           Generate a new SSH key if none exists.
  --ssh-key-type TYPE          SSH key type (rsa, ed25519). Default: rsa
  --ssh-key-bits BITS          Number of bits for SSH key (e.g., 4096). Default: 4096
  --ssh-key-comment COMMENT    Comment for the SSH key.
  --ssh-key-passphrase PHRASE  Passphrase for the SSH key.
  --proxy PROXY_URL            Set proxy settings for network operations.
  -h, --help                   Display this help message.

EOL
}

# Function to load configuration from a file
function load_config_file() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        echo_info "Loaded configuration from $CONFIG_FILE"
    else
        echo_error "Configuration file $CONFIG_FILE not found."
        exit 1
    fi
}

# Function to check dependencies
function check_dependencies() {
    local dependencies=("git" "curl" "wget")
    local missing_dependencies=()

    for dep in "${dependencies[@]}"; do
        if ! command_exists "$dep"; then
            missing_dependencies+=("$dep")
        fi
    done

    if [ ${#missing_dependencies[@]} -ne 0 ]; then
        echo_error "Missing dependencies: ${missing_dependencies[*]}"
        echo_error "Please install the missing dependencies and re-run the script."
        exit 1
    fi
}

# Function to validate email
function validate_email() {
    local email=$1
    if [[ ! "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        echo_error "Invalid email address: $email"
        exit 1
    fi
}

# Function to generate SSH key
function generate_ssh_key() {
    if [[ -f "$HOME/.ssh/id_$SSH_KEY_TYPE" ]]; then
        echo_info "SSH key already exists. Skipping generation."
        return
    fi

    if [[ "$DRY_RUN_MODE" == "yes" ]]; then
        echo_info "Would generate SSH key of type $SSH_KEY_TYPE with $SSH_KEY_BITS bits."
        return
    fi

    mkdir -p "$HOME/.ssh"
    ssh-keygen -t "$SSH_KEY_TYPE" -b "$SSH_KEY_BITS" -C "$SSH_KEY_COMMENT" -N "$SSH_KEY_PASSPHRASE" -f "$HOME/.ssh/id_$SSH_KEY_TYPE"
    if [ $? -eq 0 ]; then
        echo_info "SSH key generated successfully."
    else
        echo_error "Failed to generate SSH key."
    fi
}

# -----------------------------
# Start of the Script
# -----------------------------

parse_options "$@"

if [[ "$CONFIG_FILE" != "" ]]; then
    load_config_file
fi

# Export proxy settings if provided
if [[ -n "$PROXY_SETTINGS" ]]; then
    export http_proxy="$PROXY_SETTINGS"
    export https_proxy="$PROXY_SETTINGS"
    echo_info "Proxy settings applied."
fi

# Initialize logging
if [[ -n "$LOG_FILE" ]]; then
    echo_info "Logging to $LOG_FILE"
    touch "$LOG_FILE"
fi

# Check for dependencies
check_dependencies

# Start message
echo_info "Starting Git configuration and software installation setup..."

# Detect Operating System and Package Manager
PACKAGE_MANAGER=$(detect_os)
if [[ "$PACKAGE_MANAGER" == "unknown" ]]; then
    echo_warning "Unsupported OS or package manager not found. Software installation may be skipped."
else
    echo_info "Detected package manager: $PACKAGE_MANAGER"
fi

# Backup existing .gitconfig
backup_gitconfig

# Set or prompt for Git user name
if [[ -z "$GIT_NAME" ]]; then
    if [[ "$NON_INTERACTIVE_MODE" == "yes" ]]; then
        echo_error "Git user name is required. Use --name option to set it."
        exit 1
    else
        read -p "Enter your Git user name: " GIT_NAME
        while [[ -z "$GIT_NAME" ]]; do
            echo_warning "User name cannot be empty."
            read -p "Enter your Git user name: " GIT_NAME
        done
    fi
fi

# Set or prompt for Git user email
if [[ -z "$GIT_EMAIL" ]]; then
    if [[ "$NON_INTERACTIVE_MODE" == "yes" ]]; then
        echo_error "Git user email is required. Use --email option to set it."
        exit 1
    else
        read -p "Enter your Git user email: " GIT_EMAIL
        while [[ -z "$GIT_EMAIL" ]]; do
            echo_warning "User email cannot be empty."
            read -p "Enter your Git user email: " GIT_EMAIL
        done
    fi
fi

# Validate email address
validate_email "$GIT_EMAIL"

# Set or prompt for default editor
if [[ -z "$GIT_EDITOR" ]]; then
    if [[ "$NON_INTERACTIVE_MODE" == "yes" ]]; then
        GIT_EDITOR="nano"
    else
        echo_info "Select your preferred Git editor:"
        echo "1) Vim"
        echo "2) Nano"
        echo "3) VS Code"
        echo "4) Emacs"
        echo "5) Other"
        read -p "Enter choice [1-5] (default: Nano): " editor_choice
        editor_choice=${editor_choice:-2}

        case "$editor_choice" in
            1)
                GIT_EDITOR="vim"
                ;;
            2)
                GIT_EDITOR="nano"
                ;;
            3)
                GIT_EDITOR="code --wait"
                ;;
            4)
                GIT_EDITOR="emacs"
                ;;
            5)
                read -p "Enter your preferred editor command: " GIT_EDITOR
                GIT_EDITOR=${GIT_EDITOR:-nano}
                ;;
            *)
                echo_warning "Invalid choice. Defaulting to nano."
                GIT_EDITOR="nano"
                ;;
        esac
    fi
fi

# Set global Git configurations
set_git_config "user.name" "$GIT_NAME"
set_git_config "user.email" "$GIT_EMAIL"
set_git_config "core.editor" "$GIT_EDITOR"

# Install Selected Editor
if [[ "$PACKAGE_MANAGER" != "unknown" ]]; then
    case "$GIT_EDITOR" in
        "vim")
            install_software "$PACKAGE_MANAGER" "vim"
            ;;
        "nano")
            install_software "$PACKAGE_MANAGER" "nano"
            ;;
        "code --wait")
            if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
                install_vscode_debian
            elif [[ "$PACKAGE_MANAGER" == "brew" ]]; then
                install_software "$PACKAGE_MANAGER" "visual-studio-code"
            elif [[ "$PACKAGE_MANAGER" == "choco" ]]; then
                install_software "$PACKAGE_MANAGER" "vscode"
            else
                echo_warning "Automatic installation for VS Code not configured for package manager '$PACKAGE_MANAGER'. Please install it manually."
            fi
            ;;
        "emacs")
            install_software "$PACKAGE_MANAGER" "emacs"
            ;;
        *)
            echo_info "Custom editor command selected. Skipping installation."
            ;;
    esac
fi

# Install additional packages
if [ ${#ADDITIONAL_PACKAGES[@]} -gt 0 ]; then
    for pkg in "${ADDITIONAL_PACKAGES[@]}"; do
        install_software "$PACKAGE_MANAGER" "$pkg"
    done
fi

# Enable colored output
if [[ "$ENABLE_COLOR_UI" == "yes" ]]; then
    set_git_config "color.ui" "auto"
fi

# Configure line endings
if [[ "$CONFIGURE_LINE_ENDINGS" == "yes" ]]; then
    if [[ -z "$LINE_END_CHOICE" ]]; then
        if [[ "$NON_INTERACTIVE_MODE" == "yes" ]]; then
            LINE_END_CHOICE="unix"
        else
            echo "Select your operating system for line ending settings:"
            echo "1) Windows (CRLF)"
            echo "2) macOS/Linux (LF)"
            read -p "Enter choice [1 or 2]: " line_end_choice
            case "$line_end_choice" in
                1)
                    LINE_END_CHOICE="windows"
                    ;;
                2)
                    LINE_END_CHOICE="unix"
                    ;;
                *)
                    echo_warning "Invalid choice. Skipping line ending configuration."
                    CONFIGURE_LINE_ENDINGS="no"
                    ;;
            esac
        fi
    fi

    if [[ "$LINE_END_CHOICE" == "windows" ]]; then
        set_git_config "core.autocrlf" "true"
    elif [[ "$LINE_END_CHOICE" == "unix" ]]; then
        set_git_config "core.autocrlf" "input"
    fi
fi

# Set default push behavior
if [[ "$SET_PUSH_BEHAVIOR" == "yes" ]]; then
    set_git_config "push.default" "simple"
fi

# Define Git aliases
if [[ "$SET_GIT_ALIASES" == "yes" ]]; then
    for alias in "${GIT_ALIASES[@]}"; do
        IFS='=' read -r alias_name alias_command <<< "$alias"
        set_git_config "alias.$alias_name" "$alias_command"
    done
fi

# Set a global .gitignore
if [[ "$SET_GLOBAL_GITIGNORE" == "yes" ]]; then
    if [ ! -f "$GITIGNORE_PATH" ]; then
        if [[ "$DRY_RUN_MODE" == "yes" ]]; then
            echo_info "Would create global .gitignore at $GITIGNORE_PATH"
        else
            touch "$GITIGNORE_PATH"
            echo_info "Created global .gitignore at $GITIGNORE_PATH"
            # Add some common ignore patterns
            cat <<EOL >> "$GITIGNORE_PATH"
# Commonly ignored files

# macOS
.DS_Store

# Windows
Thumbs.db

# Editor backups
*~
*.swp

# Node.js
node_modules/

# Python
__pycache__/
*.pyc

# Logs
logs/
*.log

# Others
.idea/
.vscode/
EOL
            echo_info "Added common ignore patterns to $GITIGNORE_PATH"
        fi
    else
        echo_info "Global .gitignore already exists at $GITIGNORE_PATH"
    fi
    set_git_config "core.excludesfile" "$GITIGNORE_PATH"
    echo_info "You can add additional patterns to $GITIGNORE_PATH to ignore files globally."
fi

# Configure default merge tool
if [[ "$SET_MERGE_TOOL" == "yes" ]]; then
    if [[ -z "$MERGE_TOOL_CHOICE" ]]; then
        if [[ "$NON_INTERACTIVE_MODE" == "yes" ]]; then
            MERGE_TOOL_CHOICE="vimdiff"
        else
            echo_info "Select your preferred merge tool:"
            echo "1) Meld"
            echo "2) KDiff3"
            echo "3) Vimdiff"
            echo "4) Beyond Compare"
            echo "5) Other"
            read -p "Enter choice [1-5]: " merge_choice
            case "$merge_choice" in
                1)
                    MERGE_TOOL_CHOICE="meld"
                    ;;
                2)
                    MERGE_TOOL_CHOICE="kdiff3"
                    ;;
                3)
                    MERGE_TOOL_CHOICE="vimdiff"
                    ;;
                4)
                    MERGE_TOOL_CHOICE="bc"  # Beyond Compare
                    ;;
                5)
                    read -p "Enter your preferred merge tool command: " MERGE_TOOL_CHOICE
                    MERGE_TOOL_CHOICE=${MERGE_TOOL_CHOICE:-"vimdiff"}
                    ;;
                *)
                    echo_warning "Invalid choice. Skipping merge tool configuration."
                    SET_MERGE_TOOL="no"
                    ;;
            esac
        fi
    fi

    if [[ "$SET_MERGE_TOOL" == "yes" ]]; then
        set_git_config "merge.tool" "$MERGE_TOOL_CHOICE"

        # Install the selected merge tool
        case "$MERGE_TOOL_CHOICE" in
            meld|kdiff3|vimdiff)
                if [[ "$PACKAGE_MANAGER" != "unknown" ]]; then
                    install_software "$PACKAGE_MANAGER" "$MERGE_TOOL_CHOICE"
                fi
                ;;
            bc)
                if [[ "$PACKAGE_MANAGER" != "unknown" ]]; then
                    if [[ "$PACKAGE_MANAGER" == "brew" ]]; then
                        install_software "$PACKAGE_MANAGER" "beyond-compare"
                    else
                        echo_warning "Automatic installation for Beyond Compare not configured for package manager '$PACKAGE_MANAGER'. Please install it manually."
                    fi
                fi
                ;;
            *)
                echo_warning "Automatic installation for $MERGE_TOOL_CHOICE not configured. Please install it manually."
                ;;
        esac
    fi
fi

# Enable commit signing
if [[ "$ENABLE_GPG_SIGNING" == "yes" ]]; then
    if command_exists "gpg" || command_exists "gpg2"; then
        if [[ -z "$GPG_KEY" ]]; then
            if [[ "$NON_INTERACTIVE_MODE" == "yes" ]]; then
                echo_error "GPG key ID is required. Use --gpg-key option to set it."
                exit 1
            else
                read -p "Enter your GPG key ID (or leave blank to skip): " GPG_KEY
            fi
        fi

        if [[ -n "$GPG_KEY" ]]; then
            set_git_config "user.signingkey" "$GPG_KEY"
            set_git_config "commit.gpgsign" "true"
            echo_info "Ensure that your GPG key is properly set up and associated with your GitHub/GitLab account."
        else
            echo_warning "GPG commit signing not configured."
        fi
    else
        echo_warning "GPG is not installed. Attempting to install GPG..."
        if [[ "$PACKAGE_MANAGER" != "unknown" ]]; then
            install_software "$PACKAGE_MANAGER" "gnupg"
            if command_exists "gpg" || command_exists "gpg2"; then
                if [[ -z "$GPG_KEY" ]]; then
                    if [[ "$NON_INTERACTIVE_MODE" == "yes" ]]; then
                        echo_error "GPG key ID is required. Use --gpg-key option to set it."
                        exit 1
                    else
                        read -p "Enter your GPG key ID (or leave blank to skip): " GPG_KEY
                    fi
                fi

                if [[ -n "$GPG_KEY" ]]; then
                    set_git_config "user.signingkey" "$GPG_KEY"
                    set_git_config "commit.gpgsign" "true"
                    echo_info "Ensure that your GPG key is properly set up and associated with your GitHub/GitLab account."
                else
                    echo_warning "GPG commit signing not configured."
                fi
            else
                echo_error "GPG installation failed. Skipping commit signing."
            fi
        else
            echo_warning "Package manager not available. Please install GPG manually."
        fi
    fi
fi

# Generate SSH key if requested
if [[ "$GENERATE_SSH_KEY" == "yes" ]]; then
    generate_ssh_key
fi

# Optimize Git performance
if [[ "$OPTIMIZE_GIT_PERFORMANCE" == "yes" ]]; then
    set_git_config "gc.auto" "256"
    set_git_config "core.compression" "9"
    set_git_config "pack.deltaCacheSize" "2047m"
    set_git_config "pack.packSizeLimit" "2g"
    set_git_config "pack.windowMemory" "300m"
fi

# Set up credential helper
if [[ "$SET_CREDENTIAL_HELPER" == "yes" ]]; then
    if [[ -z "$CREDENTIAL_HELPER_CHOICE" ]]; then
        if [[ "$NON_INTERACTIVE_MODE" == "yes" ]]; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                CREDENTIAL_HELPER_CHOICE="osxkeychain"
            elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
                CREDENTIAL_HELPER_CHOICE="cache"
            elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]]; then
                CREDENTIAL_HELPER_CHOICE="wincred"
            fi
        else
            echo "Available credential helpers:"
            echo "1) cache"
            echo "2) store"
            echo "3) osxkeychain (macOS)"
            echo "4) wincred (Windows)"
            echo "5) Other"
            read -p "Enter your preferred credential helper (e.g., cache, store, osxkeychain, wincred): " CREDENTIAL_HELPER_CHOICE
        fi
    fi

    if [[ -n "$CREDENTIAL_HELPER_CHOICE" ]]; then
        set_git_config "credential.helper" "$CREDENTIAL_HELPER_CHOICE"
        echo_info "Credential helper set to $CREDENTIAL_HELPER_CHOICE."
    else
        echo_warning "Credential helper not set."
    fi
fi

# Set up rebase auto stash
if [[ "$ENABLE_REBASE_AUTO_STASH" == "yes" ]]; then
    set_git_config "rebase.autoStash" "true"
fi

# Customize Git's pager
if [[ "$CUSTOMIZE_GIT_PAGER" == "yes" ]]; then
    set_git_config "core.pager" "less -FRX"
fi

# Optional: Set up commit template
if [[ "$SET_COMMIT_TEMPLATE" == "yes" ]]; then
    if [ ! -f "$COMMIT_TEMPLATE_PATH" ]; then
        if [[ "$DRY_RUN_MODE" == "yes" ]]; then
            echo_info "Would create commit template at $COMMIT_TEMPLATE_PATH"
        else
            touch "$COMMIT_TEMPLATE_PATH"
            echo_info "Created commit template at $COMMIT_TEMPLATE_PATH"
            # Add a basic template structure
            cat <<EOL >> "$COMMIT_TEMPLATE_PATH"
# Summary

# Description

# Related Issues
EOL
            echo_info "Added basic structure to commit template. You can customize it as needed."
        fi
    else
        echo_info "Commit template already exists at $COMMIT_TEMPLATE_PATH"
    fi
    set_git_config "commit.template" "$COMMIT_TEMPLATE_PATH"
fi

# Display final configuration
echo_info "Final Git configuration:"
git config --global --list

echo_info "Git configuration and software installation setup completed successfully!"

