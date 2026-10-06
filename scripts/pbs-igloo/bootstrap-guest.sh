#!/bin/bash
# Configure a Debian 13 guest as a Proxmox Backup Server.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
install -m 0644 /root/proxmox-archive-keyring.gpg /usr/share/keyrings/proxmox-archive-keyring.gpg
cat > /etc/apt/sources.list.d/proxmox.sources <<'REPO'
Types: deb
URIs: http://download.proxmox.com/debian/pbs
Suites: trixie
Components: pbs-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
REPO
disable_enterprise() {
    if [ -f /etc/apt/sources.list.d/pbs-enterprise.sources ]; then
        if ! grep -q "^Enabled: false" /etc/apt/sources.list.d/pbs-enterprise.sources; then
            echo "Enabled: false" >> /etc/apt/sources.list.d/pbs-enterprise.sources
        fi
    fi
}
disable_enterprise
apt-get update
apt-get install -y proxmox-backup-server qemu-guest-agent curl
disable_enterprise
systemctl start qemu-guest-agent
# The datastore disk must be the dedicated, newly provisioned 2 TiB volume.
disk=/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi1
[ "$(lsblk -dn -o SERIAL "$disk")" = pbs-data ]
[ "$(blockdev --getsize64 "$disk")" = 2199023255552 ]
if ! blkid "$disk"; then
    mkfs.ext4 -m 0 -L pbs-backups "$disk"
fi
[ "$(blkid -s LABEL -o value "$disk")" = pbs-backups ]
install -d /mnt/datastore/backups
if ! grep -q 'LABEL=pbs-backups ' /etc/fstab; then
    echo 'LABEL=pbs-backups /mnt/datastore/backups ext4 defaults,relatime 0 2' >> /etc/fstab
fi
mountpoint -q /mnt/datastore/backups || mount /mnt/datastore/backups
# Refuse to start PBS without its datastore disk mounted.
for service in proxmox-backup.service proxmox-backup-proxy.service; do
    install -d "/etc/systemd/system/$service.d"
    printf '[Unit]\nRequiresMountsFor=/mnt/datastore/backups\n' > "/etc/systemd/system/$service.d/datastore.conf"
done
systemctl daemon-reload
systemctl enable --now fstrim.timer
if ! grep -q '^datastore: backups$' /etc/proxmox-backup/datastore.cfg 2>/dev/null; then
    proxmox-backup-manager datastore create backups /mnt/datastore/backups --gc-schedule '06:00'
fi
if ! grep -q '^verification: backups-weekly$' /etc/proxmox-backup/verification.cfg 2>/dev/null; then
    proxmox-backup-manager verify-job create backups-weekly --store backups --schedule 'sun 08:00' --ignore-verified true --outdated-after 30
fi
systemctl restart proxmox-backup.service proxmox-backup-proxy.service
touch /root/pbs-bootstrap-complete
