#!/bin/bash

SERVICE_NAME="pcpoweroffer"
BINARY_NAME="pcpoweroffer-server"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/pcpoweroffer-server"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

echo "Installing $SERVICE_NAME..."

# Build the binary (assuming go is installed and we are in the source directory)
if command -v go &> /dev/null; then
    echo "Building binary..."
    go build -o $BINARY_NAME
    if [ $? -ne 0 ]; then
        echo "Build failed. Please ensure you have generated the gRPC code and have dependencies installed."
        exit 1
    fi
else
    echo "Go not found. Assuming binary '$BINARY_NAME' exists in current directory."
    if [ ! -f "./$BINARY_NAME" ]; then
        echo "Binary not found. Please build it first."
        exit 1
    fi
fi

# Install binary
cp ./$BINARY_NAME $INSTALL_DIR/$BINARY_NAME
chmod +x $INSTALL_DIR/$BINARY_NAME

# Setup config
mkdir -p $CONFIG_DIR
if [ ! -f "$CONFIG_DIR/config.cfg" ]; then
    echo "Installing config..."
    cp ./config.cfg $CONFIG_DIR/config.cfg
else
    echo "Config already exists, skipping overwrite."
fi

# Create systemd service
echo "Creating systemd service..."
cat <<EOF > $SERVICE_FILE
[Unit]
Description=PC Power Offer gRPC Server
After=network.target

[Service]
ExecStart=$INSTALL_DIR/$BINARY_NAME
WorkingDirectory=$CONFIG_DIR
Restart=always
RestartSec=5
User=root
# We run as root to access /dev/ttyACM0, or use a user in dialout group
# If running as non-root, ensure user is in dialout group

[Install]
WantedBy=multi-user.target
EOF

# Reload and start
systemctl daemon-reload
systemctl enable $SERVICE_NAME
systemctl start $SERVICE_NAME

echo "Installation complete. Service started."
