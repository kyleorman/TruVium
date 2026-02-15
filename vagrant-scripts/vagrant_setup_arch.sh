#!/bin/bash

# Exit immediately if a command exits with a non-zero status,
# if any undefined variable is used, and if any command in a pipeline fails
set -eEuo pipefail
IFS=$'\n\t'

# --- Bash Progress Bar ---
# Colors for both interactive and non-interactive modes
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    INTERACTIVE=1
    BLUE="\033[34m"    # Simple blue color
    RESET="\033[0m"    # Reset
else
    INTERACTIVE=0
    BLUE=""
    RESET=""
fi

# Initialize progress bar position
init_progress_bar() {
    if [ "$INTERACTIVE" -eq 1 ]; then
        # Save cursor position and hide it
        echo -en "\033[s"
        echo -en "\033[?25l"
        PROGRESS_LINE=$(tput lines)
    fi
}

# Progress bar function
progress_bar_inline() {
    local current="$1"
    local total="$2"
    local width=50

    # Calculate percentage and bar segments
    local percent=$(( current * 100 / total ))
    local filled=$(( current * width / total ))
    local empty=$(( width - filled ))

    # Create the bar
    local bar_filled=$(printf "%${filled}s" | tr ' ' '#')
    local bar_empty=$(printf "%${empty}s" | tr ' ' '-')
    local bar="[${bar_filled}${bar_empty}] ${percent}%"

    if [ "$INTERACTIVE" -eq 1 ]; then
        # Save position, move to bottom, print bar, restore position
        echo -en "\033[s"
        echo -en "\033[${PROGRESS_LINE};0H"
        echo -en "\033[K"
        echo -en "${BLUE}${bar}${RESET}"
        echo -en "\033[u"
    else
        # Simple progress output for non-interactive mode
        echo "Progress: ${bar}"
    fi
}

# Log output function
log_line() {
    local msg="$1"
    
    if [ "$INTERACTIVE" -eq 1 ]; then
        # Save position, print message, restore position
        echo -en "\033[s"
        echo -e "$msg"
        echo -en "\033[u"
    else
        # Simple logging for non-interactive mode
        echo "==> $msg"
    fi
}

# Cleanup function
cleanup_progress_bar() {
    if [ "$INTERACTIVE" -eq 1 ]; then
        # Move cursor below progress bar and show it
        echo -en "\033[${PROGRESS_LINE}H\n"
        echo -en "\033[?25h"
    else
        # Just print a newline in non-interactive mode
        echo ""
    fi
}

# --- Configuration Variables ---
SCRIPT_DIR="/vagrant" # Adjust this if needed
LOGFILE="/var/log/setup-script.log"
TMP_DIR="/tmp/setup_script_install"
USER_CONFIG_DIR="$SCRIPT_DIR/user-config"
VAGRANT_SCRIPTS_DIR="$SCRIPT_DIR/vagrant-scripts"
VAGRANT_CONFIG_DIR="$SCRIPT_DIR/vagrant-config"

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

# Set vm.swappiness to 10 to reduce swap usage
# echo "vm.swappiness=10" | tee -a /etc/sysctl.conf
# sysctl -p

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

resize_disk() {
    log_line "Resizing root partition and filesystem when supported..."

    local ROOT_SOURCE ROOT_DEVICE FS_TYPE
    local ROOT_DISK_NAME ROOT_PARTNUM ROOT_DISK_PATH
    local GROWPART_OUTPUT GROWPART_STATUS=""

    ROOT_SOURCE=$(findmnt -n -o SOURCE / || true)
    ROOT_DEVICE=$(readlink -f "$ROOT_SOURCE" 2>/dev/null || printf '%s' "$ROOT_SOURCE")
    FS_TYPE=$(findmnt -n -o FSTYPE / || true)

    if [ -z "$ROOT_DEVICE" ] || [ ! -b "$ROOT_DEVICE" ]; then
        log_line "Skipping disk resize: root device is not a block device ($ROOT_SOURCE)."
        return 0
    fi

    # Try to determine parent disk + partition number from lsblk first
    ROOT_DISK_NAME=$(lsblk -no PKNAME "$ROOT_DEVICE" 2>/dev/null || true)
    ROOT_PARTNUM=$(lsblk -no PARTNUM "$ROOT_DEVICE" 2>/dev/null || true)

    if [ -n "$ROOT_DISK_NAME" ] && [ -n "$ROOT_PARTNUM" ]; then
        ROOT_DISK_PATH="/dev/$ROOT_DISK_NAME"
    elif [[ "$ROOT_DEVICE" =~ ^/dev/(nvme[0-9]+n[0-9]+|mmcblk[0-9]+)p([0-9]+)$ ]]; then
        ROOT_DISK_PATH="/dev/${BASH_REMATCH[1]}"
        ROOT_PARTNUM="${BASH_REMATCH[2]}"
    elif [[ "$ROOT_DEVICE" =~ ^(/dev/[[:alpha:]]+)([0-9]+)$ ]]; then
        ROOT_DISK_PATH="${BASH_REMATCH[1]}"
        ROOT_PARTNUM="${BASH_REMATCH[2]}"
    else
        log_line "Skipping disk resize: unable to infer partition layout for $ROOT_DEVICE."
        return 0
    fi

    # Ensure required tools are available
    pacman -S --noconfirm --needed cloud-guest-utils parted || {
        log_line "Failed to install cloud-guest-utils or parted."
        return 0
    }

    # Grow the root partition to fill available space
    log_line "Using growpart to resize $ROOT_DEVICE on $ROOT_DISK_PATH (partition $ROOT_PARTNUM)..."
    GROWPART_OUTPUT=$(growpart "$ROOT_DISK_PATH" "$ROOT_PARTNUM" 2>&1) || GROWPART_STATUS=$?

    if [[ -n "$GROWPART_STATUS" ]]; then
        if echo "$GROWPART_OUTPUT" | grep -q "NOCHANGE"; then
            log_line "No partition change required for $ROOT_DEVICE."
        else
            log_line "Warning: growpart failed for $ROOT_DEVICE."
            log_line "growpart output was: $GROWPART_OUTPUT"
        fi
    else
        log_line "growpart successfully resized $ROOT_DEVICE."
    fi

    # Grow filesystem to match partition size
    case "$FS_TYPE" in
        btrfs)
            if ! command -v btrfs >/dev/null 2>&1; then
                pacman -S --noconfirm --needed btrfs-progs || true
            fi
            if ! btrfs filesystem resize max /; then
                log_line "Warning: Btrfs filesystem resize failed on /."
                return 0
            fi
            ;;
        ext2|ext3|ext4)
            if ! command -v resize2fs >/dev/null 2>&1; then
                pacman -S --noconfirm --needed e2fsprogs || true
            fi
            if ! resize2fs "$ROOT_DEVICE"; then
                log_line "Warning: resize2fs failed on $ROOT_DEVICE."
                return 0
            fi
            ;;
        *)
            log_line "Skipping filesystem resize: unsupported filesystem type '$FS_TYPE'."
            return 0
            ;;
    esac

    log_line "Root resize step completed for $ROOT_DEVICE ($FS_TYPE)."
}

