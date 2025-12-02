#!/bin/bash

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

echo "Updating pcpoweroffer-server..."

# Fetch latest changes
git fetch --all
git reset --hard origin/main

# Run install script
chmod +x install.sh
./install.sh

echo "Update complete."
