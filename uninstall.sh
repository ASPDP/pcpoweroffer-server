#!/bin/bash

SERVICE_NAME="pcpoweroffer"
BINARY_NAME="pcpoweroffer-server"
INSTALL_DIR="/usr/local/bin"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

echo "Uninstalling $SERVICE_NAME..."

# Stop and disable service
systemctl stop $SERVICE_NAME
systemctl disable $SERVICE_NAME

# Remove service file
rm -f $SERVICE_FILE
systemctl daemon-reload

# Remove binary
rm -f $INSTALL_DIR/$BINARY_NAME

echo "Uninstallation complete. Config file preserved."