# Function to enable parallel downloads in pacman.conf and parallel builds in makepkg.conf
enable_parallel_builds() {
  echo "Enabling parallel downloads in pacman.conf..."

  PACMAN_CONF="/etc/pacman.conf"
  MAKEPKG_CONF="/etc/makepkg.conf"

  # Backup the original pacman.conf if not already backed up
  if [ ! -f "${PACMAN_CONF}.bak" ]; then
    cp "$PACMAN_CONF" "${PACMAN_CONF}.bak"
    echo "Backup of pacman.conf created at ${PACMAN_CONF}.bak"
  fi

  # Enable ILoveCandy and ParallelDownloads = 5 (or any value you prefer)
  # (Comment out any existing ParallelDownloads and add your own)
  sed -i 's/^#\(Color\)$/\1/' "$PACMAN_CONF"
  sed -i 's/^#\(ILoveCandy\)$/\1/' "$PACMAN_CONF"
  if grep -q '^#ParallelDownloads' "$PACMAN_CONF"; then
    sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 5/' "$PACMAN_CONF"
  elif ! grep -q '^ParallelDownloads' "$PACMAN_CONF"; then
    # If ParallelDownloads doesn't exist at all, add it
    echo "ParallelDownloads = 5" >> "$PACMAN_CONF"
  fi

  echo "Enabling parallel builds in makepkg.conf..."

  # Backup the original makepkg.conf if not already backed up
  if [ ! -f "${MAKEPKG_CONF}.bak" ]; then
    cp "$MAKEPKG_CONF" "${MAKEPKG_CONF}.bak"
    echo "Backup of makepkg.conf created at ${MAKEPKG_CONF}.bak"
  fi

  # Replace existing MAKEFLAGS line or append if not found
  # This uses all available cores: -j$(nproc)
  if grep -q '^#MAKEFLAGS=' "$MAKEPKG_CONF"; then
    sed -i "s|^#MAKEFLAGS=.*|MAKEFLAGS=\"-j$(nproc)\"|" "$MAKEPKG_CONF"
  elif grep -q '^MAKEFLAGS=' "$MAKEPKG_CONF"; then
    sed -i "s|^MAKEFLAGS=.*|MAKEFLAGS=\"-j$(nproc)\"|" "$MAKEPKG_CONF"
  else
    echo "MAKEFLAGS=\"-j$(nproc)\"" >> "$MAKEPKG_CONF"
  fi

  # (Optionally) you can also speed up compression by enabling more threads
  if grep -q '^COMPRESSXZ' "$MAKEPKG_CONF"; then
    sed -i "s|^COMPRESSXZ=.*|COMPRESSXZ=(xz -c -T $(nproc) -z -)|" "$MAKEPKG_CONF"
  fi

  echo "Parallel downloads and builds have been enabled."
}

# Function to install essential packages
install_dependencies() {
  echo "Installing essential packages..."

  # Combined pacman installation
  pacman -Syu --noconfirm

  # Preselect common virtual providers to keep installs non-interactive
  pacman -S --noconfirm --needed qt6-multimedia-ffmpeg jack2 || {
    echo "Warning: Failed to preinstall multimedia/audio providers; continuing."
  }

  pacman -S --noconfirm --needed \
    base-devel \
    git \
    zsh \
    wget \
    curl \
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
    bat \
    eza \
    zoxide \
    btop \
    thefuck \
    p7zip \
    jq \
    poppler \
    imagemagick \
    task \
    taskwarrior-tui \
    timew \
    lazygit \
    yazi \
    kitty \
    fish \
    nushell \
    bazel \
    lazydocker \
    ttf-firacode-nerd \
    ttf-hack-nerd \
    ttf-jetbrains-mono-nerd \
    ttf-meslo-nerd \
    doxygen \
    tk \
    eigen \
    yosys \
    klayout \
    emacs \
    go ||
    {
      echo "Package installation failed"
      exit 1
    }

  # gvim conflicts with vim/vim-minimal on some Arch base boxes.
  # Keep it optional so provisioning can continue.
  if pacman -Qi vim >/dev/null 2>&1; then
    echo "Skipping gvim install because vim is already present and conflicts with gvim."
  else
    pacman -S --noconfirm --needed gvim || {
      echo "Warning: Optional package gvim failed to install; continuing."
    }
  fi
}

