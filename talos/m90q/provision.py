#!/usr/bin/env python3
"""Create only the declared Talos VMs. Never modifies pre-existing VMs."""
import json, pathlib, shlex, subprocess
root = pathlib.Path(__file__).resolve().parent
cfg = json.loads((root / 'cluster.json').read_text())
def remote(args, node=None, capture=False):
    command = shlex.join(args)
    if node:
        command = shlex.join(['ssh', '-o', 'BatchMode=yes', 'root@'+node, command])
    return subprocess.run(['ssh', '-o', 'BatchMode=yes', cfg['sshGateway'], command], check=True, text=True, capture_output=capture)
resources=json.loads(remote(['pvesh','get','/cluster/resources','--output-format','json'],capture=True).stdout)
existing={r['vmid']:r for r in resources if 'vmid' in r}
for n in cfg['nodes']:
    if n['vmid'] in existing:
        raise SystemExit(f"VMID {n['vmid']} already exists; refusing to change any VMs")
for n in cfg['nodes']:
    remote(['qm','create',str(n['vmid']),'--name',n['name'],'--description','Talos m90q cluster; managed by infra/talos/m90q; local system disk, external Ceph app volumes',
        '--cores',str(cfg['cores']),'--memory',str(cfg['memoryMiB']),'--balloon','0','--cpu','host','--machine','q35','--bios','ovmf',
        '--efidisk0','local:0,efitype=4m,pre-enrolled-keys=0,format=qcow2','--scsihw','virtio-scsi-single','--scsi0',f"{cfg['storage']}:{cfg['diskGiB']},format=qcow2,discard=on,iothread=1,ssd=1",
        '--ide2','ISOs:iso/talos-1.13.8-qemu.iso,media=cdrom','--boot','order=scsi0;ide2','--net0','virtio='+n['mac']+',bridge=vmbr0',
        '--agent','enabled=1','--serial0','socket','--vga','serial0','--onboot','1','--tags','talos;m90q'],n['host'])
    remote(['qm','start',str(n['vmid'])],n['host'])
    print(f"Started {n['name']} ({n['vmid']}) on {n['proxmoxNode']}",flush=True)
