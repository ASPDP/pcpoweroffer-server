# PC Power Offer Server

A Go-based gRPC server for controlling power via serial port (`/dev/ttyACM0`).

## Installation

To install the server on your Linux machine, run the following one-liner:

```bash
git clone https://github.com/ASPDP/pcpoweroffer-server.git && cd pcpoweroffer-server && sudo ./install.sh
```

## Update

To update the server to the latest version:

```bash
cd pcpoweroffer-server
sudo ./update.sh
```

## Configuration

The configuration file is located at `/etc/pcpoweroffer-server/config.cfg`.
Default password: `0192837465`

## API

See `api_description.md` for details on the gRPC API.