# Function to install AUR packages with retry mechanism
install_aur_packages() {
  echo "Installing AUR packages..."

  install_yay() {
    local retry=3

    if su - "$ACTUAL_USER" -c "command -v yay >/dev/null 2>&1"; then
      return 0
    fi

    # Prefer official repo package when available.
    if pacman -S --noconfirm --needed yay >/dev/null 2>&1; then
      return 0
    fi

    while [ "$retry" -gt 0 ]; do
      su - "$ACTUAL_USER" -c "rm -rf $TMP_DIR/yay"
      if su - "$ACTUAL_USER" -c "git clone https://aur.archlinux.org/yay.git $TMP_DIR/yay && cd $TMP_DIR/yay && GODEBUG=netdns=cgo makepkg -si --noconfirm"; then
        return 0
      fi

      retry=$((retry - 1))
      if [ "$retry" -gt 0 ]; then
        echo "Retrying yay bootstrap... ($retry attempts left)"
        sleep 2
      fi
    done

    echo "WARNING: Unable to install yay. Skipping AUR package installation."
    return 1
  }

  if ! install_yay; then
    return 0
  fi

  install_ghdl_with_fallback() {
    local retry=3

    while [ "$retry" -gt 0 ]; do
      su - "$ACTUAL_USER" -c "rm -rf ~/.cache/yay/ghdl"
      if su - "$ACTUAL_USER" -c 'yay -S --noconfirm --needed --answerclean All --cleanbuild --mflags "--nocheck" ghdl'; then
        return 0
      fi
      retry=$((retry - 1))
      if [ "$retry" -gt 0 ]; then
        echo "Retrying installation of ghdl... ($retry attempts left)"
        sleep 2
      fi
    done

    echo "Falling back to ghdl-gcc after ghdl failures..."
    retry=2
    while [ "$retry" -gt 0 ]; do
      su - "$ACTUAL_USER" -c "rm -rf ~/.cache/yay/ghdl-gcc"
      if su - "$ACTUAL_USER" -c 'yay -S --noconfirm --needed --answerclean All --cleanbuild --mflags "--nocheck" ghdl-gcc'; then
        return 0
      fi
      retry=$((retry - 1))
      if [ "$retry" -gt 0 ]; then
        echo "Retrying installation of ghdl-gcc... ($retry attempts left)"
        sleep 2
      fi
    done

    echo "WARNING: Unable to install ghdl or ghdl-gcc from AUR. Continuing without GHDL."
    return 0
  }

  # Define AUR packages to install
  AUR_PACKAGES=(
    perl-language-server
    ghdl
    gtkwave
    texlab
    verilator
    iverilog
    verible
    # lemminx # optional XML language server
    # emacs-nativecomp # disabled due build failures
    falkon
    globalprotect-openconnect-git
    figlet
    boxes
    lolcat
    fortune-mod
    fortune-mod-wisdom-fr
    fortune-mod-hitchhiker
    tlrc
    broot
    lazysql
    jupyterlab-catppuccin
    viu
    visual-studio-code-bin
    kicad
    tcllib
    # termscp # currently omitted due package source churn
    # cudd # currently omitted due package source churn
    # openroad-git # resource-intensive and disabled by default
    # ffmpeg # optional
  )

  # Install each AUR package with retries
  for package in "${AUR_PACKAGES[@]}"; do
    if [ "$package" = "ghdl" ]; then
      install_ghdl_with_fallback
      continue
    fi

    retry=3
    until su - "$ACTUAL_USER" -c "yay -S --noconfirm --needed $package"; do
      retry=$((retry - 1))
      if [ "$retry" -le 0 ]; then
        echo "WARNING: Failed to install AUR package: $package after multiple attempts. Continuing."
        break
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
      while ((retry > 0)); do
        if su - "$ACTUAL_USER" -c "yay -S --noconfirm --needed $package"; then
          echo "Successfully installed '$package' via yay."
          return 0
        else
          echo "Failed to install '$package' via yay. Retries left: $((retry - 1))"
          retry=$((retry - 1))
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

# Install OpenROAD (Require more RAM and Storage)
install_openroad_from_source() {
  echo "Installing OpenROAD from source..."

  # 1) Update system and install essential packages from official repos
  echo "Installing required Arch Linux packages..."
  pacman -Syy --noconfirm
  pacman -S --noconfirm --needed \
    base-devel git cmake tcl tk python python-pip clang llvm boost eigen \
    zlib libffi flex bison swig libx11 mesa glew qt5-base qt5-svg qt5-x11extras \
    ttf-liberation ttf-dejavu coin-or-lemon doxygen || {
      echo "Failed to install some required packages from official repos."
      exit 1
    }

  # 2) Install AUR dependencies using yay
  echo "Installing AUR dependencies..."
  su - "$ACTUAL_USER" -c "yay -S --noconfirm --needed or-tools tclreadline" || {
    echo "Failed to install AUR dependencies."
    exit 1
  }

  # 3) Create build directory with proper permissions
  BUILD_DIR="/tmp/openroad_build"
  rm -rf "$BUILD_DIR"  # Clean up any previous failed attempts
  mkdir -p "$BUILD_DIR"
  chmod 777 "$BUILD_DIR"  # Give full permissions to ensure write access
  chown -R "$ACTUAL_USER:$ACTUAL_USER" "$BUILD_DIR"

  # 4) Configure git to handle large files and line endings
  su - "$ACTUAL_USER" -c "git config --global core.autocrlf false"
  su - "$ACTUAL_USER" -c "git config --global core.longpaths true"

  # 5) Clone and build as the actual user with specific git options
  echo "Building OpenROAD as user $ACTUAL_USER..."
  su - "$ACTUAL_USER" -c "
    set -e
    cd '$BUILD_DIR'
    
    # Clone with specific options to handle permissions
    git clone --recursive https://github.com/The-OpenROAD-Project/OpenROAD.git \
      --config core.autocrlf=false \
      --config core.fileMode=false \
      --config core.ignorecase=false

    cd OpenROAD

    # Ensure write permissions for the repository
    chmod -R u+w .

    # Configure build without tests to avoid permission issues
    mkdir -p build
    cd build
    
  cmake .. \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TESTS=OFF \
    -DUSE_SYSTEM_BOOST=ON \
    -DBUILD_GUI=ON
    
    # Build using all available cores
    make -j\$(nproc)
  " || {
    echo "Failed during OpenROAD build process"
    exit 1
  }

  # 6) Install as root (required for /usr/local)
  echo "Installing OpenROAD to system directories..."
  cd "$BUILD_DIR/OpenROAD/build" || exit 1
  make install || {
    echo "Installation failed"
    exit 1
  }

  # 7) Configure library paths
  echo "/usr/local/lib" > /etc/ld.so.conf.d/openroad.conf
  ldconfig

  # 8) Verify installation
  if command -v openroad &>/dev/null; then
    # Test basic OpenROAD functionality
    su - "$ACTUAL_USER" -c "openroad -version" || {
      echo "OpenROAD installation verification failed"
      exit 1
    }
    echo "OpenROAD installed successfully"
  else
    echo "OpenROAD installation verification failed"
    exit 1
  fi

  # 9) Clean up build directory
  # echo "Cleaning up build directory..."
  # rm -rf "$BUILD_DIR"
}

# Install Verible
install_verible_from_source() {
  echo "Installing Verible from source..."

  # Ensure the temporary directory exists
  mkdir -p "$TMP_DIR"
  cd "$TMP_DIR" || {
    echo "Failed to access temporary directory $TMP_DIR"
    exit 1
  }

  # Install Verible dependencies
  echo "Installing Verible dependencies..."
  pacman -S --noconfirm --needed git autoconf flex bison gcc make libtool curl || {
    echo "Failed to install dependencies"
    exit 1
  }

  # Clone Verible repository
  echo "Cloning Verible repository..."
  git clone https://github.com/chipsalliance/verible.git /tmp/verible || {
    echo "Failed to clone Verible repository"
    exit 1
  }
  cd /tmp/verible || {
    echo "Failed to navigate to Verible directory"
    exit 1
  }

  # Build Verible using Bazel
  echo "Building Verible..."
  bazel build //... || {
    echo "Failed to build Verible"
    exit 1
  }

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

install_broot() {
  echo "Installing broot shell integration..."

  if ! command -v broot &>/dev/null; then
    echo "broot not found; attempting to install from pacman..."
    if ! pacman -S --noconfirm --needed broot; then
      echo "WARNING: Failed to install broot package. Skipping shell integration."
      return 0
    fi
  fi

  # Install the shell function integration
  if ! su - "$ACTUAL_USER" -c "broot --install"; then
    echo "WARNING: Failed to run broot shell integration. Continuing."
    return 0
  fi

  echo "broot shell integration installed successfully."
}

