#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 --id LXC_ID"
    exit 1
}

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --id) lxc_id="$2"; shift ;;
        *) usage ;;
    esac
    shift
done

# Check if LXC ID was provided
if [ -z "$lxc_id" ]; then
    usage
fi

# Define the config file path for Proxmox VE
config_file="/etc/pve/lxc/$lxc_id.conf"

# Check if the config file exists
if [ ! -f "$config_file" ]; then
    echo "Error: Config file for LXC ID $lxc_id not found at $config_file"
    exit 1
fi

# Function to add configuration if it doesn't exist
add_if_not_exists() {
    local config="$1"
    if ! grep -q "^$config" "$config_file"; then
        echo "$config" >> "$config_file"
        echo "Added: $config"
    else
        echo "Already exists: $config"
    fi
}

# Handle the unprivileged setting
if grep -q "^unprivileged:" "$config_file"; then
    # If unprivileged exists, check if it's set to 1 and change to 0 if needed
    sed -i 's/^unprivileged: 1/unprivileged: 0/' "$config_file"
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
add_if_not_exists "lxc.cgroup2.devices.allow: c 10:200 rwm"
add_if_not_exists "lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file"


echo "Proxmox VE LXC container $lxc_id configuration has been updated successfully."