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

# 1. Install Dependencies
echo "Checking dependencies..."
if ! command -v go &> /dev/null; then
    echo "Go not found. Installing Go..."
    # This is a best-effort install for Debian/Ubuntu. 
    # For other distros, user might need to install manually.
    if command -v apt-get &> /dev/null; then
        apt-get update
        apt-get install -y golang
    elif command -v yum &> /dev/null; then
        yum install -y golang
    else
        echo "Could not install Go. Please install Go manually."
        exit 1
    fi
fi

if ! command -v protoc &> /dev/null; then
    echo "Protoc not found. Installing protobuf-compiler..."
    if command -v apt-get &> /dev/null; then
        apt-get install -y protobuf-compiler
    elif command -v yum &> /dev/null; then
        yum install -y protobuf-compiler
    else
        echo "Could not install protoc. Please install protobuf-compiler manually."
        exit 1
    fi
fi

# Install Go plugins for protoc
echo "Installing Go plugins for protoc..."
export PATH=$PATH:$(go env GOPATH)/bin
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

# 2. Generate Code
echo "Generating gRPC code..."
make gen
if [ $? -ne 0 ]; then
    echo "Code generation failed."
    exit 1
fi

# 3. Build Binary
echo "Building binary..."
make build
if [ $? -ne 0 ]; then
    echo "Build failed."
    exit 1
fi

# 4. Install Binary
echo "Installing binary to $INSTALL_DIR..."
cp ./$BINARY_NAME $INSTALL_DIR/$BINARY_NAME
chmod +x $INSTALL_DIR/$BINARY_NAME

# 5. Setup Config
mkdir -p $CONFIG_DIR
if [ ! -f "$CONFIG_DIR/config.cfg" ]; then
    echo "Installing config..."
    cp ./config.cfg $CONFIG_DIR/config.cfg
else
    echo "Config already exists, skipping overwrite."
fi

# 6. Create systemd service
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
# We run as root to access /dev/ttyACM0

[Install]
WantedBy=multi-user.target
EOF

# 7. Reload and start
systemctl daemon-reload
systemctl enable $SERVICE_NAME
systemctl restart $SERVICE_NAME

echo "Installation complete. Service started."