# Function to install Go tools
install_go_tools() {
  echo "Installing Go tools..."

  # Check if Go is installed
  if ! command -v go &>/dev/null; then
    echo "Error: Go is not installed. Please ensure Go is installed before running this function."
    exit 1
  fi

  # Install Go tools
  TOOLS=(
    "golang.org/x/tools/gopls@latest"                  # Go language server
    "github.com/mrtazz/checkmake/cmd/checkmake@latest" # CheckMake
    "github.com/DerTimonius/twkb@latest"               # TWKB
  )

  install_go_tool_with_fallbacks() {
    local tool="$1"

    # Normal install path first
    if su - "$ACTUAL_USER" -c "go install $tool"; then
      return 0
    fi

    # Some boxes fail with Go's default DNS resolver; try libc resolver
    if su - "$ACTUAL_USER" -c "GODEBUG=netdns=cgo go install $tool"; then
      return 0
    fi

    # Final fallback: bypass module proxy and use libc DNS resolver
    if su - "$ACTUAL_USER" -c "GODEBUG=netdns=cgo GOPROXY=direct go install $tool"; then
      return 0
    fi

    # Last resort for restricted DNS environments: skip checksum DB lookup
    if su - "$ACTUAL_USER" -c "GODEBUG=netdns=cgo GOPROXY=direct GOSUMDB=off go install $tool"; then
      return 0
    fi

    return 1
  }

  local failed_tools=()
  for tool in "${TOOLS[@]}"; do
    echo "Installing $tool..."
    if ! install_go_tool_with_fallbacks "$tool"; then
      echo "WARNING: Failed to install $tool. Continuing."
      failed_tools+=("$tool")
    fi
  done

  if [ "${#failed_tools[@]}" -gt 0 ]; then
    echo "WARNING: Some Go tools failed to install: ${failed_tools[*]}"
  else
    echo "Go tools installed successfully."
  fi
}

# Function to install Tmux Plugin Manager and tmux plugins
install_tpm() {
  echo "Installing Tmux Plugin Manager (TPM) and tmux plugins..."
  TPM_DIR="$USER_HOME/.tmux/plugins/tpm"

  if [ ! -d "$TPM_DIR" ]; then
    su - "$ACTUAL_USER" -c "git clone https://github.com/tmux-plugins/tpm '$TPM_DIR'" || {
      echo "WARNING: Failed to clone TPM. Skipping tmux plugin installation."
      return 0
    }
  else
    echo "TPM is already installed."
  fi

  # Initialize TPM in .tmux.conf if not already present
  if [ ! -f "$USER_HOME/.tmux.conf" ]; then
    touch "$USER_HOME/.tmux.conf"
    chown "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME/.tmux.conf"
  fi

  # Some tmux configs reference $TMUX_PLUGIN_MANAGER_PATH directly.
  # Define it explicitly to avoid "unknown variable" failures.
  if ! grep -q "TMUX_PLUGIN_MANAGER_PATH" "$USER_HOME/.tmux.conf"; then
    echo "set-environment -g TMUX_PLUGIN_MANAGER_PATH '$USER_HOME/.tmux/plugins/tpm'" >>"$USER_HOME/.tmux.conf"
  fi

  if ! grep -q "run -b '~/.tmux/plugins/tpm/tpm'" "$USER_HOME/.tmux.conf"; then
    echo "run -b '~/.tmux/plugins/tpm/tpm'" >>"$USER_HOME/.tmux.conf"
  fi

  # Install tmux plugins
  if ! su - "$ACTUAL_USER" -c "TMUX_PLUGIN_MANAGER_PATH='$TPM_DIR' tmux start-server && tmux new-session -d && tmux set-environment -g TMUX_PLUGIN_MANAGER_PATH '$TPM_DIR' && ~/.tmux/plugins/tpm/bin/install_plugins && tmux kill-server"; then
    echo "WARNING: Failed to install tmux plugins. Continuing."
    su - "$ACTUAL_USER" -c "tmux kill-server || true"
    return 0
  fi
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
    # "vim-syntastic/syntastic" # archived; ALE is used instead
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
    "kyleorman/vim-themer"
  )

  OPTIONAL_PLUGINS=(
    "klen/python-mode"
    "suoto/hdl_checker"
    "vim-perl/vim-perl"
    "octol/vim-cpp-enhanced-highlight"
    # "nsf/gocode" # deprecated; gopls is installed by install_go_tools
    "daeyun/vim-matlab"
  )

  COLOR_SCHEMES=(
    "altercation/vim-colors-solarized"
    "rafi/awesome-vim-colorschemes"
	"catppuccin/vim"
	"ywjno/vim-tomorrow-theme"
	"ayu-theme/ayu-vim"
	"ghifarit53/tokyonight-vim"
	#"chriskempson/base16-vim"
	"tinted-theming/tinted-vim"
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

  setup_ftdetect_symlinks
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
    if ! su - "$ACTUAL_USER" -c "git clone --depth=1 https://github.com/$repo.git $target_dir"; then
      echo "WARNING: Failed to clone '$repo' into '$target_dir'. Continuing."
      return 0
    fi
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
        ln -s "$src_file" "$dest_file" &&
          echo "Created symlink: $dest_file -> $src_file" ||
          echo "Failed to create symlink for $filename"
      fi
    done
  else
    echo "No ftdetect files found in $FTDETECT_SRC_DIR. Skipping symlink creation."
  fi
}

# Function to clone the fzf-git.sh repository
clone_fzf_git_repo() {
  echo "Cloning fzf-git.sh repository to the home directory..."

  # Define repository details
  FZF_GIT_REPO="https://github.com/junegunn/fzf-git.sh.git"
  TARGET_DIR="$USER_HOME/fzf-git.sh"

  # Check if the target directory already exists
  if [ -d "$TARGET_DIR" ]; then
    echo "The fzf-git.sh repository already exists at $TARGET_DIR. Skipping clone."
    return 0
  fi

  # Clone the repository
  su - "$ACTUAL_USER" -c "git clone --depth=1 $FZF_GIT_REPO $TARGET_DIR" || {
    echo "Error: Failed to clone fzf-git.sh repository."
    exit 1
  }

  echo "Successfully cloned fzf-git.sh repository to $TARGET_DIR."
}

# Function to install Oh My Zsh
install_oh_my_zsh() {
  echo "Installing Oh My Zsh..."
  su - "$ACTUAL_USER" -c "sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" --unattended" || {
    echo "Failed to install Oh My Zsh."
    exit 1
  }
}

# Function to install and configure Starship prompt and Zsh plugins
install_starship() {
  echo "Installing Starship prompt and configuring it for the actual user..."

  # Install Starship as the actual user
  if ! su - "$ACTUAL_USER" -c "command -v starship &>/dev/null"; then
    echo "Installing Starship..."
    su - "$ACTUAL_USER" -c "curl -sS https://starship.rs/install.sh | sh -s -- --yes" || {
      echo "Failed to install Starship."
      exit 1
    }
  else
    echo "Starship is already installed."
  fi

  # Configure Starship
  STARSHIP_CONFIG_DIR="$USER_HOME/.config"
  STARSHIP_CONFIG_FILE="$STARSHIP_CONFIG_DIR/starship.toml"

  su - "$ACTUAL_USER" -c "mkdir -p $STARSHIP_CONFIG_DIR"

  if [ ! -f "$STARSHIP_CONFIG_FILE" ]; then
    echo "Creating Starship configuration file..."
    su - "$ACTUAL_USER" -c "cat <<EOF > $STARSHIP_CONFIG_FILE
[character]
success_symbol = '[➜](bold green)'
error_symbol = '[✗](bold red)'

[git_branch]
symbol = ' '

[package]
symbol = '📦 '
EOF"
  else
    echo "Starship configuration file already exists. Skipping creation."
  fi

  # Ensure Starship is initialized in the user's shell configuration
  SHELL_RC="$USER_HOME/.zshrc" # Adjust for other shells as needed
  if [ ! -f "$SHELL_RC" ]; then
    touch "$SHELL_RC"
    chown "$ACTUAL_USER:$ACTUAL_USER" "$SHELL_RC"
  fi
  if ! grep -q 'eval "$(starship init zsh)"' "$SHELL_RC"; then
    echo 'eval "$(starship init zsh)"' >>"$SHELL_RC"
  fi

  echo "Starship prompt installed and configured successfully."
}

