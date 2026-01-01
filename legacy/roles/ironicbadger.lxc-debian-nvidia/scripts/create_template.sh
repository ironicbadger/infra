#!/bin/bash
set -e

NVIDIA_DRIVER_VERSION=$1

if [ -z "$NVIDIA_DRIVER_VERSION" ]; then
    echo "Error: NVIDIA driver version not specified"
    echo "Usage: $0 <driver_version>"
    exit 1
fi

TEMPLATE_NAME="nvidia-template-debian12-${NVIDIA_DRIVER_VERSION}"

echo "Creating Proxmox LXC template with NVIDIA driver ${NVIDIA_DRIVER_VERSION}..."

# Create a temporary directory
mkdir -p /tmp/template
cd /tmp/template

# Create a Debian 12 rootfs
echo "Creating Debian 12 rootfs with debootstrap..."
debootstrap --arch=amd64 bookworm /tmp/template/rootfs http://deb.debian.org/debian/

# Copy our setup script into the rootfs
cp /template/setup_template.sh /tmp/template/rootfs/setup.sh
chmod +x /tmp/template/rootfs/setup.sh

# Ensure /dev exists in the chroot
mkdir -p /tmp/template/rootfs/dev

# Prepare the chroot environment
echo "Mounting virtual filesystems for chroot..."
mount -t proc proc /tmp/template/rootfs/proc || echo "Warning: Failed to mount proc filesystem"
mount -t sysfs sys /tmp/template/rootfs/sys || echo "Warning: Failed to mount sysfs filesystem"
mount -o bind /dev /tmp/template/rootfs/dev || echo "Warning: Failed to bind mount /dev"
mkdir -p /tmp/template/rootfs/dev/pts
mount -o bind /dev/pts /tmp/template/rootfs/dev/pts || echo "Warning: Failed to bind mount /dev/pts"

# Run our setup script inside the chroot
echo "Running setup script inside chroot..."
chroot /tmp/template/rootfs /bin/bash -c "/setup.sh ${NVIDIA_DRIVER_VERSION}" || {
    echo "Error: Setup script failed inside chroot"
    # Try to unmount everything before exiting
    umount -l /tmp/template/rootfs/proc 2>/dev/null || true
    umount -l /tmp/template/rootfs/sys 2>/dev/null || true
    umount -l /tmp/template/rootfs/dev/pts 2>/dev/null || true
    umount -l /tmp/template/rootfs/dev 2>/dev/null || true
    exit 1
}

# Clean up the chroot environment
echo "Cleaning up chroot environment..."
rm -f /tmp/template/rootfs/setup.sh
umount -l /tmp/template/rootfs/proc 2>/dev/null || echo "Warning: Failed to unmount proc"
umount -l /tmp/template/rootfs/sys 2>/dev/null || echo "Warning: Failed to unmount sys"
umount -l /tmp/template/rootfs/dev/pts 2>/dev/null || echo "Warning: Failed to unmount dev/pts"
umount -l /tmp/template/rootfs/dev 2>/dev/null || echo "Warning: Failed to unmount dev"

# Create the template tarball
echo "Creating template tarball..."
cd /tmp/template/rootfs
tar czf /template/${TEMPLATE_NAME}.tar.gz . || {
    echo "Error: Failed to create tarball"
    exit 1
}

echo "Template created at /template/${TEMPLATE_NAME}.tar.gz"
ls -la /template/${TEMPLATE_NAME}.tar.gz