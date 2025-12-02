#!/bin/bash

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

echo "Updating pcpoweroffer-server..."

# Stop and remove existing service using uninstall script
if [ -f "./uninstall.sh" ]; then
    echo "Stopping and removing existing service..."
    chmod +x uninstall.sh
    ./uninstall.sh
else
    echo "Warning: uninstall.sh not found. Attempting manual stop..."
    systemctl stop pcpoweroffer
    systemctl disable pcpoweroffer
fi

# Fetch latest changes
echo "Fetching latest code..."
git fetch --all
git reset --hard origin/main

# Run install script
echo "Installing new version..."
chmod +x install.sh
./install.sh

echo "Update complete."