install_oh_my_posh() {
  echo "Installing Oh My Posh..."

  # Check if Oh My Posh is already installed
  if su - "$ACTUAL_USER" -c "command -v oh-my-posh &>/dev/null"; then
    echo "Oh My Posh is already installed. Skipping installation."
    return
  fi

  # Download and install Oh My Posh as the actual user
  su - "$ACTUAL_USER" -c "curl -s https://ohmyposh.dev/install.sh | bash -s" || {
    echo "Failed to install Oh My Posh."
    exit 1
  }

  echo "Oh My Posh installation complete."
}

install_powerlevel10k() {
  echo "Installing Powerlevel10k..."

  P10K_DIR="$USER_HOME/.oh-my-zsh/custom/themes/powerlevel10k"

  if [ ! -d "$P10K_DIR" ]; then
    echo "Cloning Powerlevel10k repository..."
    su - "$ACTUAL_USER" -c "git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $P10K_DIR" || {
      echo "Failed to clone Powerlevel10k."
      exit 1
    }
  else
    echo "Powerlevel10k is already installed."
  fi

  echo "Powerlevel10k installation complete."
}

install_spaceship() {
  echo "Installing Spaceship Prompt..."

  SPACESHIP_DIR="$USER_HOME/.oh-my-zsh/custom/themes/spaceship-prompt"

  if [ ! -d "$SPACESHIP_DIR" ]; then
    echo "Cloning Spaceship Prompt repository..."
    su - "$ACTUAL_USER" -c "git clone --depth=1 https://github.com/spaceship-prompt/spaceship-prompt.git $SPACESHIP_DIR" || {
      echo "Failed to clone Spaceship Prompt."
      exit 1
    }
    su - "$ACTUAL_USER" -c "ln -sf $SPACESHIP_DIR/spaceship.zsh-theme $SPACESHIP_DIR/../spaceship.zsh-theme" || {
      echo "Failed to create Spaceship theme symlink."
      exit 1
    }
  else
    echo "Spaceship Prompt is already installed."
  fi

  echo "Spaceship Prompt installation complete."
}

install_zsh_plugins() {
  echo "Installing Zsh plugins..."

  # Define the directories for plugin installation
  OH_MY_ZSH_PLUGIN_DIR="$USER_HOME/.oh-my-zsh/custom/plugins"
  ZSH_PLUGIN_DIR="$USER_HOME/.zsh/plugins"

  # Ensure both plugin directories exist
  su - "$ACTUAL_USER" -c "mkdir -p '$OH_MY_ZSH_PLUGIN_DIR'"
  su - "$ACTUAL_USER" -c "mkdir -p '$ZSH_PLUGIN_DIR'"

  # List of plugins to install
  ZSH_PLUGINS=(
    "zsh-users/zsh-syntax-highlighting"
    "zsh-users/zsh-autosuggestions"
    "zsh-users/zsh-completions"
  )

  clone_zsh_plugin_with_retry() {
    local plugin_repo="$1"
    local target_dir="$2"
    local context="$3"
    local retry=3

    while [ "$retry" -gt 0 ]; do
      if su - "$ACTUAL_USER" -c "git clone --depth=1 https://github.com/$plugin_repo.git '$target_dir'"; then
        return 0
      fi

      retry=$((retry - 1))
      if [ "$retry" -gt 0 ]; then
        echo "Retrying plugin clone for '$plugin_repo' in $context... ($retry attempts left)"
        sleep 2
      fi
    done

    echo "WARNING: Failed to install plugin '$plugin_repo' to $context. Continuing."
    return 1
  }

  local failed_plugins=()

  # Install each plugin into both directories
  for plugin in "${ZSH_PLUGINS[@]}"; do
    local plugin_name
    plugin_name=$(basename "$plugin")
    local oh_my_zsh_target="$OH_MY_ZSH_PLUGIN_DIR/$plugin_name"
    local zsh_target="$ZSH_PLUGIN_DIR/$plugin_name"

    # Install into .oh-my-zsh/custom/plugins
    if [ -d "$oh_my_zsh_target" ]; then
      echo "Plugin '$plugin_name' already installed in .oh-my-zsh/custom/plugins. Skipping."
    else
      echo "Installing plugin '$plugin_name' into .oh-my-zsh/custom/plugins..."
      if ! clone_zsh_plugin_with_retry "$plugin" "$oh_my_zsh_target" ".oh-my-zsh/custom/plugins"; then
        failed_plugins+=("$plugin_name (.oh-my-zsh/custom/plugins)")
      fi
    fi

    # Install into .zsh/plugins
    if [ -d "$zsh_target" ]; then
      echo "Plugin '$plugin_name' already installed in .zsh/plugins. Skipping."
    else
      echo "Installing plugin '$plugin_name' into .zsh/plugins..."
      if ! clone_zsh_plugin_with_retry "$plugin" "$zsh_target" ".zsh/plugins"; then
        failed_plugins+=("$plugin_name (.zsh/plugins)")
      fi
    fi
  done

  if [ "${#failed_plugins[@]}" -gt 0 ]; then
    echo "WARNING: Some Zsh plugin installs failed: ${failed_plugins[*]}"
  else
    echo "Zsh plugins installed successfully in both directories."
  fi
}


# Function to install coc.nvim dependencies
install_coc_dependencies() {
  echo "Installing coc.nvim dependencies..."

  local coc_dir="$USER_HOME/.vim/pack/plugins/start/coc.nvim"
  if [ ! -d "$coc_dir" ]; then
    echo "WARNING: coc.nvim plugin directory not found at $coc_dir. Skipping dependency install."
    return 0
  fi

  if ! su - "$ACTUAL_USER" -c "cd '$coc_dir' && npm install"; then
    echo "WARNING: Failed to install coc.nvim dependencies. Continuing."
    return 0
  fi

  echo "coc.nvim dependencies installed successfully."
}

