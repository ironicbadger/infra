# Proxmox Backup Server on igloo

PBS runs in VM **2001**, `pbs-igloo`, on the standalone igloo Proxmox host.
It receives offsite backups from the local meeseeks cluster.

## Resources and storage

- 4 vCPUs, 4 GiB fixed RAM, and a 32 GiB OS disk on `local-lvm`.
- A 2 TiB thin-provisioned ZFS volume, `z2tank/pbs/vm-2001-disk-0`, is attached
  as `scsi1` through the `pbs-zfs` storage definition. The disk has the serial
  `pbs-data`, discard enabled, and `backup=0` to avoid backing up the backup store.
- The guest formats that dedicated volume as ext4, label `pbs-backups`, mounted
  at `/mnt/datastore/backups`. The PBS datastore is named `backups`.
- The virtual disk limits the guest to 2 TiB before filesystem overhead. ZFS
  metadata, RAID parity, and any host snapshots are additional physical usage.
- ZFS stays on the host. The guest uses a normal local filesystem rather than
  nesting ZFS or mounting a network filesystem. Mount dependencies prevent PBS
  from starting against an unmounted directory on the OS disk.
- The VM starts automatically. Daily garbage collection runs at 06:00, and
  verification runs Sundays at 08:00, rechecking data after 30 days.

The guest uses Debian 13's official genericcloud image and the PBS
`pbs-no-subscription` repository. `bootstrap-guest.sh` contains the guest setup.
The source image was checked against Debian's published SHA512 digest.

## Network and administration

- `net0` uses igloo's existing `vmbr0`, with DHCP for Internet access.
- `net1` uses a host-only `vmbr1`: igloo `10.255.250.1/30`, PBS `10.255.250.2/30`.
- `/etc/network/interfaces.d/pbs-private` persists the host-only bridge.
- PBS has its own Tailscale identity: `pbs-igloo.ktz.ts.net`, IPv4
  `100.88.74.80`, tagged `tag:server` and `tag:ssh`. Tailscale is installed from
  its official Debian repository and starts automatically.
- Web interface: **https://pbs-igloo.ktz.ts.net/** (tailnet access required).
  Tailscale Serve terminates HTTPS with an automatically renewed public
  certificate. No browser certificate exception is required:

  ```sh
  # Inside PBS
  tailscale serve --bg https+insecure://localhost:8007
  ```

- The loopback connection uses PBS's local certificate. The `https+insecure`
  setting applies only to that loopback backend, not browser-facing TLS.
- The existing igloo TCP 8007 forwarder remains the cluster's backup transport,
  with the PBS certificate fingerprint pinned by PVE. It is not the browser
  entry point. Keeping it preserves in-flight initial backup connections:

  ```sh
  # On igloo
  tailscale serve --bg --tcp 8007 tcp://10.255.250.2:8007
  ```

- SSH from the workstation: `ssh -J root@igloo root@10.255.250.2`.
- Administrator: `root@pam`. The generated password is stored only in the
  root-readable `/root/pbs-deploy/admin-credentials` file on igloo. An encrypted
  copy, together with the cluster token, is in
  `group_vars/pbs-igloo.sops.yaml`, using the existing infra age recipient.
- SSH password authentication is disabled. The workstation and igloo public
  keys are authorized in the guest.

## Backups

The meeseeks cluster storage ID is `pbs-igloo`, with datastore `backups` and
backup transport `igloo.ktz.ts.net:8007`.
The cluster uses a dedicated PBS API token, `meeseeks@pbs!pve`, with
`DatastorePowerUser` permissions limited to this datastore. Token secrets belong
in PVE's private storage configuration, never in this repository.

| VM | Name | Nightly start |
| --- | --- | --- |
| 1013 | dev | 01:53 |
| 1014 | hermes | 04:29 |

All times use **America/New_York**. Retention is **7 daily and 3 monthly** backups
per VM. Jobs use snapshot mode and follow the VM's cluster node; they are not
pinned to `fwd`, where both guests currently run. The retention categories are
combined by PBS, so monthly recovery points survive beyond the seven daily ones.

## Deployment validation

- The VM rebooted successfully with the datastore mounted and no failed units.
- Both meeseeks and fwd report the PBS storage as active.
- The dedicated Serve endpoint returns HTTP 200 with normal certificate
  validation. An authenticated shell WebSocket returned HTTP 101 and executed
  a command whose output was verified. The login page also loaded in a browser
  without a certificate warning.
- An 8 MiB random-data backup from fwd was restored and compared byte-for-byte.
  The comparison passed, and the temporary test snapshot was deleted.
- Initial snapshot backups of VMs 1013 and 1014 were started as one sequential
  PVE task. They were still running when deployment was handed over; check the
  task log for the final result:

  ```sh
  pvesh get /nodes/fwd/tasks/UPID:fwd:00048DCE:0FFE34FA:6AAA0A65:vzdump::root@pam:/status
  ```

## Recovery and checks

```sh
# On igloo
qm config 2001
zfs list -t volume z2tank/pbs/vm-2001-disk-0
tailscale serve status
ssh root@10.255.250.2 'systemctl status proxmox-backup-proxy; df -h /mnt/datastore/backups'

# On meeseeks or the VM's current node
pvesm status --storage pbs-igloo
pvesh get /cluster/backup
pvesm list pbs-igloo --content backup
```

If the PBS OS disk is lost, recreate the guest OS and reattach the existing
ZFS volume. **Do not format the existing datastore volume.** Mount it and use
PBS's reuse-existing-datastore option. Restore PBS configuration from a secure
copy if available, or recreate users and permissions, update the client token
and TLS fingerprint, and set backup group ownership appropriately.

VM 1013 had no responding QEMU guest agent during deployment. Its snapshot
backup is crash-consistent; enable its guest agent for filesystem freezing.

This VM depends on igloo and its ZFS pool. Offsite copies protect against loss
of the local cluster, but are not independent of igloo's hardware.

References: [PBS installation](https://pbs.proxmox.com/docs/installation.html),
[PBS storage](https://pbs.proxmox.com/docs/storage.html).
