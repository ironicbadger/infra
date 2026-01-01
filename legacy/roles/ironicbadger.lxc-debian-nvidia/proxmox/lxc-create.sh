#!/bin/bash

# Default values
DEFAULT_CORES=8
DEFAULT_MEMORY=8192
DEFAULT_HOSTNAME="abc123"
DEFAULT_ROOT_PASSWORD="abc123"
DEFAULT_STORAGE="nvme1tb"
DEFAULT_DISK_SIZE=64
DEFAULT_SWAP=512
TEMPLATE="/var/lib/vz/template/cache/nvidia-template-debian12-570.124.04.tar.gz"

# Function to display usage information
usage() {
    echo "Usage: $0 --id LXC_ID [--cores CORES] [--memory MEMORY] [--hostname HOSTNAME]"
    echo "          [--password PASSWORD] [--storage STORAGE] [--disk-size SIZE]"
    echo "          [--swap SWAP]"
    exit 1
}

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --id) LXC_ID="$2"; shift ;;
        --cores) CORES="$2"; shift ;;
        --memory) MEMORY="$2"; shift ;;
        --hostname) HOSTNAME="$2"; shift ;;
        --password) ROOT_PASSWORD="$2"; shift ;;
        --storage) STORAGE="$2"; shift ;;
        --disk-size) DISK_SIZE="$2"; shift ;;
        --swap) SWAP="$2"; shift ;;
        --help) usage ;;
        *) usage ;;
    esac
    shift
done

# Check if LXC ID was provided
if [ -z "$LXC_ID" ]; then
    usage
fi

# Set defaults for unspecified parameters
CORES=${CORES:-$DEFAULT_CORES}
MEMORY=${MEMORY:-$DEFAULT_MEMORY}
HOSTNAME=${HOSTNAME:-$DEFAULT_HOSTNAME}
ROOT_PASSWORD=${ROOT_PASSWORD:-$DEFAULT_ROOT_PASSWORD}
STORAGE=${STORAGE:-$DEFAULT_STORAGE}
DISK_SIZE=${DISK_SIZE:-$DEFAULT_DISK_SIZE}
SWAP=${SWAP:-$DEFAULT_SWAP}

# Define the config file path for Proxmox VE
CONFIG_FILE="/etc/pve/lxc/$LXC_ID.conf"

# Function to generate random MAC address
generate_mac() {
    printf "BC:%02X:%02X:%02X:%02X:%02X" $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256))
}

# Function to add configuration if it doesn't exist
add_if_not_exists() {
    local config="$1"
    if ! grep -q "^$config" "$CONFIG_FILE"; then
        echo "$config" >> "$CONFIG_FILE"
        echo "Added: $config"
    else
        echo "Already exists: $config"
    fi
}

# Check if the container exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Container $LXC_ID does not exist. Creating..."

    # Check if template exists
    if [ ! -f "$TEMPLATE" ]; then
        echo "Error: Template $TEMPLATE not found!"
        exit 1
    fi

    # Generate a random MAC address
    MAC_ADDRESS=$(generate_mac)

    # Create the container with basic parameters
    pct create "$LXC_ID" "$TEMPLATE" \
        --cores "$CORES" \
        --memory "$MEMORY" \
        --hostname "$HOSTNAME" \
        --storage "$STORAGE" \
        --rootfs "$STORAGE:$DISK_SIZE" \
        --swap "$SWAP" \
        --password "$ROOT_PASSWORD" \
        --unprivileged 0 \
        --net0 "name=eth0,bridge=vmbr0,firewall=1,hwaddr=$MAC_ADDRESS,ip=dhcp,type=veth"

    if [ $? -ne 0 ]; then
        echo "Error: Failed to create container $LXC_ID"
        exit 1
    fi

    echo "Container $LXC_ID created successfully."
else
    echo "Container $LXC_ID already exists. Updating configuration..."

    # Update container settings if it already exists
    pct set "$LXC_ID" --cores "$CORES" --memory "$MEMORY" --swap "$SWAP" 2>/dev/null

    echo "Container settings updated."
fi

# Handle the unprivileged setting
if grep -q "^unprivileged:" "$CONFIG_FILE"; then
    # If unprivileged exists, check if it's set to 1 and change to 0 if needed
    sed -i 's/^unprivileged: 1/unprivileged: 0/' "$CONFIG_FILE"
    echo "Checked unprivileged setting"
else
    # If unprivileged doesn't exist, add it
    add_if_not_exists "unprivileged: 0"
fi

# Add all the required configuration lines
add_if_not_exists "lxc.cgroup2.devices.allow: c 195:* rwm"
add_if_not_exists "lxc.cgroup2.devices.allow: c 234:* rwm"
add_if_not_exists "lxc.cgroup2.devices.allow: c 509:* rwm"
add_if_not_exists "lxc.mount.entry: /dev/nvidia0 dev/nvidia0 none bind,optional,create=file"
add_if_not_exists "lxc.mount.entry: /dev/nvidiactl dev/nvidiactl none bind,optional,create=file"
add_if_not_exists "lxc.mount.entry: /dev/nvidia-modeset dev/nvidia-modeset none bind,optional,create=file"
add_if_not_exists "lxc.mount.entry: /dev/nvidia-uvm dev/nvidia-uvm none bind,optional,create=file"
add_if_not_exists "lxc.mount.entry: /dev/nvidia-uvm-tools dev/nvidia-uvm-tools none bind,optional,create=file"
add_if_not_exists "lxc.mount.entry: /dev/nvidia-caps/nvidia-cap1 dev/nvidia-caps/nvidia-cap1 none bind,optional,create=file"
add_if_not_exists "lxc.mount.entry: /dev/nvidia-caps/nvidia-cap2 dev/nvidia-caps/nvidia-cap2 none bind,optional,create=file"
add_if_not_exists "lxc.apparmor.profile: unconfined"
add_if_not_exists "lxc.cgroup2.devices.allow: a"
add_if_not_exists "lxc.cap.drop:"

echo "Proxmox VE LXC container $LXC_ID configuration has been completed successfully."