# Function to copy configuration files and directories
copy_config_files() {
  echo "Copying configuration files and directories..."

  # Files to copy directly to the home directory
  DOT_FILES=(
    "vimrc"
    "tmux.conf"
    #"tmux_keys.sh"
    "tmuxline.conf"
  )

  # Files to copy to the .vim directory
  VIM_FILES=(
    "coc-settings.json"
    "hdl_checker.json"
    "airline_theme.conf"
  )

  # Files and directories to copy to the .config directory
  CONFIG_ITEMS=(
	"vim-themer"
	"bat"
	"yazi"
	"lazygit"
	"btop"
	"timewarrior"
	"taskwarrior"
    "tmux-sessionizer.conf"
	"truvium"
	"tmux_keys.sh"
  )

  # Copy dot-prefixed files to the home directory
  for file in "${DOT_FILES[@]}"; do
    src="$USER_CONFIG_DIR/$file"
    dest="$USER_HOME/.$file" # Prepend a dot for these files
    if [ -f "$src" ]; then
      # Backup if exists
      [ -f "$dest" ] && cp "$dest" "$dest.bak" && echo "Backup of $dest created."
      cp "$src" "$dest"
      chown "$ACTUAL_USER:$ACTUAL_USER" "$dest"
      echo "Copied $file to $dest."
    else
      echo "$file not found in $src."
    fi
  done

  # Ensure .vim directory exists
  if [ ! -d "$USER_HOME/.vim" ]; then
    mkdir -p "$USER_HOME/.vim"
    chown "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME/.vim"
    echo "Created .vim directory."
  fi

  # Copy files to the .vim directory
  for file in "${VIM_FILES[@]}"; do
    src="$USER_CONFIG_DIR/$file"
    dest="$USER_HOME/.vim/$file"
    if [ -f "$src" ]; then
      # Backup if exists
      [ -f "$dest" ] && cp "$dest" "$dest.bak" && echo "Backup of $dest created."
      cp "$src" "$dest"
      chown "$ACTUAL_USER:$ACTUAL_USER" "$dest"
      echo "Copied $file to $dest."
    else
      echo "$file not found in $src."
    fi
  done

  # Ensure .config directory exists
  CONFIG_DIR="$USER_HOME/.config"
  if [ ! -d "$CONFIG_DIR" ]; then
    mkdir -p "$CONFIG_DIR"
    chown "$ACTUAL_USER:$ACTUAL_USER" "$CONFIG_DIR"
    echo "Created .config directory."
  fi

  # Copy files and directories to .config
  for item in "${CONFIG_ITEMS[@]}"; do
    src="$USER_CONFIG_DIR/$item"
    dest="$CONFIG_DIR/$item"
    if [ -d "$src" ]; then
      # Backup if exists
      if [ -d "$dest" ]; then
        mv "$dest" "$dest.bak" && echo "Backup of $dest created."
      fi
      cp -r "$src" "$dest"
      chown -R "$ACTUAL_USER:$ACTUAL_USER" "$dest"
      echo "Copied directory $item to $dest."
    elif [ -f "$src" ]; then
      # Backup if exists
      if [ -f "$dest" ]; then
        mv "$dest" "$dest.bak" && echo "Backup of $dest created."
      fi
      cp "$src" "$dest"
      chown "$ACTUAL_USER:$ACTUAL_USER" "$dest"
      echo "Copied file $item to $dest."
    else
      echo "Item $item not found in $src."
    fi
  done

  # Copy gp.conf to /etc/gpservice
  GP_CONF_SRC="$USER_CONFIG_DIR/gp.conf"
  GP_CONF_DEST="/etc/gpservice/gp.conf"
  if [ -f "$GP_CONF_SRC" ]; then
    # Backup if exists
    [ -f "$GP_CONF_DEST" ] && cp "$GP_CONF_DEST" "$GP_CONF_DEST.bak" && echo "Backup of $GP_CONF_DEST created."
    cp "$GP_CONF_SRC" "$GP_CONF_DEST"
    chown root:root "$GP_CONF_DEST"
    echo "Copied gp.conf to $GP_CONF_DEST."
  else
    echo "gp.conf not found in $GP_CONF_SRC."
  fi
}

# Function to install tmux-sessionizer
install_tmux_sessionizer() {
  echo "Installing tmux-sessionizer..."

  # Define the installation target and source URL
  INSTALL_DIR="/usr/local/bin"
  SCRIPT_URL="https://raw.githubusercontent.com/kyleorman/tmux-sessionizer/main/tmux-sessionizer.sh"
  INSTALL_PATH="$INSTALL_DIR/tmux-sessionizer"
  CONFIG_DIR="$USER_HOME/.config"

  # Ensure the target directory exists
  echo "Ensuring $INSTALL_DIR exists..."
  mkdir -p "$INSTALL_DIR" || {
    echo "Error: Failed to create directory $INSTALL_DIR."
    exit 1
  }

  # Download the main script
  echo "Downloading tmux-sessionizer from $SCRIPT_URL..."
  curl -fsLo "$INSTALL_PATH" "$SCRIPT_URL" || {
    echo "Error: Failed to download tmux-sessionizer script."
    exit 1
  }

  # Set executable permissions for the script
  echo "Setting executable permissions for tmux-sessionizer..."
  chmod +x "$INSTALL_PATH" || {
    echo "Error: Failed to set executable permissions for tmux-sessionizer."
    exit 1
  }

  # Ensure the user's config directory exists
  echo "Ensuring $CONFIG_DIR exists..."
  su - "$ACTUAL_USER" -c "mkdir -p $CONFIG_DIR" || {
    echo "Error: Failed to create directory $CONFIG_DIR."
    exit 1
  }

  # Verify the installation
  if command -v tmux-sessionizer >/dev/null 2>&1; then
    echo "tmux-sessionizer installed successfully."
  else
    echo "Error: tmux-sessionizer installation failed."
    exit 1
  fi
}

# Function to configure Git
configure_git() {
  GIT_SETUP_SCRIPT="$VAGRANT_SCRIPTS_DIR/git_setup.sh"
  GIT_SETUP_CONF="$VAGRANT_CONFIG_DIR/git_setup.conf"

  echo "Configuring Git..."

  if [ -f "$GIT_SETUP_SCRIPT" ] && [ -f "$GIT_SETUP_CONF" ]; then
    su - "$ACTUAL_USER" -c "bash '$GIT_SETUP_SCRIPT' --config-file '$GIT_SETUP_CONF' --non-interactive" || {
      echo "Git configuration failed"
      exit 1
    }
  else
    echo "Git setup script or configuration file not found."
  fi
}

