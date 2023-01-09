# Create Ubuntu template

* SSH into proxmox server

```bash
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
qm create 8001 --memory 2048 --name ubuntu-cloud-2204 --net0 virtio,bridge=vmbr0
qm importdisk 8001 jammy-server-cloudimg-amd64.img local
qm set 8001 --scsihw virtio-scsi-pci --scsi0 local:8001/vm-8001-disk-0.raw
qm set 8001 --ide2 local:cloudinit
qm set 8001 --boot c --bootdisk scsi0
qm set 8001 --serial0 socket --vga serial0
```