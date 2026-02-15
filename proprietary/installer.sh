#!/bin/bash

# Define the default installation path
INSTALL_PATH="/opt/vlsi-tools"

# Function to display usage help
function usage() {
    echo "Usage: $0 [-c config.json]"
    echo "-c: Use JSON config file for non-interactive mode."
    exit 1
}

# Function to check if the script is running as root
function check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Please run as root."
        exit 1
    fi
}

# Function to install a tool
function install_tool() {
    local tool_name=$1
    echo "Installing $tool_name..."
    bash "tools/install_${tool_name}.sh" $INSTALL_PATH
}

# Interactive mode for tool selection
function interactive_install() {
    echo "Welcome to the Proprietary VLSI Tool Installer"
    echo "Where would you like to install the tools? [default: $INSTALL_PATH]"
    read -r user_install_path
    if [ ! -z "$user_install_path" ]; then
        INSTALL_PATH=$user_install_path
    fi

    echo "Which tools would you like to install?"
    echo "1) Vivado WebPACK"
    echo "2) ModelSim"
    echo "3) Both"
    read -r choice
    case $choice in
        1) install_tool "vivado" ;;
        2) install_tool "modelsim" ;;
        3) install_tool "vivado"
           install_tool "modelsim" ;;
        *) echo "Invalid choice"; exit 1 ;;
    esac
}

# Non-interactive mode based on JSON config
function json_install() {
    local config_file=$1
    echo "Using configuration from $config_file..."

    # Parse JSON config (requires `jq` to be installed)
    INSTALL_PATH=$(jq -r '.install_path' "$config_file")

    if jq -e '.tools.vivado' "$config_file" | grep -q true; then
        install_tool "vivado"
    fi
    if jq -e '.tools.modelsim' "$config_file" | grep -q true; then
        install_tool "modelsim"
    fi
}

# Parse command line arguments
while getopts ":c:" opt; do
    case $opt in
        c) CONFIG_FILE=$OPTARG ;;
        *) usage ;;
    esac
done

# Check if the script is run as root
check_root

# If a config file is provided, run in non-interactive mode
if [ ! -z "$CONFIG_FILE" ]; then
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Config file not found!"
        exit 1
    fi
    json_install "$CONFIG_FILE"
else
    # Default to interactive mode
    interactive_install
fi

echo "Installation completed!"
