#!/bin/bash
# credit: https://www.apalrd.net/posts/2023/pve_cloud/

function create_template() {
    echo "Creating template $2 ($1)"

    qm create $1 --name $2 --ostype l26
    qm set $1 --net0 virtio,bridge=vmbr0
    qm set $1 --serial0 socket --vga serial0
    qm set $1 --memory 1024 --cores 4 --cpu host
    qm set $1 --scsi0 ${storage}:0,import-from="$(pwd)/$3",discard=on
    qm set $1 --boot order=scsi0 --scsihw virtio-scsi-single
    qm set $1 --agent enabled=1,fstrim_cloned_disks=1
    qm set $1 --ide2 ${storage}:cloudinit
    qm set $1 --ipconfig0 "ip6=auto,ip=dhcp"
    qm set $1 --sshkeys ${ssh_keyfile}
    qm set $1 --ciuser ${username}
    qm disk resize $1 scsi0 8G
    qm template $1

    #Remove file when done
    rm $3
}

export ssh_keyfile=/root/.ssh/id_ed25519.pub
export username=zaphod
export storage=shared

## Ubuntu
#24.04 (Noble Numbat) LTS
wget "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
virt-customize -a ubuntu-24.04-server-cloudimg-amd64.img --install qemu-guest-agent
create_template 9000 "ubuntu-2404" "ubuntu-24.04-server-cloudimg-amd64.img"