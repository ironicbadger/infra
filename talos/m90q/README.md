# M90q Talos cluster

Created 2026-09-08. Three Talos VMs, one on each M90q. No application workloads.

| Proxmox host | VM | Name | Address | CPU / RAM | System disk |
|---|---|---|---|---|---|
| m90q-1 | 1201 | talos-m90q-1 | 10.42.1.121 | 4 vCPU / 8 GiB | local, 64 GiB qcow2 |
| m90q-2 | 1202 | talos-m90q-2 | 10.42.1.122 | 4 vCPU / 8 GiB | local, 64 GiB qcow2 |
| m90q-3 | 1203 | talos-m90q-3 | 10.42.1.123 | 4 vCPU / 8 GiB | local, 64 GiB qcow2 |

Kubernetes API VIP: https://10.42.1.120:6443. Gateway 10.42.0.254; DNS 10.42.0.53.
These static IPs are outside the documented DHCP range (10.42.7.1–254), had no
ARP response before provisioning, and had no matching declarations in either repo.
All nodes are control planes and allow application scheduling. Pod CIDR is
10.244.0.0/16; Service CIDR is 10.96.0.0/12. Nodes have Proxmox host zone labels.

Talos is pinned to 1.13.8 (matching the installed talosctl), Kubernetes 1.36.2.
The Talos image includes qemu-guest-agent. Ballooning is disabled. VM autostart
is enabled; Proxmox HA is not configured for these local-disk VMs. Kubernetes
handles workload recovery across surviving nodes; replace a lost node locally.

## Ownership

- This repo: VM inventory, provisioning and configuration generation scripts.
- `../k8s/clusters/m90q`: encrypted Talos secrets, patches and Flux platform config.
- Flux tracks `ironicbadger/k8s`, branch `codex/m90q-cluster`, path `clusters/m90q`.
  That path includes only Flux and platform infrastructure. It references neither
  the old clusters' apps nor their Rook-managed Ceph deployments.
- Cilium 1.20.1 replaces kube-proxy; KubePrism uses port 7445.
- Ceph-CSI RBD 3.17.1 consumes existing Proxmox Ceph. Pool `k8s-m90q` has
  size=3, min_size=2 and autoscaling PGs. User `client.k8s-m90q` has access only
  to this pool. Default StorageClass `ceph-rbd` uses Retain and supports expansion.
- Tailscale operator 1.102.3 exposes the authenticated API at
  `https://m90q-ts-operator.ktz.ts.net`, using existing `tag:k8s-operator` and
  `tag:k8s` tags. OAuth credentials are encrypted in the k8s repo. No appdata
  has been migrated. Tailnet access was verified with `kubectl get nodes`.

## Access

Use explicit configs; the build did not change your default kubectl context:

```sh
export TALOSCONFIG="$PWD/../k8s/clusters/m90q/talos/clusterconfig/talosconfig"
export KUBECONFIG="$PWD/../k8s/clusters/m90q/talos/clusterconfig/kubeconfig"
kubectl get nodes -o wide
flux get all -A
talosctl -n 10.42.1.121 etcd members
```

## Secrets and recovery

New cluster secrets are SOPS-encrypted for both the existing infra recipient and
`~/.config/sops/age/m90q.txt`. The existing infra private key was not present on
this Mac when building. The new private key must be backed up separately and
must never be committed. Plaintext configs are mode 0600 inside the ignored
`k8s/clusters/m90q/talos/clusterconfig/` directory (mode 0700).

`python3 talos/m90q/generate.py` decrypts the saved secrets and regenerates config;
it does not apply it. Do not generate replacement cluster secrets during recovery.
Use normal Talos etcd snapshot/recovery procedures. An encrypted initial snapshot
is kept under `~/.local/share/talos-backups/m90q/`; recurring backups are not yet
configured. The snapshot is not a backup of app volumes.

## Reproduction

`cluster.json` is the public VM inventory. `schematic.json` records the Image
Factory customization. The ISO is stored on shared ISO storage:

```sh
ssh root@meeseeks 'curl -fL --retry 3 https://factory.talos.dev/image/ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515/v1.13.8/metal-amd64.iso -o /mnt/pve/ISOs/template/iso/talos-1.13.8-qemu.iso'
python3 talos/m90q/provision.py
python3 talos/m90q/generate.py
```

Provisioning refuses any existing declared VMID; it never replaces a VM. It uses
meeseeks as the SSH gateway and Proxmox's existing cluster SSH trust. At initial
ISO boot obtain each DHCP address using `pvesh get /nodes/<host>/qemu/<vmid>/agent/network-get-interfaces`.
Validate generated config with `talosctl validate --mode metal`, apply it to each
fresh maintenance-mode node using `talosctl apply-config --insecure`, then bootstrap
etcd exactly once and fetch kubeconfig. Install Cilium using the pinned values
in the k8s repo before waiting for node readiness. Install the checked-in Flux
components, create the `flux-system/sops-age` Secret from the recovery key and
apply `gotk-sync.yaml`; Flux installs the remaining platform resources.

`python3 talos/m90q/verify-storage.py` is a disposable infrastructure check: creates
a 1 GiB Ceph PVC, writes on node 1, reads on node 2, checks DNS and deletes its
namespace and volume. It does not install an application. Existing app volumes
are never touched. Retain remains the default for future application volumes.

## Verified on 2026-09-08

- All three nodes Ready; all platform Deployments and DaemonSets ready.
- Flux root/platform reconciliations and both HelmReleases healthy.
- Temporary Ceph PVC provisioned, mounted, written on node 1, remounted and read
  on node 2; cluster DNS resolved successfully. Test namespace and RBD image removed.
- Rebooted node 1 while it owned the API VIP. VIP moved to node 2; twelve API
  readiness probes at three-second intervals all succeeded. Node 1 rejoined.
- Talos health checks passed; etcd has three consistent voting members.
- Ceph remains HEALTH_OK. No application manifests or persistent test volumes.
- Installation ISOs ejected after installation; all VMs boot only from local disk.
- Encrypted etcd snapshot saved at
  `~/.local/share/talos-backups/m90q/20260908T160248Z.snapshot.age`.