# Function to install LazyVim
install_lazyvim() {
  echo "Installing LazyVim..."

  # Ensure Neovim 0.9 or higher is installed
  if ! command -v nvim &>/dev/null || ! nvim --version | grep -q '^NVIM v0\.\([9-9]\|1[0-9]\)'; then
    echo "Neovim 0.9 or higher is not installed. Please install it before proceeding."
    exit 1
  fi

  # Clone the LazyVim starter repository if not already present
  LAZYVIM_DIR="$USER_HOME/.config/nvim"
  if [ ! -d "$LAZYVIM_DIR" ]; then
    echo "Cloning LazyVim starter repository..."
    su - "$ACTUAL_USER" -c "git clone https://github.com/LazyVim/starter '$LAZYVIM_DIR'" || {
      echo "Failed to clone LazyVim starter repository"
      exit 1
    }
  else
    echo "LazyVim starter repository is already cloned in $LAZYVIM_DIR."
  fi

  # Install Neovim plugin manager (lazy.nvim) if not already installed
  if [ ! -d "$USER_HOME/.local/share/nvim/lazy" ]; then
    echo "Installing lazy.nvim plugin manager..."
    su - "$ACTUAL_USER" -c "git clone https://github.com/folke/lazy.nvim.git --branch=stable '$USER_HOME/.local/share/nvim/lazy'" || {
      echo "Failed to install lazy.nvim"
      exit 1
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
  pacman -S --noconfirm --needed ripgrep fd || {
    echo "Failed to install dependencies"
    exit 1
  }

  # Clone Doom Emacs repository
  if [ ! -d "$USER_HOME/.emacs.d" ]; then
    echo "Cloning Doom Emacs repository..."
    su - "$ACTUAL_USER" -c "git clone --depth 1 https://github.com/doomemacs/doomemacs '$USER_HOME/.emacs.d'" || {
      echo "Failed to clone Doom Emacs"
      exit 1
    }
  else
    echo "Doom Emacs is already cloned in $USER_HOME/.emacs.d"
  fi

  # Create Doom configuration if it doesn't exist
  if [ ! -d "$USER_HOME/.doom.d" ]; then
    echo "Creating Doom configuration directory..."
    su - "$ACTUAL_USER" -c "mkdir -p '$USER_HOME/.doom.d'"
  fi

  # Let Doom install its own configuration
  su - "$ACTUAL_USER" -c "$USER_HOME/.emacs.d/bin/doom install --force" || {
    echo "Doom Emacs installation failed"
    exit 1
  }

  # Fix ownership of .emacs.d and .doom.d directories
  echo "Fixing ownership of .emacs.d and .doom.d directories..."
  chown -R "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME/.emacs.d" "$USER_HOME/.doom.d" || echo "Failed to change ownership of $USER_HOME/.emacs.d or $USER_HOME/.doom.d"

  # Sync Doom Emacs packages
  echo "Syncing Doom Emacs packages..."
  su - "$ACTUAL_USER" -c "$USER_HOME/.emacs.d/bin/doom sync" || {
    echo "Doom Emacs package sync failed"
    exit 1
  }

  echo "Doom Emacs installed successfully."
}


# Function to install Rust
install_rust() {
  echo "Installing Rust..."

  # Check if Rust is already installed
  if command -v rustc &>/dev/null; then
    echo "Rust is already installed. Skipping installation."
    return
  fi

  # Download and execute the Rust installer
  echo "Downloading and installing Rust..."
  su - "$ACTUAL_USER" -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y" || {
    echo "Failed to install Rust."
    exit 1
  }

  # Add Cargo and Rust binaries to the PATH
  RUST_ENV_FILE="$USER_HOME/.cargo/env"
  SHELL_RC="$USER_HOME/.zshrc" # Update for other shells as needed

  if [ -f "$RUST_ENV_FILE" ]; then
    if [ ! -f "$SHELL_RC" ]; then
      touch "$SHELL_RC"
      chown "$ACTUAL_USER:$ACTUAL_USER" "$SHELL_RC"
    fi
    if ! grep -q "source $RUST_ENV_FILE" "$SHELL_RC"; then
      echo "Adding Rust environment to $SHELL_RC..."
      su - "$ACTUAL_USER" -c "echo 'source $RUST_ENV_FILE' >> $SHELL_RC"
    else
      echo "Rust environment already sourced in $SHELL_RC."
    fi
  else
    echo "Warning: Rust environment file ($RUST_ENV_FILE) not found."
  fi

  # Ensure Rust is available in the provisioning environment
  echo "Exporting Rust environment for the current session..."
  export PATH="$USER_HOME/.cargo/bin:$PATH"

  # Verify the installation
  echo "Verifying Rust installation..."
  su - "$ACTUAL_USER" -c "rustup --version" || {
    echo "Rustup installation verification failed."
    exit 1
  }

  echo "Rust installed successfully."
}

# Function to install cht.sh
install_cht_sh() {
  echo "Installing cht.sh..."

  # Define the target path
  CHT_SH_PATH="/usr/local/bin/cht.sh"

  # Check if cht.sh is already installed
  if [ -x "$CHT_SH_PATH" ]; then
    echo "cht.sh is already installed at $CHT_SH_PATH. Skipping installation."
    return
  fi

  # Download and install cht.sh
  echo "Downloading cht.sh..."
  curl -s https://cht.sh/:cht.sh | sudo tee "$CHT_SH_PATH" >/dev/null || {
    echo "Failed to download cht.sh."
    exit 1
  }

  # Make cht.sh executable
  echo "Setting executable permissions for cht.sh..."
  sudo chmod +x "$CHT_SH_PATH" || {
    echo "Failed to set executable permissions for cht.sh."
    exit 1
  }

  # Verify installation
  if command -v cht.sh &>/dev/null; then
    echo "cht.sh installed successfully at $CHT_SH_PATH."
  else
    echo "cht.sh installation failed."
    exit 1
  fi
}

# Install hdl_checker
install_hdl_checker_with_pipx() {
  echo "Installing hdl_checker using pipx..."

  # Define a separate temporary directory for hdl_checker installation
  HCL_TMP_DIR="/tmp/hdl_checker_install"

  # Ensure the temporary directory exists
  mkdir -p "$HCL_TMP_DIR" || {
    echo "Failed to create temporary directory $HCL_TMP_DIR"
    exit 1
  }
  cd "$HCL_TMP_DIR" || {
    echo "Failed to access temporary directory $HCL_TMP_DIR"
    exit 1
  }

  # Install necessary dependencies using pacman
  echo "Installing dependencies for hdl_checker..."
  sudo pacman -S --noconfirm --needed python-setuptools python-pip python-wheel git base-devel python-pipx || {
    echo "Failed to install dependencies"
    exit 1
  }

  # Ensure pipx path as ACTUAL_USER
  echo "Ensuring pipx path..."
  su - "$ACTUAL_USER" -c "python3 -m pipx ensurepath" || {
    echo "Failed to ensure pipx path"
    exit 1
  }

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
  if [ ! -f "$SHELL_RC" ]; then
    touch "$SHELL_RC"
    chown "$ACTUAL_USER:$ACTUAL_USER" "$SHELL_RC"
  fi
  if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$SHELL_RC"; then
    echo "Adding ~/.local/bin to PATH in $SHELL_RC..."
    echo 'export PATH="$HOME/.local/bin:$PATH"' >>"$SHELL_RC"
  fi

  # Clone the hdl_checker repository
  echo "Cloning hdl_checker repository..."
  git clone https://github.com/suoto/hdl_checker.git || {
    echo "Failed to clone hdl_checker repository"
    exit 1
  }
  cd hdl_checker || {
    echo "Failed to navigate to hdl_checker directory"
    exit 1
  }

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
  su - "$ACTUAL_USER" -c "pipx install '$HCL_TMP_DIR/hdl_checker'" || {
    echo "Failed to install hdl_checker via pipx"
    exit 1
  }

  # Verify installation
  echo "Verifying hdl_checker installation..."
  su - "$ACTUAL_USER" -c "command -v hdl_checker" >/dev/null 2>&1 && echo "hdl_checker installed successfully." || {
    echo "hdl_checker installation failed."
    exit 1
  }

  # Clean up temporary directory
  echo "Cleaning up temporary files..."
  rm -rf "$HCL_TMP_DIR" || echo "Failed to remove temporary directory $HCL_TMP_DIR"
}

