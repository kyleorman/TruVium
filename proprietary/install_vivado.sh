#!/bin/bash
INSTALL_DIR=$1

echo "Installing Vivado WebPACK..."

# Download the installer (you can specify a specific version or allow it to download the latest)
wget -O /tmp/vivado-webpack-installer.tar.gz "https://www.xilinx.com/member/forms/download/xef.html?filename=Xilinx_Vivado_WebPACK_Lin_2023.x.tar.gz"

# Extract the installer
mkdir -p /tmp/vivado
tar -xvzf /tmp/vivado-webpack-installer.tar.gz -C /tmp/vivado

# Run the installer
/tmp/vivado/xsetup --batch Install --edition WebPACK --location "$INSTALL_DIR/vivado" --accept-eula XilinxEULA

# Set up environment variables
echo "export PATH=$INSTALL_DIR/vivado/bin:\$PATH" >> ~/.bashrc
source ~/.bashrc

echo "Vivado WebPACK installed in $INSTALL_DIR/vivado"
