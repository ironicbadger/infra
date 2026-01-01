#!/bin/bash
set -e

# This script is copied inside the template container and run to set it up

NVIDIA_DRIVER_VERSION=$1

if [ -z "$NVIDIA_DRIVER_VERSION" ]; then
    echo "Error: NVIDIA driver version not specified"
    echo "Usage: $0 <driver_version>"
    exit 1
fi

echo "Setting up LXC template with NVIDIA driver ${NVIDIA_DRIVER_VERSION}..."

# Update system
echo "Updating system packages..."
apt update
apt upgrade -y

# Install prerequisites
echo "Installing prerequisites..."
apt install -y curl gnupg lsb-release ca-certificates wget sudo nano

# Get NVIDIA driver
echo "Downloading NVIDIA driver ${NVIDIA_DRIVER_VERSION}..."
latest_driver_file="NVIDIA-Linux-x86_64-${NVIDIA_DRIVER_VERSION}.run"
curl -O "https://download.nvidia.com/XFree86/Linux-x86_64/${NVIDIA_DRIVER_VERSION}/${latest_driver_file}"
chmod +x ${latest_driver_file}

# Install NVIDIA driver without kernel modules (as these are provided by the host)
echo "Installing NVIDIA driver (without kernel modules)..."
./${latest_driver_file} --no-kernel-module --silent --accept-license || {
    echo "Error: NVIDIA driver installation failed"
    exit 1
}

# Setup NVIDIA Container Toolkit repository
echo "Setting up NVIDIA Container Toolkit repository..."
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sed 's#\$(ARCH)#amd64#g' > /etc/apt/sources.list.d/nvidia-container-toolkit.list

# Install Docker and NVIDIA Container Toolkit
echo "Installing NVIDIA Container Toolkit..."
apt update
apt install -y nvidia-container-toolkit || {
    echo "Error: Failed to install nvidia-container-toolkit"
    exit 1
}

# Install Docker
echo "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh || {
    echo "Error: Docker installation failed"
    exit 1
}

# Configure NVIDIA runtime for Docker
echo "Configuring NVIDIA runtime for Docker..."
nvidia-ctk runtime configure --runtime=docker || {
    echo "Error: Failed to configure nvidia-ctk runtime"
    # Continue anyway as this might still work in the actual container
}

# Enable Docker service (this might fail in chroot, which is fine)
systemctl enable docker || echo "Warning: Failed to enable docker service (expected in chroot)"

# Create a sample docker-compose.yaml for Ollama
echo "Creating sample docker-compose.yaml for Ollama..."
mkdir -p /root
cat > /root/compose.yaml << 'EOF'
version: '3.8'
services:
  ollama:
    container_name: ollama
    image: ollama/ollama:latest
    restart: unless-stopped
    ports:
      - "11434:11434"
    volumes:
      - ollama_data:/root/.ollama
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
volumes:
  ollama_data:
EOF

# Add instructions for container configuration in Proxmox
cat > /root/README.txt << EOF
=== NVIDIA GPU-enabled LXC Container ===

This container has NVIDIA driver ${NVIDIA_DRIVER_VERSION} pre-installed.

To enable GPU access, add the following to your container configuration
in Proxmox (/etc/pve/lxc/<container-id>.conf):

lxc.cgroup2.devices.allow: c 195:* rwm
lxc.cgroup2.devices.allow: c 234:* rwm
lxc.cgroup2.devices.allow: c 509:* rwm
lxc.mount.entry: /dev/nvidia0 dev/nvidia0 none bind,optional,create=file
lxc.mount.entry: /dev/nvidiactl dev/nvidiactl none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-modeset dev/nvidia-modeset none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm dev/nvidia-uvm none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm-tools dev/nvidia-uvm-tools none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-caps/nvidia-cap1 dev/nvidia-caps/nvidia-cap1 none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-caps/nvidia-cap2 dev/nvidia-caps/nvidia-cap2 none bind,optional,create=file

NOTE: The device numbers (195, 234, 509) may vary - verify them on your host with:
ls -la /dev/nvidia*

To test GPU access, run:
nvidia-smi
EOF

# Clean up
echo "Cleaning up..."
apt clean
apt autoremove -y
rm -f ${latest_driver_file} get-docker.sh
rm -rf /var/lib/apt/lists/*

# Clear command history
cat /dev/null > ~/.bash_history
history -c || true

echo "Setup complete! The template is ready."