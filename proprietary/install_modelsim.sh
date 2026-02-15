#!/bin/bash
INSTALL_DIR=$1

echo "Installing ModelSim..."

# Download ModelSim free edition (adjust for the specific version or vendor, e.g., Intel/Altera or Mentor Graphics)
wget -O /tmp/modelsim-installer.run "https://download.intel.com/akdlm/software/acdsinst/20.1std/modelsim-ase-linux.sh"

# Run the installer (in silent mode)
chmod +x /tmp/modelsim-installer.run
/tmp/modelsim-installer.run --mode unattended --prefix "$INSTALL_DIR/modelsim"

# Set up environment variables
echo "export PATH=$INSTALL_DIR/modelsim/bin:\$PATH" >> ~/.bashrc
source ~/.bashrc

echo "ModelSim installed in $INSTALL_DIR/modelsim"