# Function to rebuild bat cache
rebuild_bat_cache() {
  echo "Rebuilding bat theme cache..."

  # Ensure bat is installed
  if ! command -v bat &>/dev/null; then
    echo "Error: 'bat' command not found. Please install bat before proceeding."
    exit 1
  fi

  # Run bat cache --build as the appropriate user
  if su - "$ACTUAL_USER" -c "bat cache --build"; then
    echo "Bat theme cache rebuilt successfully."
  else
    echo "Error: Failed to rebuild bat theme cache."
    exit 1
  fi
}

overwrite_shell_configs() {
  echo "Overwriting shell configuration files..."

  # Directory containing shell configuration files in user_config
  SHELL_CONFIGS_DIR="$USER_CONFIG_DIR/shell_configs"

  # Define the shell configuration files to overwrite and their corresponding locations
  declare -A SHELL_CONFIGS=(
    ["zshrc"]="$USER_HOME/.zshrc"
    ["bashrc"]="$USER_HOME/.bashrc"
    ["fish/config.fish"]="$USER_HOME/.config/fish/config.fish"
    ["nushell/config.nu"]="$USER_HOME/.config/nushell/config.nu"
  )

  # Iterate through the shell configuration files and overwrite them
  for src_file in "${!SHELL_CONFIGS[@]}"; do
    local src_path="$SHELL_CONFIGS_DIR/$src_file"
    local dest_path="${SHELL_CONFIGS[$src_file]}"

    # Ensure the source file exists
    if [ ! -f "$src_path" ]; then
      echo "Warning: Source shell configuration file $src_path not found. Skipping."
      continue
    fi

    # Create the parent directory for the destination if it doesn't exist
    dest_dir="$(dirname "$dest_path")"
    if [ ! -d "$dest_dir" ]; then
      echo "Creating directory $dest_dir..."
      mkdir -p "$dest_dir" || {
        echo "Error: Failed to create directory $dest_dir. Skipping $dest_path."
        continue
      }
    fi

    # Backup the existing configuration file if it exists
    if [ -f "$dest_path" ]; then
      echo "Backing up existing $dest_path to $dest_path.bak..."
      cp "$dest_path" "$dest_path.bak" || {
        echo "Error: Failed to back up $dest_path. Skipping overwrite."
        continue
      }
    fi

    # Copy the new configuration file to the destination
    echo "Copying $src_path to $dest_path..."
    cp "$src_path" "$dest_path" || {
      echo "Error: Failed to copy $src_path to $dest_path. Skipping."
      continue
    }

    # Adjust ownership of the file
    echo "Setting ownership of $dest_path to $ACTUAL_USER..."
    chown "$ACTUAL_USER:$ACTUAL_USER" "$dest_path" || {
      echo "Error: Failed to set ownership for $dest_path."
    }

    echo "Successfully updated $dest_path."
  done

  echo "Shell configuration file overwrite process completed."
}


# Configure X11 Forwarding
configure_ssh_x11_forwarding() {
  SSH_CONFIG="/etc/ssh/sshd_config"

  echo "Configuring SSH for X11 forwarding..."

  # Check if the file already contains the required settings and add them if not
  if ! grep -q "^X11Forwarding yes" "$SSH_CONFIG"; then
    echo "X11Forwarding yes" >>"$SSH_CONFIG"
  fi

  if ! grep -q "^X11DisplayOffset 10" "$SSH_CONFIG"; then
    echo "X11DisplayOffset 10" >>"$SSH_CONFIG"
  fi

  if ! grep -q "^X11UseLocalhost yes" "$SSH_CONFIG"; then
    echo "X11UseLocalhost yes" >>"$SSH_CONFIG"
  fi

  # Restart the SSH service to apply changes
  systemctl restart sshd

  echo "X11 forwarding configuration applied and SSH service restarted."
}

# Function to ensure home directory ownership is correct
ensure_home_ownership() {
  echo "Ensuring home directory ownership is correct..."
  chown -R "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME"
}

# --- Main Script Execution ---

STEPS=(
	"check_internet_connection"
	"resize_disk"
	"enable_parallel_builds"
	"install_dependencies"
	"install_rust"
	"install_aur_packages"
	"copy_config_files"
	"install_python_tools"
	"install_tmux_sessionizer"
	"install_cht_sh"
	"install_broot"
	"install_go_tools"
  # "install_openroad_from_source" # opt-in only: resource intensive
	# "install_verible_from_source" # opt-in only: verible is installed via AUR
	"install_tpm"
	"install_vim_plugins"
	"install_doom_emacs"
	"install_lazyvim"
	"install_hdl_checker_with_pipx"
	"clone_fzf_git_repo"
	"install_oh_my_zsh"
	"install_starship"
	"install_spaceship"
	"install_powerlevel10k"
	"install_oh_my_posh"
	"install_zsh_plugins"
	"configure_git"
	"install_coc_dependencies"
	"rebuild_bat_cache"
	"overwrite_shell_configs"
	"configure_ssh_x11_forwarding"
	"ensure_home_ownership"
)

NUM_STEPS=${#STEPS[@]}

echo "----- Starting Setup Script -----"

# Initialize progress tracking
init_progress_bar

# Execute each step
for i in "${!STEPS[@]}"; do
    step_name="${STEPS[$i]}"
    current_step=$((i + 1))

    # Log the current step
    log_line "Running step $current_step/$NUM_STEPS: $step_name..."

    # Run the step function
    "$step_name"

    # Update progress bar
    progress_bar_inline "$current_step" "$NUM_STEPS"
done

# Clean up progress bar and restore terminal state
cleanup_progress_bar

echo "Cleaning up package manager cache..."
pacman -Scc --noconfirm || true

echo "----- Setup Completed Successfully! -----"

# Remove the trap to prevent cleanup from running again
trap - ERR EXIT

echo "----- Setup Script Finished -----"

# --- End of Script ---
