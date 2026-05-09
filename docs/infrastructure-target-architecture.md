# Infrastructure Target Architecture

Status: working draft
Last hardware inference: 2026-05-03, including Proxmox, core nodes, and `igloo`
Primary goal: define the desired end state first, then rebuild toward it instead of forcing the new platform into the shape of older hosts and ad hoc service placement.

## How To Use This Document

This document is meant to become the planning source of truth for the next version of the infrastructure. It intentionally separates:

- Inferred current state: what exists now based on the repo and live Proxmox/core-node inventory.
- Guiding principles: rules that should survive individual tool choices.
- Desired end state: the system we would build if we were starting clean with the current hardware.
- Proposed decisions: defaults that should be accepted, rejected, or edited.
- Open questions: places where operator preference matters more than technical inference.

The target state should be updated before implementation work begins. Once a decision is accepted, the matching infrastructure code should be created or changed to match this document.

## High-Level Goals

- Keep critical home infrastructure available even when the app platform is broken.
- Name the critical services explicitly and make them as self-healing as the hardware realistically allows.
- Make Proxmox the stable hardware and storage substrate unless a better reason emerges.
- Use Talos/Kubernetes for declarative, cattle-style application runtime where it adds value.
- Keep bulk storage and GPU-heavy workloads close to the hardware that actually owns those resources.
- Make Forgejo/GitOps the primary workflow for day-two operations.
- Avoid pretending replication is backup. Backups must be restorable, verified, and off-site.
- Keep local services useful without the VPS, but use the VPS where it clearly improves ingress, monitoring, or external reachability.
- Prefer boring recovery paths over clever HA that cannot be debugged under pressure.

## Decision Log

These are accepted design inputs from the planning discussion.

| Topic | Decision / Preference | Consequence |
| --- | --- | --- |
| Critical availability | Critical services should be up as much as possible and self-healing. | We must name critical services and give each one an HA, backup, and break-glass policy. |
| `meeseeks` quorum | Keeping `meeseeks` in Proxmox quorum is acceptable. | The target remains a 4-node Proxmox cluster unless future behavior argues otherwise. |
| Physical network | The cluster has 10G SFP+ links end-to-end through UniFi. | Keep Ceph/storage converged on the existing 10G links unless metrics show real contention. |
| VLANs | A small set of VLANs is desirable, including cameras and management. | Network design should be intentional but not over-segmented. |
| Ceph shape | Current 3-node Ceph size 3/min_size 2 is acceptable. | Keep this as the baseline; evaluate the spare M.2 slot separately. |
| `meeseeks` criticality | `meeseeks` being on the critical path is acceptable. | A dedicated Ceph OSD on `meeseeks` becomes a viable resilience improvement. |
| Talos scope | Not yet decided. | Use an incremental Talos adoption plan rather than making Kubernetes the default for every app immediately. |
| Forgejo placement | Not yet decided. | Compare LXC, VM, and Talos placement before implementation. |
| Off-site PBS | Run PBS as a VM on `igloo` in the tailnet. | PBS datastore should live on `igloo`'s ZFS `z2tank`, not only on the VM boot disk. |
| Auth scope | No auth needed for `*arr`; auth wanted for most other apps such as Immich and Miniflux. | Pocket ID should protect user-facing/private apps, not every internal utility. |

## Current State Inferred

### Management Repo

The repo already provides a useful base:

- Ansible inventory and playbooks for servers, core nodes, and external hosts.
- Docker Compose deployment through `ironicbadger.docker-compose-generator`.
- SOPS plus age for secrets.
- Tailscale for mesh access.
- ZFS and zrepl roles for file/data replication.
- Core node roles for network config, Keepalived, AdGuard Home, AdGuard Home sync, Chrony, and Caddy.
- Experimental Proxmox/Talos Terraform under `dev/proxmox`, currently aimed at older names/storage such as `c137` and `vmstore-nfs`.

### Proxmox Cluster

Cluster name: `homeprod`
Proxmox version observed: `pve-manager/9.1.9` with kernel `7.0.0-3-pve`
Quorum: 4 nodes, quorate, expected votes 4, quorum 3

| Node | IP | Role In Current State | CPU | RAM | Notes |
| --- | --- | --- | --- | --- | --- |
| `m90q-1` | `10.42.1.91` | Proxmox, Ceph mon/mgr/osd, HA workload host | Intel i5-10500T, 6C/12T | 64 GiB | VLAN-aware `vmbr0`, Intel 82599ES dual 10G SFP+ present |
| `m90q-2` | `10.42.1.92` | Proxmox, Ceph mon/mgr standby/osd, HA workload host | Intel i5-10500T, 6C/12T | 64 GiB | VLAN-aware `vmbr0`, Mellanox ConnectX-3 present |
| `m90q-3` | `10.42.1.93` | Proxmox, Ceph mon/mgr standby/osd, HA workload host | Intel i5-10500T, 6C/12T | 64 GiB | VLAN-aware `vmbr0`, Intel 82599 10G present |
| `meeseeks` | `10.42.1.10` | Proxmox, bulk storage, GPU/media/app workloads | Intel i5-13600K, 14C/20T | 64 GiB | RTX A4000, large ZFS pools, part of Proxmox quorum |

Current network baseline:

- Proxmox management is on `10.42.0.0/21`, gateway `10.42.0.254`.
- Corosync ring addresses are the node IPs above.
- Ceph `public_network` and `cluster_network` are both set to the same `10.42.1.91/21` network family.
- The three M90q nodes use VLAN-aware bridges. `meeseeks` currently has a simpler non-VLAN-aware `vmbr0` on `nic3`.
- The physical network is understood to be 10G SFP+ end-to-end through UniFi.
- The available 10G NICs are present, but the final mapping between physical ports, bridges, VLANs, and Ceph/storage traffic still needs to be codified.
- A separate physical storage network is not justified yet because it would require new dual-SFP+ NICs and more SFP+ switch ports. A VLAN on the same physical 10G links would provide logical separation, not extra throughput.

Hardware expansion note:

- Each M90q has another M.2 slot available. This could improve capacity, performance, or recovery flexibility, but it should be planned deliberately before adding OSDs.

### Proxmox Storage

| Storage | Type | Scope | Current Use | Notes |
| --- | --- | --- | --- | --- |
| `ceph-nvme3` | Ceph RBD | Shared across cluster | VM/LXC disks | 3x 1 TB NVMe OSDs, replicated size 3, min_size 2 |
| `local` | Directory | Per node | local rootdir/images/backups | Not shared |
| `nvmeu2-vmstore` | ZFS pool | `meeseeks` only | VM/LXC disks | Mirror of 2x 3.6 TB Intel NVMe, about 58% used |
| `nvmeu2-vmstore-nfs` | NFS export | Shared from `meeseeks` | Some LXC rootfs | Depends on `meeseeks`; not equivalent to Ceph HA |
| `ISOs` | CIFS | Shared | ISO/templates | Served from `10.42.1.91` |

Ceph current state:

- Health: `HEALTH_OK`.
- Monitors: `m90q-1`, `m90q-2`, `m90q-3`.
- Managers: active on `m90q-1`, standby on `m90q-2` and `m90q-3`.
- OSDs: 3 up, 3 in, one NVMe OSD per M90q.
- Raw capacity: about 2.8 TiB.
- `ceph-nvme3` stored data: about 91 GiB logical, about 272 GiB used after replication.
- Pool policy: replicated size 3, min_size 2.

Important implication: with exactly three OSD hosts and replication size 3, all data is copied to every M90q. One M90q can be down and data should remain available at min_size 2, but the cluster cannot fully heal until that node returns. Two M90q failures should be treated as data unavailable.

### `meeseeks` Storage And GPU

`meeseeks` is not just another Proxmox compute node. It has distinct data gravity.

Observed local pools:

- `rpool`: 2x Samsung 970 PRO 512 GB NVMe mirror for host OS.
- `nvmeu2`: 2x Intel SSDPE2KX040T8 3.6 TB NVMe mirror.
- `rust`: about 164 TB raw ZFS pool, two 5-disk RAIDZ2 vdevs, about 54 TB allocated at inventory time.

Observed special hardware:

- NVIDIA RTX A4000 passed through to the `appnv` VM.
- Intel UHD 770 and ASPEED graphics also present.

Target implication: media, photos, downloads, AI/GPU, and large-file workflows should stay tied to `meeseeks` unless there is a deliberate storage redesign.

### Hardware Inventory Notes

Additional local inventory source:

- `/Users/alex/Documents/alexs-notes/02-infra/Hardware Inventory/April 2026/raw-reports/hardware-manifest.md`
- `/Users/alex/Documents/alexs-notes/02-infra/Hardware Inventory/April 2026/ceph-nvme-health-benchmark-10.42.0.93.md`
- `/Users/alex/Documents/alexs-notes/02-infra/Systems Docs/Hardware Inventory April 2026.md`
- `/Users/alex/Documents/alexs-notes/02-infra/Systems Docs/IGLOO.md`

The April manifest is useful, but live inventory supersedes it where host names and installed devices have changed. In particular, the live `meeseeks` state now has mirrored Samsung 970 PRO NVMe boot and 2x Intel 4 TB NVMe for `nvmeu2`, while the April `c137` report still shows mirrored SATA SSD boot.

Relevant available/candidate storage from the notes:

| Item | Status | Planning Use |
| --- | --- | --- |
| Spare Kingston 1 TB NVMe | User-confirmed spare and healthy; model/serial/SMART details still need to be captured | Preferred candidate for the dedicated `meeseeks` Ceph OSD after validation |
| Loose Samsung SSD 980 500 GB, serial `S64ENU0T905979N` | Drawer inventory only, untested | Possible boot disk if tested healthy; not ideal as Ceph OSD due to 500 GB size |
| M70q1 UMIS 256 GB NVMe | SMART pass, poor performance, installed in M70q1 | Possible boot-only disk if removed; not a Ceph OSD candidate |
| M70q2 UMIS 256 GB NVMe | SMART pass, poor performance, installed in M70q2 | Possible boot-only disk if removed; not a Ceph OSD candidate |
| M70q3 UMIS 256 GB NVMe | Faulted during fio with media/read errors | Do not use |
| Samsung 970 PRO 512 GB pair currently in `meeseeks` | Healthy live boot mirror | Retire/repurpose after redesign; not the preferred Ceph OSD because target is 1 TB |
| c137/meeseeks SATA SSDs, 1 TB MX500 and 1 TB 870 EVO | Present historically/currently with old ZFS labels | Useful as emergency/local storage, but not relevant to the NVMe boot plus Ceph plan |
| Existing M90q Ceph OSDs | Samsung `MZVLB1T0HBLR-000L7`, 953.9 GiB, benchmarked healthy and closely matched | Prefer matching this class/capacity for a new `meeseeks` OSD if buying used |

Procurement implication:

- Use the spare healthy 1 TB Kingston NVMe as the planned `meeseeks` Ceph OSD if validation confirms the model, serial, SMART state, firmware, endurance, and baseline performance.
- This is pragmatic rather than perfect: the cluster will use healthy client/OEM NVMe devices without enterprise power-loss protection because PLP devices are not currently worth the cost for this environment.
- Mitigate the non-PLP reality with UPS coverage, conservative Ceph health monitoring, app-consistent backups, and restore tests. Do not treat Ceph replication as protection from acknowledged-write loss or operator mistakes.
- If validation shows the Kingston drive is a poor OSD candidate, buy a dedicated 1 TB client/OEM NVMe for the `meeseeks` OSD, preferably matching the existing Samsung `MZVLB1T0HBLR-000L7` class/capacity.
- For boot, either buy a small reliable 256-500 GB NVMe or test the loose Samsung 980 500 GB and use it as the boot-only disk.

### Current Proxmox Guests

| ID | Name | Type | Node | Storage | Current Role/Notes |
| --- | --- | --- | --- | --- | --- |
| `1000` | `appnv` | VM | `meeseeks` | `nvmeu2-vmstore` | 16 cores, 24 GiB RAM, RTX A4000 passthrough, virtiofs mounts for appdata/media/downloads |
| `1111` | `immich-app` | LXC | `meeseeks` | `nvmeu2-vmstore` | 16 cores, 32 GiB RAM, mounts Immich DB appdata and `/mnt/rust/photos`, privileged container |
| `1001` | `ha` | VM | `m90q-1` | `ceph-nvme3` | 4 cores, 8 GiB RAM, HA-managed |
| `1100` | `forgejo` | LXC | `m90q-3` | `ceph-nvme3` | 6 cores, 4 GiB RAM, IP `10.42.1.100`, HA-managed |
| `2000` | `us-rdu-exit` | LXC | `m90q-2` | `nvmeu2-vmstore-nfs` | 2 cores, 1 GiB RAM, IP `10.42.0.251`, HA-managed but storage depends on `meeseeks` |
| `2001` | `panda-proxy` | LXC | `m90q-2` | `nvmeu2-vmstore-nfs` | 2 cores, 1 GiB RAM, DHCP, HA-managed but storage depends on `meeseeks` |

HA manager currently tracks:

- `vm:1001`
- `ct:1100`
- `ct:2000`
- `ct:2001`

No Proxmox backup jobs and no Proxmox replication jobs were observed at inventory time.

### Core Edge Nodes

These are already modeled in the repo as the DNS/VIP layer.

| Node | IP | Role | Hardware | Current Notes |
| --- | --- | --- | --- | --- |
| `core-pi5` | `10.42.0.5` current | Keepalived master | Raspberry Pi 5, Cortex-A76, 8 GiB RAM, 512 GB NVMe | Currently holds VIP `10.42.0.53/21` on `eth0`; target Core / Services subnet is `10.42.10.0/24` |
| `core-zima` | `10.42.0.6` | Keepalived backup | ZimaBlade, Intel Celeron N3450, 8 GiB RAM, 238 GB SATA SSD | Tailscale enabled |
| VIP | `10.42.0.53` current; target likely `10.42.10.53` | Floating service address | N/A | Intended for DNS and possibly other critical edge services |

Current repo intent:

- AdGuard Home on both nodes.
- AdGuard Home sync from `core-pi5` to `core-zima`.
- Keepalived VRRP failover.
- Chrony.
- Caddy with Cloudflare DNS challenge and wildcard `*.wd.ktz.me`.

### Off-Site Host: `igloo`

`igloo` is the intended off-site Proxmox Backup Server location.

Observed state:

- Hostname: `igloo.maple.ktz.me`.
- Proxmox version observed: `pve-manager/9.1.9` with kernel `7.0.0-3-pve`.
- Tailscale address: `100.91.74.29`.
- LAN address: `192.168.100.2/24`.
- CPU: Intel Xeon Gold 6230R.
- RAM: 64 GiB.
- ZFS pool: `z2tank`, about 82 TiB raw, about 54 TiB free at inventory time.
- Existing replicated data under `z2tank/backups/c137`, including appdata, photos, media, and video datasets.
- Existing VM `bitflip` with 16 GiB RAM, 48 cores, 100 GiB boot disk, and virtiofs access to the `bitflip` storage path.

Target implication:

- PBS should run as a VM on `igloo`.
- The PBS datastore must be backed by `z2tank`, either through a dedicated virtual disk/zvol, a carefully managed mount, or a design-specific passthrough. It should not rely only on a small local-lvm boot disk.
- The existing zrepl backup role on `igloo` should be accounted for so PBS retention and ZFS replication do not fight over the same capacity.

## Guiding Principles

### 1. Core stays independent

DNS, time, emergency access, and enough reverse proxying to reach critical services should not depend on Kubernetes, Ceph, or the app stack being healthy.

The core nodes are small on purpose. They should run critical edge services, not become general application servers.

### 2. Proxmox is the hardware contract

The M90q systems already fit Proxmox plus Ceph well: small symmetrical nodes, shared NVMe storage, HA-managed VMs/LXCs, and good recovery tooling.

Talos should run on top as a declarative workload substrate unless bare-metal Talos solves a specific problem that Proxmox cannot.

### 3. Talos is for cattle, not irreplaceable pets

Talos nodes should be reproducible from Git and disposable. A failed Talos VM should be replaced, not nursed.

Persistent data used by workloads must have an explicit storage policy, backup policy, and restore test.

### 4. Replication is not backup

Ceph replication protects against a node or OSD failure. It does not protect against deletion, bad deploys, ransomware, database corruption, or operator mistakes.

Every important data class needs both:

- Availability policy: how it stays online.
- Recovery policy: how it is restored after bad state is replicated everywhere.

### 5. Declare steady state, document bootstrap

The desired steady state should be declarative:

- Ansible for physical/core host baseline.
- Terraform/OpenTofu for Proxmox VM/container definitions where practical.
- Talos machine config for Kubernetes nodes.
- Flux or Argo CD for Kubernetes workloads.
- SOPS/age for secrets.

Bootstrap still needs a human-readable runbook because Git, DNS, auth, and Proxmox can depend on each other during disaster recovery.

### 6. Prefer local-first, external-assisted

Home should continue working if the VPS is gone. The VPS can provide external ingress, remote monitoring, status pages, off-site coordination, and public services, but it should not be required for local DNS, local auth, or local recovery.

### 7. Keep data gravity honest

The `rust` pool, photos, media, downloads, and GPU workflows belong close to `meeseeks`.

Do not pretend these workloads are transparently HA unless the storage and application architecture actually supports it.

### 8. Break-glass access must be boring

Pocket ID/OIDC can be the normal authentication path, but every critical layer needs local break-glass access:

- Proxmox root or equivalent.
- Core node SSH.
- AdGuard/Core UI.
- Forgejo admin.
- Kubernetes admin kubeconfig.
- Backup server admin.

## Target End State

The desired architecture is:

- Core nodes provide the stable local edge: DNS VIP, local reverse proxy entry point, time, and bootstrap-friendly access.
- Core nodes also provide Tailscale remote access and UPS visibility where practical.
- Proxmox remains bare metal on `m90q-1`, `m90q-2`, `m90q-3`, and `meeseeks`.
- Ceph remains on the three M90q nodes for HA VM/LXC storage and Talos node disks.
- `meeseeks` remains the bulk storage, media, photo, download, and GPU node.
- Talos runs as VMs on Proxmox for Kubernetes workloads that benefit from GitOps and declarative orchestration.
- Forgejo is treated as critical infrastructure, backed up, mirrored, and exposed through a stable local name.
- Pocket ID is the preferred OIDC provider for user-facing apps, but not a hard dependency for emergency access.
- Off-site Proxmox Backup Server stores encrypted backups and participates in restore drills.
- The VPS is used as an external edge and remote foothold, not as the primary source of truth for the home environment.

## Critical Services

Critical services are split into two concepts:

- Core services: must not depend on Proxmox, Ceph, Talos, or the app stack being healthy. These live on the low-power core nodes behind the VIP where practical.
- Tier 1 services: should be up as much as possible, normally through Proxmox HA, Ceph-backed storage, good backups, and clear restore procedures.

Proxmox should not be treated as something that is casually allowed to be down. The core layer exists because the house still needs enough DNS, access, time, and emergency operation to diagnose and recover the larger platform.

### Core Services

| Service | Target Tier | Desired Availability Pattern | State Location | Auth Policy |
| --- | --- | --- | --- | --- |
| Local DNS | Core | Active/passive on `core-pi5` and `core-zima` behind fixed VIP, target address TBD in `10.42.10.0/24` | Git plus AdGuard Home sync | Local admin break-glass |
| AdGuard Home | Core | One instance per core node, synchronized | Core node data plus Git where practical | Local admin break-glass |
| Unbound | Core candidate | Recursive/cache resolver on both core nodes if adopted | Core node config | No user auth |
| Core VIP | Core | Keepalived VRRP with health checks; target address TBD in `10.42.10.0/24` | Core node config | SSH/root break-glass |
| Caddy local reverse proxy | Core | Active/passive with same VIP, config from Git | Git/SOPS | Local admin break-glass |
| Tailscale remote access | Core | Both `core-pi5` and `core-zima` advertise subnet routes and exit-node capability | Core node config and Tailscale admin | Tailscale plus SSH break-glass |
| Time/NTP | Core | Both core nodes independently serve time with Chrony | Core node config | No user auth |
| NUT/UPS monitoring | Core | UPS state available from core layer, alerts sent externally where possible | Core node config | Local admin break-glass |
| Secrets break-glass material | Core | Offline/password-manager-backed recovery material available without app stack | Password manager/offline copy | Owner-only |

Explicitly not core:

- DHCP stays on the UniFi firewall.
- Camera recording stays on UniFi Protect hardware. The current baseline is the existing UniFi NVR; the UDM Beast is a possible consolidation option. The camera VLAN is part of the network design, not a service to move onto the core nodes.
- General app ingress should not overload the core layer unless the route is needed for infrastructure recovery.

### Tier 1 Services

| Service | Target Tier | Desired Availability Pattern | State Location | Auth Policy |
| --- | --- | --- | --- | --- |
| Proxmox API/UI | Tier 1 | Native Proxmox cluster; reachable through stable DNS | Proxmox cluster config | Proxmox local accounts required |
| Ceph | Tier 1 | 3 M90q monitors/managers/OSDs, size 3/min_size 2 | M90q NVMe OSDs | Proxmox/root break-glass |
| Forgejo | Tier 1 | Proxmox HA-backed workload, external Git mirror | Ceph-backed disk plus DB backup | Local admin plus optional OIDC |
| Pocket ID | Tier 1 | HA-backed workload with PostgreSQL if critical | Ceph-backed disk or Kubernetes PV plus DB backup | Local break-glass accounts elsewhere |
| Home Assistant OS | Tier 1 | VM on Proxmox HA using Ceph-backed storage where practical | HAOS VM disk plus app backups | App-native auth; local break-glass |
| Immich | Tier 1 | Up as much as possible, but design must respect photo/data gravity | App DB plus photo library | Pocket ID or app-native auth |
| Plex | Tier 1, `meeseeks`-bound | Up as much as possible, tied to `meeseeks` for media and hardware acceleration | `meeseeks` media/appdata | App-native auth |
| Infisical | Tier 1 | Highly available enough for normal use, but not required for emergency recovery | DB/storage TBD plus offline recovery keys | Strong auth plus offline break-glass |
| Monitoring/alerting | Tier 1 important | Local stack plus external checks; should alert on core, Proxmox, Ceph, PBS, and link failures | TBD | Auth preferred |
| PBS integration | Tier 1/off-site | Home jobs to off-site PBS on `igloo`; alert if stale for 24h | `igloo` `z2tank` | PBS local admin |

### Tier 2 Services

These should be reliable, authenticated where appropriate, and backed up where state matters, but manual recovery is acceptable.

| Service Class | Availability Target | Auth Policy | Notes |
| --- | --- | --- | --- |
| Miniflux | Tier 2 | Pocket ID or app-native auth | Good candidate for Talos once DB backup is proven |
| Nextcloud | Tier 2 | Pocket ID preferred | Important app data, but manual recovery is acceptable unless promoted later |
| Paperless-ngx | Tier 2 | Pocket ID preferred | Important app data, but manual recovery is acceptable unless promoted later |
| `*arr` apps | Tier 2/best effort | No Pocket ID required | Keep LAN/Tailscale-only or otherwise non-public |
| Download stack | Tier 2/best effort | No central auth required | Keep isolated from critical networks |
| General personal apps | Tier 2 | Pocket ID preferred when private | Promote individually if they become recovery-critical |
| Experiments/labs | Tier 3 | Case by case | Should never block restore of critical services |

### Self-Healing Rules

- Core services should fail over through Keepalived health checks or equivalent active/passive design.
- One core VIP is acceptable for DNS and Caddy as long as each service binds to its own ports on the VIP: DNS on `53/tcp` and `53/udp`, HTTP on `80/tcp`, HTTPS on `443/tcp`, and any future service-specific ports if deliberately exposed.
- Tier 1 Proxmox workloads should use HA only when their storage is truly shared and resilient.
- Do not mark NFS-from-`meeseeks` workloads as HA unless `meeseeks` failure behavior is acceptable.
- Every critical service needs a backup/restore path even if it has HA.
- Every critical service needs a break-glass path that does not depend on Pocket ID.
- Tier 1 services tied to `meeseeks` can be "up as much as possible" without pretending to survive a full `meeseeks` outage.

## Runtime Tiers

### Tier 0: Core Local Edge

Runs on `core-pi5` and `core-zima`.

Services:

- AdGuard Home local DNS.
- Optional Unbound recursive/cache resolver.
- Keepalived VIP on the Core / Services VLAN, likely `10.42.10.53` if keeping the DNS-port convention.
- Caddy local reverse proxy for critical entry points.
- Tailscale subnet router and exit node on both core nodes.
- Chrony/NTP.
- NUT/UPS monitoring.
- Optional lightweight health/status endpoints.

Design rule: core services must keep working while Proxmox, Ceph, Talos, and the VPS are unavailable. DHCP remains on the UniFi firewall.

### Tier 1: Infrastructure Control Plane

Runs primarily on Proxmox HA storage, with some special cases tied to `meeseeks`.

Services:

- Proxmox itself.
- Ceph.
- Forgejo.
- Pocket ID.
- Home Assistant OS VM.
- Immich.
- Plex as a `meeseeks`/Quick Sync/media special case.
- Infisical for normal secrets access.
- Monitoring and alerting minimum viable stack.
- Proxmox Backup Server integration.

Design rule: Tier 1 may use Proxmox HA and Ceph, but every Tier 1 service needs backups and break-glass access. Services tied to `meeseeks` should be documented honestly as high-importance, not fully node-independent HA.

### Tier 2: Declarative Application Platform

Runs on Talos VMs.

Services:

- Kubernetes control plane and workers.
- Flux or Argo CD.
- Ingress controllers.
- Cert management.
- Stateless and moderately stateful apps that fit Kubernetes well.

Design rule: Talos/Kubernetes should be rebuildable from Git plus secrets plus documented bootstrap steps.

### Tier 3: Data-Gravity Workloads

Runs close to `meeseeks`.

Services:

- Immich app/database paths currently tied to `/mnt/rust/photos` and local appdata.
- Plex/media.
- Download stack.
- GPU/AI workloads.
- Any workloads requiring direct access to `rust`, `nvmeu2`, or RTX A4000.

Design rule: optimize for data integrity and realistic recovery, not fake HA.

## OS And Runtime Choices

Decision: standardize on NixOS for non-appliance Linux hosts and VMs unless a specific exception is documented. The goal is a mostly declarative estate with host state in Git, while keeping Compose/containers for application packaging where that is the pragmatic path.

### Runtime Recommendation

| Runtime Target | Recommended Default | Good Alternatives | Avoid By Default |
| --- | --- | --- | --- |
| Proxmox bare metal | Proxmox VE | N/A | Replacing with bare-metal Talos/NixOS unless the platform direction changes |
| Talos/Kubernetes nodes | Talos | N/A | General-purpose Linux if the node is meant to be Kubernetes-only |
| Critical app VM | NixOS host VM with Compose/containers declared from Git | Debian/Ubuntu only for documented vendor or hardware friction | Arch, experimental immutable images |
| Critical app LXC | Avoid where practical; prefer NixOS VM | Debian stable transitional LXC if low-risk and already working | Arch, immutable OSes, NixOS LXC unless there is a specific tested pattern |
| Disposable container-host VM | NixOS VM with Compose/Podman/Docker | Flatcar or uCore only for a deliberate experiment | Arch for production-like services |
| Declarative appliance VM | NixOS | Debian plus Ansible | Arch |
| Lab/dev VM | NixOS by default | Debian, Arch, Flatcar/uCore if isolated | Promoting lab choices into critical path without a migration plan |
| Data-gravity/GPU VM | NixOS first, chosen after hardware/runtime test | Debian/Ubuntu where GPU/application docs require it | Immutable images unless GPU/storage workflow is proven |

### Distribution Matrix

| OS | Best Fit | Strengths | Costs / Risks | LXC Fit | VM Fit | Recommendation |
| --- | --- | --- | --- | --- | --- | --- |
| NixOS | Default for core nodes, critical app VMs, Tier 2 app VMs, and most Linux systems where host config belongs in Git | Reproducible system config, atomic-ish rebuild workflow, rollbacks, strong fit for "machine as code"; reduces config drift | Nix-specific debugging and deploy safety need discipline; wrong-architecture builds from Apple Silicon must be guarded against | Possible but not the first choice on Proxmox | Excellent | Standard default unless an exception is documented |
| Debian stable | Transitional Proxmox LXC runtime and fallback for urgent/vendor-driven cases | Stable, familiar, broad package support, excellent incident fallback | Less self-documenting unless paired with strict Ansible; easy to drift through manual `apt install` and ad hoc config | Excellent | Excellent | Compatibility fallback, not the default app-VM standard |
| Flatcar | Immutable container-host VM | Minimal container OS, immutable base, automatic atomic updates, small mutable surface | No package manager for host customization; less self-documenting in the existing Nix workflow; overlaps with NixOS+containers and Talos | Poor/not appropriate | Excellent | Tempting, but park unless a specific use case beats NixOS |
| uCore | Opinionated Fedora CoreOS-style container-host VM with extra tools | Immutable/OCI-image model, more batteries included than raw CoreOS-style hosts, good for Podman/server appliance experiments | Community/opinionated layer; smaller operational track record here; overlaps with NixOS+containers | Poor/not appropriate | Good | Lab only unless explicitly chosen for a narrow role |
| Arch | Lab/dev, latest-package testing, personal tinkering | Rolling release, current packages, excellent docs, simple packaging model | Update churn, less suitable for "boring during an outage", requires active maintenance | Possible | Good | Do not use for critical services; fine for labs |
| Ubuntu LTS | Vendor-documented app/GPU cases | Common vendor target, broad docs, newer hardware/application paths than Debian in some cases | More moving vendor-specific defaults; less preferred than Debian when no app requires it | Good | Excellent | Use when app/GPU docs make Debian annoying |

### Other OS Candidates

These are worth knowing about, but none currently displace the NixOS-first direction.

| Candidate | Category | Why It Is Interesting | Why It Is Not The Default Here | Possible Future Use |
| --- | --- | --- | --- | --- |
| GNU Guix System | Functional/declarative OS | Philosophically close to NixOS; declarative system configuration; strong reproducibility story | Switching from Nix to Guix would abandon existing Nix proficiency and `ironicbadger/nix-config`; Linux-libre/proprietary firmware and package ecosystem friction may matter | Lab only, or philosophical comparison |
| Fedora CoreOS | Immutable container host | Atomic updates/rollbacks via rpm-ostree/OCI update path; strong Podman/container-host story | Ignition/ostree model is less self-documenting in the existing Nix workflow; overlaps with Flatcar/uCore and NixOS+Compose | Only if an rpm-ostree container host clearly beats NixOS |
| openSUSE MicroOS / SUSE Linux Micro | Immutable transactional container host | Transactional updates, btrfs snapshots, automated recovery from faulty updates | Another container-host model to learn; weaker fit than NixOS for host-as-code in this repo | Lab/container-host comparison |
| Ubuntu Core | Immutable IoT/edge OS | Transactional updates, snaps, automatic rollback, strong embedded/edge story | Snap-centric and IoT-oriented; poor fit for normal homelab service VMs | Appliance/edge experiment only |
| Bottlerocket | Container/Kubernetes node OS | Minimal, secure, orchestrator-driven container worker OS | Too specialized for general VMs; overlaps with Talos for Kubernetes nodes | Only if a Kubernetes distribution explicitly benefits from it |
| Kairos | Immutable OS lifecycle framework / edge Kubernetes | OCI image-based OS updates, immutable root, A/B upgrades, bring-your-own-distribution model | Platform layer is broader than needed; overlaps with Talos and NixOS while adding its own lifecycle machinery | Edge/Kubernetes lab only |
| TrueNAS SCALE | Storage appliance OS | Strong ZFS/NAS appliance model with VM/app features | Would compete with `meeseeks`/Proxmox storage design rather than improve app runtime; not a NixOS/GitOps host model | Dedicated NAS appliance if storage architecture changes |
| Harvester | Kubernetes/HCI virtualization platform | Kubernetes API for VM/container infrastructure; open HCI model | Would replace Proxmox as the virtualization layer; much larger platform shift than needed | Revisit only if leaving Proxmox |
| VyOS / OpenWrt | Router/firewall OS | Declarative-ish network configs, commit-confirm/rollback patterns, strong routing/firewall use cases | UniFi remains the gateway/firewall by decision; not an app/runtime OS | Only if replacing UniFi routing/firewall |

Conclusion: the only alternatives that seriously match the "declarative, Git-backed, rebuildable" requirement are NixOS and Guix System. Given existing Nix experience, existing repo investment, and the desire to keep Compose/containers as the app packaging layer, NixOS remains the practical standard.

### Policy

- NixOS is the default target for core nodes, important app VMs, Tier 2 app VMs, and most Linux systems where the host definition belongs in Git.
- Debian stable remains the compatibility fallback for transitional Proxmox LXCs, vendor-driven VMs, and urgent cases where NixOS would slow recovery.
- Critical services should move toward VMs rather than LXCs when isolation, PBS restore behavior, or Docker compatibility matters.
- VM boundaries should follow failure domains, not service count. Do not create one VM per service unless isolation, restore, hardware, or lifecycle requirements justify it.
- Shared service VMs are acceptable when the grouped services have similar criticality, update cadence, backup policy, and blast radius.
- NixOS is worth standardizing on when the whole machine definition will live in Git and the operator is willing to debug Nix under pressure.
- Flatcar/uCore are parked as lab/experiment options. They should not compete with NixOS as the normal container-host VM standard unless a specific use case is documented.
- Arch is allowed for labs and experiments, not critical infrastructure.
- Talos is only for Kubernetes nodes; do not treat it as a general app VM operating system.
- A service should not move to a new OS family and a new runtime platform in the same step unless it is disposable.

### NixOS Standardization

The most coherent declarative model is not "nixify every application." It is "NixOS owns the machine; containers own the application packaging."

Recommended NixOS scope:

- Use NixOS for `core-pi5` and `core-zima`, with one-node-at-a-time conversion and tested recovery.
- Use NixOS for the shared Tier 1 `infra` VM running Forgejo, Pocket ID, Infisical, and support services as containers or simple NixOS services.
- Use NixOS for `monitoring`, `apps`, and small service VMs where reproducible host state matters.
- Keep Proxmox bare metal on Proxmox VE.
- Keep Talos nodes as Talos.
- Keep Home Assistant OS and PBS as their appliance OSes.
- Keep Debian/Ubuntu available only for GPU/media/vendor cases where NixOS adds enough friction to justify an exception.
- Keep Flatcar/uCore as lab ideas, not default runtime targets.

What NixOS should declare:

- Hostname, users, SSH keys, sudo policy, and local break-glass accounts.
- Network addresses, VLAN interfaces where needed, firewall policy, routes, and DNS clients.
- Packages required for operations and debugging.
- Systemd services, timers, health checks, and restart policy.
- Docker or Podman enablement.
- Compose project deployment units.
- Persistent volume mount points and ownership.
- Backup pre/post hooks, database dump timers, and restore helper scripts.
- Prometheus exporters, logs, and alerting hooks.
- SOPS/age secret material needed to bootstrap the host.

What NixOS should not be forced to do initially:

- Repackage every upstream application as a Nix derivation.
- Replace working Docker Compose definitions with native Nix modules unless the module is simple and mature.
- Hide application state inside the Nix store.
- Make recovery depend on Infisical, Forgejo, or Pocket ID already being online.

Core node NixOS stance:

- NixOS is a strong fit for the core nodes because the desired state is small, stable, and infrastructure-like.
- The core nodes should be rebuilt from Git, not manually configured over time.
- Convert one core node first, preferably the simpler x86 `core-zima`, then fail the VIP over and validate DNS, Caddy, Tailscale, NTP, and NUT behavior.
- Convert `core-pi5` only after the Raspberry Pi 5 boot/image path, NVMe boot behavior, remote rebuild path, and serial/local recovery path are proven.
- Never convert both core nodes in the same maintenance window.

Tier 1 VM NixOS stance:

- NixOS is the target for Tier 1 VMs if the app runtime remains boring: Compose or OCI containers, explicit volumes, explicit backups, and normal TCP health checks.
- The `infra` VM is a good candidate because self-documentation matters for Git, identity, and secrets.
- The risk is deploy/recovery safety during an outage. Mitigate by documenting `nixos-rebuild`, safe-switch rollback guards, current config mirrors outside Forgejo, and practicing a restore into an isolated VM.
- If an app's vendor documentation assumes Debian/Ubuntu and the NixOS path becomes bespoke, use Debian for that app instead of forcing consistency.

Working direction:

- Standardize on "NixOS VM + Compose" for service VMs.
- Keep Debian stable as the compatibility and emergency fallback, not the default.
- Do not use NixOS LXCs as the normal path.
- Keep Talos/Kubernetes separate from the NixOS app-VM model.

Existing Nix foundation:

- The existing public `ironicbadger/nix-config` repository means this is not a greenfield NixOS adoption.
- Current repo shape already includes flakes, nix-darwin, NixOS hosts, `sops-nix`, Colmena output, host deployment attributes, common modules, and `just` targets for local build/switch and `colmena build`/`colmena apply`.
- Colmena is already available, but it is not an architectural requirement. It is one possible apply/orchestration tool.
- The `infra` repository should document architecture, inventories, Proxmox/UniFi state, service intent, and Proxmox VM creation metadata. The `nix-config` repository should own NixOS image builds, host definitions, reusable Nix modules, and NixOS deployment workflows. Cross-links are better than duplicating every host definition into both repos.

Nix provisioning versus deployment:

| Concern | Preferred Starting Tooling | Role | Notes |
| --- | --- | --- | --- |
| Blank-machine install / destructive rebuild | `nixos-anywhere` plus `disko` | Install NixOS over SSH, partition/format disks declaratively, prove a host can be rebuilt from config | Best fit for ground-up rebuild drills and new Proxmox VMs |
| Disk layout declaration | `disko` | Keep partitions, filesystems, swap, boot, and mount layout in Nix | Use carefully on existing nodes; destructive modes must be explicit |
| Simple remote switch | `nixos-rebuild --target-host` | Minimal moving parts for one host | Good baseline and incident fallback |
| Multi-host push deploy | Colmena or deploy-rs | Evaluate/build/apply multiple hosts from a workstation or CI runner | Choose after a pilot; neither is mandatory |
| Pull-based reconciliation | Flux or Argo CD | Kubernetes app reconciliation | Do not use this model for Tier 0 NixOS hosts by default |

Deployment tool options:

| Option | Pros | Cons | Fit |
| --- | --- | --- | --- |
| Raw `nixos-rebuild --target-host` | Built-in, simple, easy to reason about, excellent fallback | No fleet grouping, less ergonomic for many hosts | Start here for the first one or two hosts |
| Colmena | Already present in `nix-config`; tags, parallel multi-host applies, familiar NixOS fleet model | Extra tool semantics; not a provisioner; not required if host count stays small | Good if managing many NixOS nodes from the laptop |
| deploy-rs | Flake-native deploy definitions, deploy checks, useful profile model | Different configuration model than current Colmena output | Worth investigating before committing to Colmena |
| Custom `just`/shell wrappers | Maximum transparency, easy to encode site-specific checks | Can become bespoke and under-tested | Good for bootstrap and break-glass commands |
| CI-driven deploy | Builds and checks are reproducible away from the laptop | Needs careful approvals, secrets, remote builder/cache design, and rollback gates | Start with checks/builds only; deploy lower-risk hosts later |

Nix deployment model:

- Treat NixOS host management as Git-driven deployment, normally initiated by Forgejo runners rather than a laptop.
- The laptop remains the bootstrap and break-glass control point, not the daily deployment path.
- CI should run checks, build closures, update binary caches, and deploy approved changes.
- For core nodes, require manual approval and one-node-at-a-time rollout because a bad DNS/Caddy/Tailscale rollout can break recovery paths.
- For lower-risk NixOS app VMs, CI-triggered deploys can become the default after rollback and alerting behavior are proven.
- Use pull-based GitOps primarily for Kubernetes workloads through Flux or Argo CD, where the platform is designed for reconciliation.
- Do not install a generic "pull and rebuild myself" agent on core nodes unless there is a clear rollback story and a way to pause bad commits.
- Do not choose Colmena until it wins a pilot against raw `nixos-rebuild --target-host` and deploy-rs for this environment.

Git-driven deployment options:

| Model | How It Works | Pros | Risks / Costs | Fit |
| --- | --- | --- | --- | --- |
| Forgejo runner CI-push | Forgejo Actions runner checks/builds, then deploys over SSH using `nixos-rebuild --target-host`, deploy-rs, Colmena, or a wrapper | Keeps laptop out of daily path; simple mental model; works with existing Forgejo/runners goal; easy approvals | Runner needs deploy keys; CI can lock out hosts if safety checks are weak; local Forgejo outage blocks normal deploys | Preferred default for NixOS hosts |
| Host pull with `system.autoUpgrade` or custom timer | Host periodically pulls a flake and switches itself | Very GitOps-like; no inbound SSH from runner; simple for low-risk systems | Harder to pause bad commits; lockout risk; each host needs Git/secrets/network access; less central control | Avoid for Tier 0; possible for low-risk lab/Tier2 after safe-switch wrapper |
| Cachix Deploy-style agent | CI builds and publishes closures; host agent pulls binaries and activates requested deployment | Pull model without local builds on agents; avoids direct SSH from CI; binary-cache centered | External service unless self-host equivalent exists; another control plane; currently not as self-contained as Forgejo | Interesting if SSH-push becomes painful |
| Hercules CI effects / Nix-native CI | Nix-native CI with deployment effects and agent model | Strong Nix semantics, deploys as explicit effects | More platform adoption; may be overkill for home | Investigate only if Forgejo runners are insufficient |
| Garnix/NixCI/SaaS Nix CI | External Nix CI builds/checks and optionally deploys | Fast Nix-specific CI/cache; good off-site validation | GitHub/SaaS-oriented; less aligned with Forgejo-primary/self-hosted goal | Useful for public mirror validation, not primary home control plane |
| Kubernetes Flux/Argo CD | Cluster pulls manifests from Git and reconciles | True GitOps model; mature for Kubernetes | Applies only to Kubernetes workloads; bootstrap loops if Git/identity are down | Preferred for Talos/Kubernetes apps |

Preferred Forgejo runner topology:

- Run Forgejo and normal Git hosting in the Tier 1 `infra` VM.
- Do not run the only deploy runner inside the same `infra` VM it must deploy or recover.
- Create a separate NixOS `runner-control` VM for Forgejo Actions runners, with Nix installed, access to the Nix binary cache, and narrowly scoped deploy SSH keys.
- Consider a second runner on `igloo` or another off-site node for repository mirror checks, DR runbooks, and external reachability tests.
- Use runner labels/tags for blast-radius separation: `check`, `build-x86`, `deploy-tier2`, `deploy-tier1`, `deploy-core`.
- Protect deploy jobs with branch protection, manual approval, environment gates, and path filters.
- Core deploy jobs must deploy one core node at a time and run the safe-switch health checks before continuing.
- The off-site Git mirror must be sufficient to recover the deployment repository if the home `infra` VM is down.
- The laptop keeps a checkout and credentials for emergency deploys, but should not be required for routine changes.

Binary cache strategy:

- A binary cache is strongly recommended once Forgejo runners become the normal deploy path.
- Use an `x86_64-linux` builder/runner for most Proxmox VMs and `core-zima`.
- Initially build `core-pi5` on target; later add an `aarch64-linux` builder/cache if Pi build times are too slow.
- Self-hosted Attic fits the "own the stack" preference, but if it lives only at home it is not a disaster-recovery dependency.
- Cachix is operationally easy and supports deploy-agent workflows, but it adds an external service dependency.
- Targets must be able to build locally as a fallback when cache or runner infrastructure is unavailable.

Build strategy:

- The laptop can remain the orchestration point even when it is not the best builder.
- Apple Silicon macOS should evaluate and orchestrate, not be trusted as the Linux builder for production hosts.
- Every NixOS host must declare its target platform explicitly:
  - x86 VMs and `core-zima`: `x86_64-linux`.
  - `core-pi5`: `aarch64-linux`.
- Do not let Linux host definitions inherit `builtins.currentSystem`, the laptop's `aarch64-darwin`, or a Darwin package set by accident.
- For x86 NixOS VMs and `core-zima`, builds should happen on the target, on a Proxmox x86 Nix builder VM, or in Linux CI. The Apple Silicon laptop should only trigger the apply.
- For `core-pi5`, prove the aarch64 Linux build path explicitly. Building on the Pi may be slower but simple; an aarch64 Linux builder VM, remote builder, or binary cache can improve deploy time later.
- If using `nixos-rebuild` from the Mac, prefer `--target-host` plus `--build-host` so the closure is built on Linux, not on macOS.
- If using Colmena, use per-host `deployment.buildOnTarget = true` unless a known-good Linux remote builder/cache is configured.
- If using deploy-rs, test its build-host behavior before adopting it for mixed Apple Silicon/macOS to Linux deployments.
- Do not make build success depend only on the home Forgejo/`infra` VM. Mirror the Nix config repo to GitHub or another off-site remote, and keep a local laptop checkout usable during outages.
- Keep the flake lockfile pinned and update intentionally, with a build/test window before applying to Tier 0.

Concrete deployment patterns from Apple Silicon:

| Target | Safe Build Pattern | Notes |
| --- | --- | --- |
| x86 NixOS VM | Build on target with `nixos-rebuild --target-host root@host --build-host root@host` | Simple and avoids local architecture mismatch |
| Many x86 NixOS VMs | Build on a dedicated Proxmox `x86_64-linux` Nix builder/cache, then activate targets | Faster and keeps app VMs smaller |
| `core-zima` | Build on target or x86 builder | Avoid changing both core nodes in one run |
| `core-pi5` | Build on target first; later add an `aarch64-linux` builder/cache if needed | Do not assume Apple Silicon macOS can build Linux ARM closures correctly |
| CI validation | Use Linux runners for Linux systems; macOS runners only for nix-darwin | CI should catch wrong-platform imports before deploy |

Wrong-architecture guardrails:

- Use `nixpkgs.hostPlatform` or `nixosSystem { system = ...; }` for every NixOS host.
- Keep Darwin and Linux package sets separate.
- Use `pkgs.stdenv.hostPlatform.system` for target-aware package selection, not the evaluator's system.
- Avoid importing `nixpkgs.legacyPackages.${builtins.currentSystem}` in modules shared by Linux hosts.
- Run checks that evaluate every host from the Apple Silicon laptop while forcing Linux targets to remain Linux.
- A successful rebuild from the Mac should prove that the Mac can orchestrate the Linux deploy without building the wrong architecture locally.

Rollback and drift policy:

- Manual host changes are allowed during incidents, but they must be backported into Nix or recorded as temporary drift immediately afterward.
- NixOS generations provide fast local rollback; PBS provides VM-level rollback; both should be documented per host.
- For core nodes, every rollout should have a known previous generation and local console/SSH path before applying to the second node.
- For app VMs, every Compose-backed service should have explicit persistent volume paths, database dump timers, and restore notes declared alongside the host config.

NixOS deploy lockout prevention:

- Treat network, SSH, firewall, Tailscale, DNS, and Keepalived changes as high-risk, even when the Nix evaluation succeeds.
- Prefer `nixos-rebuild test` for risky core-node changes before `switch`; test activates the config without making it the boot default.
- For remote core-node changes, use a rollback guard: schedule a temporary rollback or reboot-to-previous-generation job before applying, then cancel it only after SSH, Tailscale, DNS, VIP, and service health checks pass.
- Keep an always-open SSH session or console session during risky applies so an active shell can repair obvious mistakes even if new connections fail.
- Use `tmux` or `screen` on the target for remote rebuilds so the apply is not tied to a fragile client terminal.
- Make firewall rules additive first, then restrictive in a later rollout. Never combine first-time VLAN/interface migration with a simultaneous broad firewall lockdown.
- Keep a permanent break-glass SSH path on core nodes that does not depend on Pocket ID, Infisical, Caddy, or the VIP.
- Keep at least one local account with key-based SSH, password/sudo recovery path, and documented console access.
- Do not restart or reconfigure both Tailscale core subnet routers in the same maintenance window.
- Do not switch both core nodes in the same window unless one has already been proven healthy on the exact generation.
- For Proxmox VMs, take a PBS backup or Proxmox snapshot before risky runtime/network changes where practical.
- For bare core nodes, prefer a physical console, PiKVM, serial, or local keyboard/monitor recovery path before first NixOS conversion.

Core-node safe rollout sequence:

1. Build and evaluate from the laptop, but build the Linux closure on the target or Linux builder.
2. Confirm current access paths: direct SSH, Tailscale SSH/path, console/PiKVM/serial if available, and local admin credentials.
3. Schedule a rollback guard on the target.
4. Apply with `nixos-rebuild test` first for risky network/firewall/core-service changes.
5. Validate direct SSH, Tailscale, DNS resolution, AdGuard/Unbound, Caddy, Chrony, NUT, and Keepalived VIP behavior.
6. If healthy, run `nixos-rebuild switch` and repeat the same checks.
7. Cancel the rollback guard only after validation passes.
8. Wait before touching the second core node.

Example rollback guard pattern:

```bash
old_system="$(readlink -f /run/current-system)"
sudo systemd-run --unit=nixos-rollback-guard --on-active=10m --collect \
  "$old_system/bin/switch-to-configuration" switch
```

Cancel after validation:

```bash
sudo systemctl cancel nixos-rollback-guard.timer
```

This exact command should be tested in the canary VM before using it on core nodes; the design requirement is the guardrail, not this specific implementation.

Ground-up rebuild investigation:

- Create a sacrificial NixOS VM on Proxmox and rebuild it from zero using `nixos-anywhere` plus `disko`.
- Validate the full lifecycle: create VM shell, boot installer or kexec path, run install, reboot, apply config, restore secrets, start Compose app, back up to PBS, destroy, and restore/rebuild again.
- Promote that pattern to the `infra` VM only after the canary host proves that disk layout, networking, SSH keys, SOPS keys, Compose units, and backup hooks are all reproducible.
- For `core-zima`, use the same ground-up model only after the canary VM is boring.
- For `core-pi5`, separately prove the aarch64/Pi 5 installer or image path before treating it like the x86 systems.
- A successful rebuild drill is the real acceptance test. The deployment tool is secondary.

### Runtime Placement Rules

Use this decision tree before choosing LXC, VM, Talos, NixOS, Flatcar/uCore, or bare services.

| Workload Shape | Preferred Runtime | Why | Examples |
| --- | --- | --- | --- |
| The house needs it during Proxmox/Ceph/Talos outages | Core node service on `core-pi5`/`core-zima` | Keeps recovery primitives outside the main cluster | DNS/AdGuard, Caddy, Tailscale subnet router, NTP, NUT |
| Appliance OS with its own supported VM shape | Dedicated Proxmox VM | Avoids fighting the appliance model | Home Assistant OS, PBS |
| Tier 1 app with normal Linux/container assumptions and important state | NixOS Proxmox VM on Ceph, using Compose/containers | Declarative host state, clean isolation, PBS restore, reduced drift | `infra` VM, monitoring VM |
| Lightweight single-purpose service with minimal state and no nested Docker | NixOS VM by default; Debian LXC only for transitional/simple cases | Preserves declarative standard while keeping LXC available where overhead matters | Small utilities, simple proxies, existing transitional services |
| Service needs Docker Compose, multiple containers, or clean backup semantics | NixOS VM with Compose managed by systemd | Avoids Docker-in-LXC edge cases, declares host state, restores as a unit | Forgejo/Pocket ID/Infisical, Tier 2 apps |
| Service needs local disks, media paths, GPU, or iGPU | `meeseeks`-bound VM or LXC | Honest placement near the data/hardware instead of pretending it is HA | Plex, Immich, downloads, AI/GPU |
| Service is stateless or has proven external state/PV backup | Talos/Kubernetes | GitOps-native and disposable | Small web apps, ingress experiments, selected Tier 2 services |
| Whole machine should be declared as code and rarely debugged imperatively | NixOS VM | Strong reproducibility and rollbacks | Purpose-built appliance VM, possible future core-node model |
| Single-purpose container host where Kubernetes is unnecessary | NixOS VM with Compose/Podman/Docker | Same declarative host model as the rest of the estate | Experimental container appliance, isolated service host |
| Latest packages or personal experimentation | Lab VM only | Contains churn away from production paths | Arch/dev boxes |

Runtime boundary rules:

- Do not put bootstrap dependencies only behind themselves. GitOps cannot require Forgejo to already be healthy; normal secrets access cannot require Infisical to already be healthy.
- Prefer one VM per failure domain, not one VM per service. Group services only when they share criticality, backup policy, restore order, update cadence, and acceptable blast radius.
- Use LXCs for simple host-adjacent services, not as the default Docker substrate for important multi-container apps.
- Use VMs for anything where PBS restore behavior, isolation, kernel/device assumptions, or Docker compatibility matters.
- Treat `meeseeks`-bound workloads as important but not cluster-HA unless the state and hardware dependency have been removed.
- Talos starts as a selected-workload platform, not the default destination for apps with unclear state, unclear backups, or bootstrap-loop risk.
- NixOS is the standard for non-appliance Linux hosts and VMs. Tier 0 rollout still requires one-node-at-a-time conversion, rebuild proof, and break-glass procedures.

Declarative management model:

| Layer | Tooling | Source Of Truth | Notes |
| --- | --- | --- | --- |
| Physical and network inventory | Markdown plus exported UniFi state | Git repo plus periodic dumps | Human-reviewed because cables, ports, and hardware reality matter |
| Proxmox guests | Terraform/OpenTofu where practical | Git | VM shell, disks, network attachments, cloud-init where supported |
| NixOS core nodes and VMs | Nix flakes/modules plus SOPS/age | Git plus off-site mirror | Default for non-appliance Linux hosts and VMs |
| Debian VMs/LXCs | Ansible | Git plus SOPS/age | Compatibility/fallback path and transitional LXC support |
| App stacks on NixOS/Debian VMs | Compose files plus systemd units | Git plus SOPS/age | Prefer explicit volumes, DB dump jobs, and restore docs |
| Talos nodes | Talos machine config | Git plus encrypted secrets | Rebuildable nodes; no hand-managed node state |
| Kubernetes apps | Flux or Argo CD | Git plus external mirror | Do not depend on home Forgejo as the only copy |
| Secrets | SOPS/age for bootstrap; Infisical for normal app/runtime secrets | Git for encrypted bootstrap material; Infisical for day-2 use | Infisical must not be the only way to recover Infisical, Forgejo, or Pocket ID |

### Proposed VM Grouping

| VM / Runtime Group | Tier | Candidate Services | Placement | Rationale |
| --- | --- | --- | --- | --- |
| `core-pi5` / `core-zima` | Tier 0 | DNS, Caddy, Keepalived, Tailscale, NTP, NUT | NixOS | Must survive app platform outages; NixOS provides self-documenting host state with one-node-at-a-time safe rollout |
| `haos` | Tier 1 | Home Assistant OS | Proxmox HA on Ceph | Appliance OS; dedicated VM is required |
| `infra` | Tier 1 | Forgejo, Pocket ID, Infisical, small supporting DBs if not externalized | NixOS VM on Proxmox HA/Ceph, Compose/containers | Shared critical infra VM by preference; requires external Git mirrors and break-glass material outside this VM |
| `runner-control` | Tier 1 support | Forgejo Actions runners, Nix build/deploy tooling, deploy wrappers | Separate NixOS VM on Proxmox HA/Ceph | Keeps deployment execution out of the `infra` VM it may need to deploy or recover |
| `monitoring` | Tier 1 important | Grafana, VictoriaMetrics/Influx, alerting components | NixOS VM on Proxmox HA/Ceph | Should observe other service groups and avoid sharing their failure domain |
| `pbs-local` | Tier 1 support | Local Proxmox Backup Server | Dedicated Proxmox VM with non-Ceph datastore target TBD | Appliance VM; fast restores should not depend only on off-site `igloo` |
| `immich` | Tier 1 | Immich app stack and DB | `meeseeks`-adjacent NixOS VM unless storage/runtime test proves an exception | Photos/data gravity dominate the design; current LXC can be transitional |
| `plex` | Tier 1, `meeseeks`-bound | Plex | `meeseeks` LXC or VM/container path with hardware acceleration | Media and hardware acceleration are local to `meeseeks` |
| `apps` | Tier 2 | Miniflux, Nextcloud, Paperless-ngx, other personal apps | NixOS VM first, Talos later if storage/backup is proven | Keeps Tier 2 apps out of the infra control plane |
| `media-ops` | Tier 2 | `*arr`, download stack | `meeseeks`-adjacent NixOS VM by default | Tied to media/download paths; does not need central auth by default |
| `talos-*` | Tier 2 platform | Kubernetes control plane/workers and selected apps | Talos VMs on Proxmox, backed by Ceph for node disks | Declarative app platform once bootstrap, secrets, ingress, and PV backups are proven |

Working decision: Forgejo, Pocket ID, and Infisical should run together in a shared Tier 1 `infra` VM. Because Git, identity, and normal secrets access share a failure domain in this model, recovery design must include external Git mirrors, offline secrets material, local admin accounts, and a bootstrap runbook that does not require this VM to be online.

## Proposed Platform Decisions

### Proxmox vs Bare-Metal Talos

Proposed decision: keep Proxmox on bare metal and run Talos on top.

Why:

- Current hardware already has Proxmox and Ceph in a healthy shape.
- The M90q nodes are well suited to a small Proxmox/Ceph HA substrate.
- Proxmox gives straightforward VM recovery, PBS integration, GPU passthrough, LXC options, and operational familiarity.
- Bare-metal Talos would make the storage story harder for this mixed environment because `meeseeks` is not just a worker node; it is a storage and GPU appliance.

Revisit only if:

- Proxmox becomes an operational burden.
- The desired end state becomes Kubernetes-only.
- Ceph is removed as the VM storage layer.

### Ceph

Proposed decision: keep Ceph limited to the M90q NVMe OSD set for HA infrastructure disks.

Policy:

- Keep replicated size 3 and min_size 2 for critical VM/LXC/Talos disks.
- Treat the current three OSD cluster as HA for one M90q failure, not as general durable backup.
- Do not add `meeseeks` rust disks to this Ceph cluster.
- Keep Ceph, Proxmox migration, and server traffic converged on the existing 10G SFP+ network for now.
- Do not buy dual-SFP+ NICs or additional SFP+ switch capacity just to split Ceph public/cluster traffic unless monitoring shows sustained link saturation, recovery/backfill contention, or latency spikes during client I/O.
- A storage VLAN on the same single physical 10G link is acceptable for policy/QoS/observability, but it should not be expected to materially improve throughput.
- Standardize bridge VLAN ranges and NIC usage across the M90q nodes.

Spare M.2 decision:

- Do not fill the second M.2 slots casually.
- Best use if purchased: add matching NVMe devices to each M90q and create either one additional OSD per host or a separate Ceph pool/device class, depending on whether the goal is capacity, performance, or failure-domain clarity.
- Avoid asymmetric OSD additions. Ceph is easiest to reason about when each M90q has the same number and class of OSDs.

Fourth OSD on `meeseeks`:

- Adding a dedicated 1 TB NVMe OSD to `meeseeks` is now a favored option because `meeseeks` being part of the critical path is acceptable. The main benefit is failure-domain behavior rather than raw capacity.
- The spare healthy 1 TB Kingston NVMe is the preferred device for this OSD, pending capture of exact model, serial, SMART, firmware, endurance, and a quick performance sanity check.
- With three M90q OSD hosts and pool size 3, every object effectively wants all three hosts. If one M90q is down, Ceph can keep serving at min_size 2 but cannot restore full replication until that host returns.
- With a fourth OSD host on `meeseeks`, a one-host failure can re-replicate back to size 3 across the remaining hosts, assuming enough free space and healthy networking.
- Capacity would improve from roughly 3 TB raw to roughly 4 TB raw for that NVMe class, which is only about a 33% raw increase and still roughly 1.3 TB usable at size 3 before reserve.
- The cost is explicit: `meeseeks` becomes part of the critical Ceph data plane. Reboots for GPU/media/storage maintenance would degrade Ceph, and heavy local I/O could contend with OSD work.
- If this path is chosen, use a dedicated NVMe device only. Do not put Ceph on `rust`, `nvmeu2`, or any disk that is also part of the bulk storage design.
- Add it only after the converged 10G network mapping is codified and `meeseeks` is intentionally attached to the Ceph data path.
- Treat `meeseeks` maintenance as cluster maintenance once this OSD exists.

`meeseeks` slot reality:

- `meeseeks` has three onboard M.2 slots, all occupied.
- `PCI-E M.2-M1`: Intel 4 TB, part of `nvmeu2`.
- `PCI-E M.2-M2`: Samsung 970 PRO 512 GB, part of `rpool`.
- `PCI-E M.2-M3`: Intel 4 TB, part of `nvmeu2`.
- A second Samsung 970 PRO 512 GB boot mirror member is installed via `CPU SLOT4 PCI-E 5.0 X8 (IN X16)`, not an onboard M.2 slot.
- Therefore a new OSD requires either additional PCIe adapter capacity or repurposing an existing device.

Preferred `meeseeks` NVMe redesign:

- Replace the two Samsung 970 PRO boot devices with a small boot-only NVMe and a dedicated 1 TB Ceph NVMe.
- Use a 256 GB boot NVMe for Proxmox so the boot device is intentionally too small to become general storage.
- Use the full spare 1 TB Kingston NVMe as a dedicated Ceph OSD if validation passes.
- Keep the two Intel 4 TB NVMe devices dedicated to the `nvmeu2` mirror.
- Retire or repurpose the two Samsung 970 PRO devices outside the critical-path storage plan.

Implications:

- `meeseeks` would no longer have mirrored boot unless another slot/adapter is used for a second boot device.
- This is an acceptable trade if `meeseeks` host configuration is fully rebuildable and backed up, and if boot-device failure downtime is acceptable.
- The Ceph OSD would match the M90q OSD size class more closely than reusing a 512 GB boot mirror member.
- The 256 GB boot disk creates a useful forcing function: host OS only, no VM/app/data sprawl.
- Before doing this, verify Proxmox bootloader/install path, make a fresh backup of host config, document ZFS pool import procedure, and document the rollback path.

Working recommendation:

- Best clean resilience move: replace the current mirrored boot layout with a 256 GB boot-only NVMe plus the spare 1 TB Kingston Ceph OSD NVMe, after converged 10G mapping and drive validation.
- Best no-reinstall move: use additional PCIe capacity for a dedicated 1 TB Ceph OSD and leave mirrored boot intact, if practical.
- Best later capacity/performance move: add matching second OSDs to each M90q.
- Do not put Ceph data on shared-purpose `meeseeks` devices.

Network stance:

- Ceph public and cluster networks currently share the management subnet. This is acceptable for the current small 10G homelab cluster.
- Revisit physical network separation only if measurements show the converged link is the bottleneck during VM I/O, recovery, backfill, PBS jobs, or Talos/Kubernetes storage load.
- Evidence baseline: official Ceph documentation says Ceph works with only a public network in many deployments, especially with faster links, and that a two-network design can improve resilience/performance under high traffic but adds configuration, cost, and management complexity and often may not significantly affect overall performance.

Monitoring requirement:

- Build Grafana or equivalent dashboards for the converged storage network before treating the network decision as "done".
- Track per-host 10G interface utilization, errors, drops, retransmits, and saturation windows.
- Track Ceph client read/write throughput, operation latency, OSD commit/apply latency, slow ops, recovery/backfill state, degraded PGs, and scrub/deep-scrub activity.
- Track Proxmox migration traffic and PBS backup/sync windows so storage-network load can be correlated with planned jobs.
- Alert when Ceph latency or slow ops coincides with high NIC utilization, because that is the signal that a separate physical storage network might be justified.
- Keep dashboard panels that compare normal operation, backup windows, migration windows, and recovery/backfill windows.

### Network And VLANs

Status: provisional. The current VLAN layout is a working draft, not a final decision.

Working direction: use a small set of VLANs, not a large enterprise-style matrix. Every VLAN should earn its existence by having a clearly different trust level, access policy, operational owner, or traffic pattern.

VLAN ID convention:

- Match VLAN ID to the third IPv4 octet where practical.
- Main/default LAN is the exception: it stays untagged/native.
- The Tailscale demo/work VLAN is also an exception and should be preserved as-is.

Revised trust split:

- Freshly joined/default DHCP clients should land on a low-trust/default network, not directly into Trusted or Management.
- Core devices, core VIPs, infrastructure services, and server workloads should not share that fresh-client broadcast domain.
- Management remains a separate admin-only plane.

Recommended layout:

| Network | VLAN ID | Subnet | Purpose | Typical Members | Notes |
| --- | --- | --- | --- | --- |
| Main / Clients | Native/untagged | `10.42.0.0/24` | Fresh/default DHCP clients and normal trusted client devices | Laptops, phones, tablets, default wired clients | Default join network; DHCP-heavy |
| Core / Services | `10` | `10.42.10.0/24` | Core devices, core services, stable service VIPs, infra-facing frontends | Core VIP/DNS/Caddy/NTP, core nodes, selected static infra services | VLAN ID matches third octet |
| Trusted | `13` | `10.42.13.0/24` | Higher-trust personal/admin devices plus server workloads | Your laptop/phone/admin workstation, Proxmox VMs/LXCs, app backends, selected server VIPs | Reduces day-to-day friction by placing your devices and your servers together |
| IoT | `40` | `10.42.40.0/24` | Constrained IoT devices | IoT clients, appliances, ESPHome-class devices if not split later | Default constrained posture; optional future split for trusted/local versus untrusted/vendor IoT |
| Tailscale demo / work | `37` | `192.168.1.0/24` | Preserve work/demo network | Demo clients | Verified in UniFi as network `tsdev` |
| Cameras | `98` | `10.42.98.0/24` | UniFi cameras and NVR paths | Cameras, UniFi NVR | Separate VLAN; cameras should not initiate to Main or Management |
| Management | `99` | `10.42.99.0/24` | Admin-only management plane | Proxmox management, UniFi management, switch/AP management, core node admin, PBS admin | Reachable from trusted admin paths only; no broad client access |
| Guest | `100` | `10.42.100.0/24` | Guest Wi-Fi | Guest clients | Recommended correction because VLAN `99` is already Management; internet-only plus DNS/NTP |
| Kubernetes | TBD/optional | TBD | Talos node and app networking if needed | Talos VMs, ingress/load balancer IPs | Defer unless Talos/IPAM design benefits |
| Storage/Ceph | None initially | N/A | Optional logical separation only | N/A | Do not create initially; converged 10G is the baseline |

Open VLAN design questions:

- Should Main be the normal household/default network, or should freshly joined devices land in a quarantine/low-trust onboarding network?
- Should admin clients and server workloads share `Trusted`, or should personal trusted devices and server workloads be separate networks?
- Should IoT be one constrained network, or split into local-trusted IoT and vendor/cloud-hostile IoT?
- Should the UniFi NVR live inside the camera VLAN, or live in Core/Trusted with explicit access into Cameras?
- Should Management be a fully separate VLAN, or should management isolation rely on Tailscale, SSH jump hosts, and strict firewall rules?
- Should VLAN IDs continue to match the third octet where practical, or should operational clarity and migration ease take priority?
- If the UDM Beast path is adopted, should the design assume gateway-routed VLANs instead of pursuing L3 switch routing?
- Which high-volume flows must avoid inter-VLAN routing entirely: Plex clients, backups, Proxmox/Ceph, NVR/cameras, large file copies, or all of the above?

Implementation rule:

- Preserve the existing Tailscale demo/work VLAN `37` with `192.168.1.0/24`.
- Reset the current IoT per-password/PSK VLAN experiment and rebuild it deliberately.
- Avoid designs where high-volume east/west traffic constantly crosses VLANs through the gateway.
- Prefer placing devices that talk heavily to each other in the same VLAN, or route those VLANs on a capable L3 switch if that becomes necessary.
- Keep DNS reachable from every VLAN that needs local name resolution.
- Keep the management VLAN reachable only from trusted admin devices or Tailscale.
- Keep Main clients, cameras, IoT, and guest networks unable to initiate access into Management.
- Prefer app access from Main through Core/Caddy or explicit service ports rather than broad Main-to-Trusted access.
- Keep Proxmox bridge VLAN allow-lists explicit rather than using `2-4094`, especially on the ConnectX-3 host.

Default network stance:

- The safest model is "default low trust": new or unknown devices land in a constrained network and are promoted to Trusted only when they have a reason to be there.
- The most convenient model is "default Main": household devices land in Main, while known risky classes move to IoT/Guest/Cameras.
- Working compromise: keep native Main as the ordinary household/default client network, but treat it as medium trust, not high trust. Trusted is explicitly promoted.
- If the household workflow can tolerate it, a stronger future posture is to make default Wi-Fi/wired onboarding land in IoT or a quarantine-style client network, then move known devices to Main or Trusted.

Alternative if Guest must be VLAN `99`:

- Management cannot also be VLAN `99`; move Management to another subnet/VLAN such as `10.42.97.0/24` VLAN `97`.

Core/Trusted split:

- Core / Services is for things the network depends on or stable front doors to those things.
- Trusted is for your higher-trust client devices and server workloads.
- Management is for admin interfaces, not user-facing service access.
- A physical host may have more than one role: for example, a Proxmox host can have a Management address on `10.42.99.0/24`, while its guests live on Trusted and its service frontends are exposed through Core/Caddy.

Main / Clients posture:

- Main clients may use core DNS/NTP.
- Main clients may reach selected app frontends through Caddy/Core or explicit allow rules.
- Main clients should not have broad access to Management.
- Main-to-Trusted should be deliberate: allow the ports household users actually need, not the whole subnet.
- Avoid putting high-bandwidth client/server paths across VLANs unless the router/L3 path can handle it. Example: if Apple TVs stream heavily from Plex, either allow that path knowingly and measure it, or place the Plex frontend/media-serving path where it does not hairpin through a slow gateway.

IoT privacy posture:

- Default deny IoT to WAN.
- Default deny IoT to Main, Management, Cameras, Guest, and Kubernetes.
- Allow IoT to core DNS only: the Core DNS VIP on `53/tcp` and `53/udp`.
- Allow IoT to local NTP only: core NTP on `123/udp`.
- Allow specific IoT devices to Home Assistant only when required, using narrow destination IPs and ports.
- Use mDNS/SSDP reflection only if needed for Home Assistant discovery, and scope it as narrowly as UniFi allows.
- Avoid UPnP on IoT.
- Log blocked IoT WAN attempts at a sampled/rate-limited level so privacy-hostile devices are visible without flooding logs.

Camera posture:

- Cameras should reach only the UniFi NVR, core DNS, and core/local NTP unless UniFi Protect requires a specific exception.
- Cameras should not initiate to Main, Management, IoT, Guest, or the Internet by default.
- The NVR may initiate to cameras and may have limited management/update access as required.
- Configuration should be verified in UniFi before cutting cameras over, with a rollback path for adoption or recording issues.

Guest posture:

- Guest should be internet-only.
- Guest clients should be isolated from each other where UniFi supports client/device isolation.
- Guest should use DNS/NTP only as deliberately allowed, and should not reach Main, Trusted, Core app frontends, Management, IoT, or Cameras.

Inter-VLAN performance note:

- Traffic within a VLAN is switched at Layer 2 and does not need to traverse the router/gateway.
- Traffic between VLANs is routed at Layer 3.
- If the UniFi gateway is the only inter-VLAN router, then high-volume inter-VLAN flows can hairpin through the gateway and be limited by gateway routing/firewall performance and uplink speed.
- Current UniFi topology shows `usa-rdu-ucg-fiber` connected to root switch `basement-poe48` over a 2.5G LAN uplink, while most downstream switch-to-switch links are 10G.
- Therefore the current practical inter-VLAN routing path should be assumed to have a 2.5G root uplink constraint unless the LAN uplink is moved to a 10G gateway port or selected VLAN routing is moved to a capable L3 switch.
- This is usually fine at home scale for DNS, web apps, management, and normal control traffic.
- It can matter for bulk transfers, media streaming, backups, storage, or large file copies.
- If this becomes a bottleneck, options are: move chatty devices into the same VLAN, expose the service through a local frontend in the client VLAN, or use a capable L3 switch for selected VLAN routing.

Topology snapshot:

- Current UniFi topology dump: `/Users/alex/git/ib/infra/docs/unifi-topology-dump-2026-05-04.md`

Core switch / L3 routing option:

- The first improvement should be a 10G LAN uplink from `usa-rdu-ucg-fiber` to the root/core switching layer. The current topology uses a 2.5G LAN uplink from gateway port `2` to `basement-poe48` port `48`.
- The UCG-Fiber has multiple 10G-capable ports, including 10G SFP+ and 10GbE RJ45 in the product spec, so the current 2.5G root uplink is likely a topology/port-availability issue rather than a gateway capability limit.
- A UniFi Layer 3 switch can route between VLANs and use a gateway for default internet routing, but networks routed by an L3 switch lose UniFi Traffic Identification features that depend on the gateway path.
- Switch ACLs can manage high-performance inter-VLAN restrictions, but they are a different operational model from gateway firewall policy.
- Do not move untrusted VLANs such as Guest, Cameras, or IoT to L3 switch routing unless the ACL model is explicitly accepted and tested.
- Candidate L3 core devices in the UniFi lineup:
  - `USW-Pro-Aggregation`: best fit for an SFP+/DAC/fiber core; 28x 10G SFP+ plus 4x 25G SFP28, Layer 3. This is the cleanest shape for the current 10G SFP+ topology, but it is currently sold out in the US store.
  - `USW-Pro-XG-24`: best current-buy fallback if availability matters or if more copper 10G is useful; 16x 10GbE RJ45, 8x 2.5GbE RJ45, 2x 25G SFP28, Layer 3.
  - `USW-EnterpriseXG-24`: good only if many 10G RJ45 endpoints are needed; 24x 10GbE RJ45 plus 2x 25G SFP28, Layer 3.
  - `USW-Pro-XG-Aggregation`: high-end/overkill option for 25G-heavy growth; 32x 25G SFP28, Layer 3.
  - `USW-Aggregation`: useful as low-cost 10G fanout, but not a Layer 3 core.
- Working recommendation: do not buy an L3 core switch just to make the VLAN plan work. First, try to make the gateway-to-root uplink 10G and keep high-volume traffic inside Trusted where practical. If buying a core switch anyway, prefer `USW-Pro-Aggregation` if it becomes available; otherwise use `USW-Pro-XG-24` only if the mixed RJ45/SFP28 layout actually matches the physical cabling plan. Revisit L3 switching only if monitoring shows inter-VLAN routing is a real bottleneck.

UDM Beast gateway/NVR consolidation option:

- The `UDM-Beast` could replace the `UCG-Fiber` as the main UniFi gateway and also replace the existing standalone NVR for Protect recording.
- It materially changes the inter-VLAN performance discussion: it is a full UniFi gateway with 25G IDS/IPS, 25G SFP28, 10G SFP+, and 10GbE RJ45 ports, so it can keep routing/firewalling on the gateway while removing the current 2.5G gateway uplink constraint.
- It does not replace a high-port-count SFP+ aggregation switch. It has strong gateway ports, but the switching fabric still needs enough SFP+/SFP28 ports for `basement-poe48`, `basement-agg`, `attic-closet-agg`, `meeseeks`, and future growth.
- For Protect, it is more powerful than the current `UCG-Fiber` and is rated for far more cameras, but it has only two 3.5-inch NVR HDD bays. If the existing NVR is a `UNVR`, replacing it with Beast likely reduces drive bays from four to two; if the existing NVR is a `UNVR-Pro`, it reduces from seven to two.
- For the currently observed camera count, two large drives may be enough, but retention and disk-failure posture must be calculated before replacing the standalone NVR.
- Consolidation benefit: one rack unit can handle Network, Protect, high-throughput routing, VPN, firewall, and storage, with simpler management and fewer boxes.
- Consolidation cost: the gateway and camera recorder now share one failure domain. A Beast outage affects routing/firewall/DHCP control plane and camera recording at the same time.
- The Beast supports Shadow Mode gateway HA, but that requires a second compatible gateway and does not automatically make Protect storage active/active. Treat Protect recovery as restore/migration unless UniFi documentation confirms otherwise for the final deployment.
- Working recommendation: consider Beast as a credible `UCG-Fiber + NVR` consolidation path if rack simplification and gateway throughput matter more than NVR drive-bay count. Do not buy it only as a substitute for an L3 core switch; it should be evaluated as a gateway/NVR architecture change.

ConnectX-3 VLAN note:

- `m90q-2` has a Mellanox `MT27500 Family [ConnectX-3]` using driver `mlx4_en` and firmware `2.36.5150`.
- The card supports VLAN Tx/Rx offload and is not VLAN-challenged.
- The practical quirk is VLAN resource count/filtering, not the numeric height of a small VLAN ID like `98`, `99`, or `100`.
- NVIDIA documents `log_num_vlan` as log2 max VLANs per Ethernet port, range `0-7`, which implies a maximum hardware VLAN filter scale of 128 VLANs per port.
- Current Proxmox config on `m90q-2` allows `bridge-vids 2-4094`, which is broader than needed. The target should use an explicit short VLAN allow-list, for example `10 13 37 40 98 99 100` plus any future Kubernetes VLAN.

Management access options:

| Option | Shape | Pros | Cons | Recommendation |
| --- | --- | --- | --- | --- |
| Admin client on Main plus SSH `ProxyJump` through core | Admin device reaches `core-pi5`/`core-zima` on Main, then jumps to Management hosts | Small firewall surface; auditable SSH path; good break-glass behavior | Less convenient for web UIs unless using SSH tunnels or SOCKS | Preferred default |
| Tailscale subnet routing to Management for tagged admin users only | Tailscale ACLs allow selected users/devices to reach `10.42.99.0/24` | Convenient remote admin; avoids opening Management to Main | Requires disciplined Tailscale ACLs and route approval | Preferred remote-admin path |
| Management web proxy on core Caddy | Caddy exposes selected management UIs behind auth | Convenient browser access; can centralize TLS | Increases blast radius of core proxy; must avoid auth dependency loops | Use sparingly for selected dashboards |
| Direct Main-to-Management firewall allows from specific admin IPs | Static allow rules from trusted client IPs | Simple | Brittle with DHCP/client changes; easier to accidentally broaden | Acceptable for one or two fixed admin machines only |
| Broad Main-to-Management routing | Main can reach management broadly | Convenient | Violates isolation goal | Avoid |

### Talos/Kubernetes

Proposed decision: create a Talos cluster as VMs on Proxmox, backed by Ceph for node disks, but do not make it the default home for every workload on day one.

Starting shape:

- 3 control-plane VMs, one on each M90q node.
- 3 worker VMs, one on each M90q node.
- Optional extra worker on `meeseeks` only for workloads that need the local hardware path and can tolerate being tied to that node.

Initial sizing to validate:

- Control plane: 4 vCPU, 4-8 GiB RAM, 30-50 GiB disk each.
- Workers: 6-8 vCPU, 12-16 GiB RAM, 100-250 GiB disk each.

Storage stance:

- Avoid running a second Ceph cluster inside Kubernetes unless there is a clear need.
- Consider using the existing external Ceph cluster through Ceph CSI for Kubernetes persistent volumes, with a dedicated pool and credentials.
- Use NFS from `meeseeks` only for workloads where node loss behavior is acceptable.
- Keep large media/photos outside Kubernetes unless the app architecture cleanly supports it.

GitOps stance:

- Use Forgejo as the primary Git remote.
- Use Flux or Argo CD for cluster reconciliation.
- Keep a mirror of the GitOps repos outside the home cluster to reduce bootstrap deadlocks.

Adoption stance:

- Use Talos first for stateless apps and small stateful apps whose database/PV backup story is already clear.
- Keep critical Tier 0 outside Talos.
- Keep data-gravity workloads on `meeseeks` until there is a deliberate storage design.
- Promote Talos from "selected workloads" to "default app runtime" only after upgrades, restore drills, ingress, secrets, and PV backups are boring.

### Forgejo

Proposed decision: treat Forgejo as critical Tier 1 infrastructure, not just another app.

Target:

- Run on Proxmox HA-backed storage, probably on Ceph.
- Keep it reachable through a stable local hostname and possibly through the core VIP/reverse proxy.
- Use Postgres with explicit dumps or PBS-aware backups.
- Mirror critical repos to an external Git remote or off-site Forgejo instance.
- Keep bootstrap manifests and recovery notes outside Forgejo as well, such as in an encrypted off-site copy or a small emergency repo mirror.

Placement question:

- The VIP can front Forgejo, but the Forgejo workload should probably stay on Proxmox rather than on `core-pi5`/`core-zima`.

Placement options:

| Option | Pros | Cons | Recommendation |
| --- | --- | --- | --- |
| LXC on Proxmox HA | Lightweight, simple, already working, easy to mount/inspect, low overhead | Container isolation is weaker than a VM; HA behavior can be fussier; Docker-in-LXC adds operational quirks | Acceptable short term |
| Shared NixOS `infra` VM on Proxmox HA | Cleaner PBS backups/restores than LXC, declarative host state, Compose/containers still familiar, groups Forgejo with Pocket ID and Infisical as preferred | Git, identity, and normal secrets access share one failure domain; NixOS recovery familiarity, mirrors, and offline break-glass material become mandatory | Preferred target |
| Talos/Kubernetes | Fully GitOps-native, easy declarative deployment, good if using shared Postgres and mature PV backups | Creates bootstrap loop because GitOps depends on Git; recovery is harder if cluster is down; persistent state must be solved first | Defer until GitOps and backup maturity are proven |
| Core nodes | Keeps Git near DNS/VIP | Overloads Tier 0 and puts mutable app/database state on small edge nodes | Avoid |

Working recommendation:

- Move Forgejo into the shared Tier 1 NixOS `infra` VM on Ceph-backed storage with Pocket ID and Infisical once the current LXC is stable and backed up.
- Use Postgres, either local to the `infra` VM or as a clearly backed-up database service.
- Keep an external mirror of all infrastructure and GitOps repos.
- Keep emergency recovery notes and secrets outside the `infra` VM so bootstrap does not depend on Forgejo, Pocket ID, or Infisical being online.

#### Off-Site Forgejo Mirror

Forgejo federation should not be treated as the answer to off-site recovery yet. Current Forgejo federation is still experimental and is aimed at forge-to-forge interoperability, not complete active/active instance replication.

The practical pattern is repository mirroring plus backup:

- Run a second Forgejo instance off-site, likely on `igloo` or a small VPS.
- Push-mirror critical repositories from home Forgejo to the off-site Forgejo instance.
- Use "sync when new commits are pushed" where available, with periodic sync as a fallback.
- Treat the off-site instance as a warm standby, not an active multi-writer peer.
- Keep the off-site mirror read-only for normal operation to avoid split-brain Git history.
- Do not rely on repository mirrors for a complete Forgejo instance restore. They primarily protect Git refs, branches, tags, and commits.
- Back up the primary Forgejo database, attachments, releases, LFS objects if used, Actions state if needed, and configuration through PBS/app-native database dumps.

Open design choices:

- Off-site location: `igloo` versus VPS.
- Mirror scope: only infrastructure/GitOps repos versus all repositories.
- Mirror transport: SSH deploy keys preferred where possible.
- Promotion process: manual DNS/client remote switch to off-site Forgejo during a home outage.
- Periodic restore test: prove a clone/build/deploy can happen from the off-site mirror without the home `infra` VM.

### Pocket ID

Proposed decision: use Pocket ID for normal OIDC authentication, with local break-glass accounts everywhere critical.

Current product facts to account for:

- Pocket ID supports SQLite and PostgreSQL connection strings.
- Its docs warn against placing the SQLite database on network filesystems such as NFS or SMB.
- Pocket ID has export/import support, but the docs currently label that path experimental.

Target:

- If Pocket ID becomes a critical auth dependency, use PostgreSQL rather than SQLite-on-shared-storage.
- Run it as Tier 1 on Proxmox HA or in Talos with a clear database backup/restore strategy.
- Do not require Pocket ID to access Proxmox, core DNS, backups, or emergency Git recovery.
- Keep session duration and bypass/recovery settings intentionally conservative.
- Protect most private user-facing apps, including Immich and Miniflux.
- Do not force Pocket ID in front of `*arr` apps unless they become internet-exposed or need household-user access.

### Core VIP

Proposed decision: keep the VIP focused on local edge services.

Definitely behind VIP:

- DNS resolver address.
- Local core reverse proxy for critical dashboards.
- Health endpoint.

Possibly behind VIP:

- Forgejo frontend route.
- Pocket ID frontend route.
- Proxmox route, if Caddy can safely proxy it with proper TLS behavior.

Not behind VIP:

- Bulk media services.
- Kubernetes app ingress in general, unless the VIP points to a load balancer that is explicitly part of the app platform.

### Local vs VPS

Proposed decision: local-first, VPS-assisted.

Local responsibilities:

- DNS.
- Auth for local apps.
- GitOps source of truth.
- Proxmox, Ceph, Talos, media, photos, and backups.
- Local monitoring sufficient to diagnose home failures.

VPS responsibilities:

- Public ingress for services that must be reachable externally.
- External status checks and alerting.
- Tailscale/remote access foothold.
- Optional off-site mirror of Git repos or container artifacts.
- Optional public-facing docs/status, not required for home operation.

Avoid:

- Making the VPS the only path to local admin.
- Making home services depend on VPS-hosted identity for normal LAN access.

## Backup And Replication Policy

### Definitions

- Replication: keeps another live or near-live copy. Good for availability. Bad-state can replicate too.
- Backup: point-in-time recovery copy with retention. Good for rollback and disaster recovery.
- Off-site backup: backup copy outside the failure domain of the house.
- Restore test: scheduled proof that a backup can actually produce a working service or readable data.

### Data Classes

| Class | Examples | Availability Target | Backup Target | Notes |
| --- | --- | --- | --- | --- |
| Tier 0 config | AdGuard, Caddy, Keepalived, Chrony | Active/passive core nodes | Git plus file backup | Must be restorable without Kubernetes |
| Git source | Forgejo repos, GitOps manifests | Proxmox HA plus external mirror | PBS plus Git mirror | Avoid bootstrap deadlock |
| Identity | Pocket ID DB/config, OIDC clients | Proxmox HA or Talos plus HA DB | PBS plus app export/dump | Break-glass accounts required |
| Proxmox guests | HA VM/LXC disks | Ceph for selected guests | PBS local and off-site | No backup jobs currently observed |
| Kubernetes state | etcd, manifests, app PVs | Talos HA and storage policy | etcd snapshots plus PV backups | Define before production use |
| Photos | Immich library, DB, uploads | Realistic local availability only | Local snapshots plus off-site | Must optimize for durability |
| Media | Plex media | Local availability | Lower priority off-site or catalog-only | Re-rippable data can have lower tier |
| Secrets | SOPS age keys, backup encryption keys | Local copies | Password manager plus offline copy | Required for disaster recovery |

### Proposed Backup Schedule

This is the starting policy, not final.

| Workload | Local Backup | Off-Site Backup | Retention | Restore Test |
| --- | --- | --- | --- | --- |
| Proxmox HA guests | PBS nightly | Off-site PBS sync or direct remote job | 7 daily, 4 weekly, 12 monthly | Quarterly boot test |
| Forgejo | PBS nightly plus Postgres dump | Off-site PBS and Git mirror | 14 daily, 8 weekly, 12 monthly | Quarterly repo and DB restore |
| Pocket ID | PBS nightly plus DB-native dump/export | Off-site PBS | 14 daily, 8 weekly, 12 monthly | Quarterly login/client restore |
| Core nodes | File backup of `/etc`, AdGuard data, Caddy config | Off-site encrypted file backup | 30 daily, 12 monthly | Semiannual bare-node rebuild |
| Talos cluster | Machine config in Git, etcd snapshots | Off-site encrypted copy | 7 daily, 4 weekly, 12 monthly | Quarterly cluster rebuild drill |
| Immich DB/appdata | App-consistent DB dump plus filesystem snapshot | Off-site encrypted copy | 14 daily, 8 weekly, 12 monthly | Quarterly album/photo restore |
| Photos/media | ZFS snapshots | Off-site replication for irreplaceable data | TBD by capacity | Annual sample restore |

PBS policy:

- Run a local PBS target at home for fast restores.
- Run the off-site PBS as a VM on `igloo`.
- Put the `igloo` PBS datastore on `igloo`'s `z2tank`, not just on the VM boot disk.
- Sync from the local PBS to the off-site PBS on `igloo`, unless a later design proves direct dual-target backups are preferable.
- Use client-side encryption for off-site backup material.
- Schedule prune, garbage collection, and verification jobs.
- Reverify all backups at least monthly.
- Keep backup encryption/master recovery keys outside the systems being backed up.

PBS topology:

| Layer | Role | Location | Purpose |
| --- | --- | --- | --- |
| Local PBS | Primary restore target | Home Proxmox environment, exact placement TBD | Fast restores, frequent verification, short recovery loop |
| Off-site PBS | Disaster recovery target | `igloo` VM backed by `z2tank` | Survive home-site loss, ransomware blast radius, major operator mistakes |

Remaining PBS design choices:

- Local PBS placement: dedicated VM on Ceph, dedicated storage on `meeseeks`, or another local dataset.
- Local PBS datastore size and retention.
- Off-site VM disk model: large zvol attached to the PBS VM, bind/virtiofs-style access to a host dataset, or another explicitly supported datastore presentation.
- Sync direction: local PBS pushes to `igloo` or `igloo` pulls from local PBS.
- Access path: Tailscale-only unless there is a strong reason to expose PBS another way.
- Capacity boundary: `igloo` PBS datastore must coexist with existing `zrepl` data on `z2tank`.

### Off-Site Failure Recovery On `igloo`

Decision: use PBS as the off-site recovery mechanism, with a documented failure recovery plan. Do not use native Proxmox storage replication to `igloo`.

Why:

- Proxmox storage replication is designed for guests using local ZFS storage inside a Proxmox cluster.
- The home Tier 1 target uses Ceph-backed VM disks, so native Proxmox ZFS replication does not directly apply.
- Making `igloo` a member of the home Proxmox cluster over Tailscale/WAN would put corosync and quorum across a latency/jitter-sensitive link. That is the wrong failure domain for this design.
- Even where Proxmox storage replication fits, it is scheduled replication and can lose changes since the last successful sync during failover.

Preferred pattern:

- Keep `igloo` as a separate Proxmox host or separate site, not a member of `homeprod`.
- Run PBS on `igloo` with its datastore on `z2tank`.
- Back up Tier 1 VMs from home to PBS.
- Define emergency VM restore settings for `igloo` in Terraform/OpenTofu, Ansible, or a written runbook.
- For selected services, periodically test-restore the latest backup onto `igloo` under a non-conflicting VMID and isolated network.
- During a real home outage, promote the restored VM manually by attaching the correct network, changing DNS/Tailscale routes, and starting the service.

Service-specific stance:

- `infra` VM: warm restore candidate on `igloo`, plus Forgejo repository mirrors for faster Git-only recovery.
- Home Assistant: restore candidate if remote operation is useful, but local house devices may not be reachable from `igloo` without VPN/routing work.
- Monitoring: good off-site candidate because it can continue observing home reachability from outside.
- Immich/Plex/media services: not good warm-standby candidates unless the underlying media/photo datasets are also available at `igloo` with a clear promotion model.

Failure recovery plan requirements:

- List the services eligible for off-site restore.
- Record each VMID, expected restored VMID on `igloo`, CPU/RAM/disk expectations, and required network attachment.
- Record the PBS datastore, namespace, encryption key location, and restore credentials.
- Record DNS/Tailscale changes needed to promote the off-site copy.
- Record which services are allowed to be restored read/write and which must be read-only.
- Include a demotion plan for returning service to home after the outage.
- Test at least one restore path on a schedule and record the result.

This gives off-site disaster recovery without turning the off-site node into part of the home HA cluster.

## Desired Build Phases

### Phase 1: Decide And Document

- Accept or edit this document.
- Answer the open questions.
- Decide service tiers and data classes.
- Decide exact names, VLANs, domains, and VIP scope.

### Phase 2: Stabilize The Substrate

- Standardize Proxmox node naming, DNS, and `/etc/hosts` resolution for all nodes.
- Standardize bridges/VLAN ranges across Proxmox nodes.
- Decide whether Ceph gets a dedicated network/VLAN.
- Add Proxmox backup jobs.
- Add off-site PBS plan and first test restore.

### Phase 3: Make Critical Services Durable

- Finalize core VIP services.
- Harden Forgejo placement, backup, and external mirror.
- Decide Pocket ID database and placement.
- Ensure break-glass accounts and recovery secrets exist.

### Phase 4: Build Talos Declaratively

- Replace old `dev/proxmox/talos-*` assumptions with `homeprod` nodes and storage.
- Use the BPG Proxmox provider unless there is a reason to keep Telmate.
- Generate Talos machine configs from code.
- Bootstrap Flux or Argo CD from Forgejo plus an external mirror fallback.

### Phase 5: Migrate Workloads By Tier

- Move stateless apps first.
- Move moderate stateful apps only after PV/backups are proven.
- Leave media/photos/GPU-heavy services on `meeseeks` until there is a separate design for them.
- Decommission old Compose placements only after restore and rollback paths exist.

## Open Questions

### Resolved Inputs

| Original Topic | Current Answer |
| --- | --- |
| Availability target | Critical services should be up as much as possible and self-healing. |
| Physical network | 10G SFP+ end-to-end through UniFi. |
| VLAN appetite | Yes, a small set, including management and cameras. |
| Main/client subnet | Fresh/default DHCP clients should land on native/untagged Main at `10.42.0.0/24`. |
| Core/services subnet | Use `10.42.10.0/24` for Core/Services, VLAN `10`; candidate core VIP `10.42.10.53`. |
| Trusted subnet | Use `10.42.13.0/24` for Trusted, VLAN `13`, containing your higher-trust devices and server workloads. |
| Management subnet | Use `10.42.99.0/24` for Management, VLAN `99`. This conflicts with Guest VLAN `99`, so Guest should move if Management remains VLAN `99`. |
| Work/demo VLAN | Preserve existing Tailscale demo/work VLAN `37`, subnet `192.168.1.0/24`, verified in UniFi as `tsdev`. |
| IoT VLAN setup | Reset the current PSK/VLAN experiment and rebuild deliberately. Use VLAN `40`, subnet `10.42.40.0/24`, with constrained/privacy-first posture. |
| Camera VLAN | Use VLAN `98`, subnet `10.42.98.0/24`, and migrate UniFi cameras/NVR deliberately with rollback. |
| Guest VLAN | Recommended correction is VLAN `100`, subnet `10.42.100.0/24`, because VLAN `99` is Management. |
| Management access | Prefer Main-to-core SSH `ProxyJump` and Tailscale ACL-based access to Management over broad Main-to-Management firewall holes. |
| ConnectX-3 VLAN handling | Avoid broad Proxmox `bridge-vids 2-4094` on the ConnectX-3 host; use an explicit short VLAN allow-list. Numeric VLAN IDs `10`, `13`, `37`, `40`, `98`, `99`, and `100` are not themselves the issue. |
| Ceph/storage network | Keep Ceph/storage converged on the existing 10G SFP+ network initially. A storage VLAN on the same link is optional for policy/observability but not expected to improve throughput. Do not buy dual-SFP+ NICs or more SFP+ switch ports unless metrics show contention. |
| Storage performance monitoring | Grafana or equivalent dashboards must track 10G utilization, Ceph latency/slow ops, recovery/backfill, Proxmox migration, and PBS windows so the converged-network decision can be revisited with evidence. |
| `meeseeks` quorum | Keeping `meeseeks` in Proxmox quorum is fine. |
| `meeseeks` critical path | `meeseeks` being a critical-path device is acceptable. |
| Ceph shape | Current three-M90q Ceph baseline is acceptable. Spare M.2 slots are available for a deliberate future expansion. |
| Off-site PBS | PBS should run as a VM on `igloo` in the tailnet. |
| Auth scope | Auth wanted for most private apps like Immich and Miniflux; `*arr` apps do not need Pocket ID by default. |
| Core services | DNS/AdGuard Home, possible Unbound, core VIP, Caddy, Tailscale subnet router/exit node, NTP, NUT/UPS monitoring, and secrets break-glass material. |
| Core Tailscale | Both `core-pi5` and `core-zima` may advertise subnet routes and exit-node capability. |
| Core VIP shape | One fixed VIP on the Core / Services VLAN is acceptable for DNS and Caddy if each service binds distinct ports on the shared VIP. Candidate: `10.42.10.53`. |
| DHCP | DHCP remains on the UniFi firewall. |
| Tier 1 apps | Home Assistant OS, Forgejo, Pocket ID, Immich, Plex, and Infisical should be up as much as possible on Proxmox/Ceph or the appropriate `meeseeks`-bound path rather than on the low-power core nodes. |
| Tier 2 apps | Miniflux, Nextcloud, Paperless-ngx, `*arr`, downloads, and general personal apps should live in their own Tier 2 VM/runtime group, with backups where state matters. |
| VM grouping | Forgejo, Pocket ID, and Infisical should share a Tier 1 `infra` VM. Monitoring should avoid sharing the same failure domain as the services it observes. |
| NixOS standardization | NixOS is the standard for non-appliance Linux hosts and VMs unless an exception is documented. Existing `ironicbadger/nix-config` provides the foundation. Use NixOS to declare host state, while keeping app packaging mostly Compose/containers. |
| Nix deployment model | Prefer Forgejo runner-driven deploys for normal NixOS changes, using raw `nixos-rebuild`, deploy-rs, Colmena, or wrappers after testing. The laptop is bootstrap/break-glass. Use pull-based GitOps mainly for Kubernetes, not as a mandatory pattern for Tier 0 NixOS hosts. |
| Apple Silicon build constraint | The Mac should orchestrate NixOS deploys but Linux closures should build on explicit Linux targets/builders. Pin every NixOS host platform and avoid inheriting `aarch64-darwin` into Linux configs. |
| Monitoring | Important and should alert on core/cluster/backup failures, but not a core service yet. |
| Backup alerting | PBS backup failures older than 24 hours should alert/page unless explained by known maintenance or `igloo` link trouble. |
| PBS topology | Use a local PBS target for fast restores and an off-site PBS on `igloo` for disaster recovery. |
| Off-site recovery | Use PBS sync/restore plus a documented failure recovery plan. Do not use native Proxmox storage replication to `igloo`. |
| Cameras | Camera recording stays with UniFi NVR; camera VLAN should be designed. |

### Next Decision Batch

These are the next decisions that matter before implementation.

1. Should Pocket ID use PostgreSQL from day one?
2. What should the final VLAN trust model be: default household Main, quarantine-first onboarding, separate Trusted clients and servers, one IoT network or split IoT, NVR inside or outside Cameras, and Management VLAN versus Tailscale/SSH-only isolation?
3. Should Talos start as a small "selected workloads" cluster instead of the default destination for all apps?
4. Flux or Argo CD?
5. Should Kubernetes persistent volumes use external Ceph RBD for selected apps, or should we avoid Kubernetes state until the backup path is proven?
6. Where should local PBS live: Ceph-backed VM, `meeseeks`-backed VM, or another dedicated local storage path?
7. Should local PBS push to `igloo`, or should `igloo` pull from local PBS?
8. What retention target do you want for irreplaceable data like photos: 30/90/365 days, longer monthly history, or capacity-limited?
9. How often are you willing to run restore drills: monthly, quarterly, or twice a year?

## External References

- Pocket ID environment variables and database options: https://pocket-id.org/docs/configuration/environment-variables
- Pocket ID export/import: https://pocket-id.org/docs/setup/data-export-import
- Forgejo repository mirrors: https://forgejo.org/docs/v15.0/user/repo-mirror/
- Forgejo federation FAQ: https://forgejo.org/faq/#what-about-forge-federation
- Forgejo federation configuration warning: https://forgejo.org/docs/latest/admin/config-cheat-sheet/#federation-federation
- Forgejo backup guidance in upgrade docs: https://forgejo.org/docs/next/admin/upgrade/#backup
- Proxmox Backup Server documentation: https://pbs.proxmox.com/docs/
- PBS maintenance, prune, garbage collection, and verification: https://pbs.proxmox.com/docs/maintenance.html
- PBS client-side encryption and restore guidance: https://pbs.proxmox.com/docs/backup-client.html
- Proxmox VE storage replication: https://pve.proxmox.com/wiki/Storage_Replication
- Proxmox VE cluster/corosync network requirements: https://pve.proxmox.com/pve-docs/chapter-pvecm.html
- Ceph network configuration reference: https://docs.ceph.com/en/latest/rados/configuration/network-config-ref/
- Ceph architecture and replication write path: https://docs.ceph.com/en/latest/architecture/
- NVIDIA MLNX_EN mlx4/ConnectX-3 driver documentation: https://docs.nvidia.com/networking/display/mlnxenv495100/introduction
- UDM Beast product page: https://store.ui.com/us/en/category/cloud-gateways-large-scale/products/udm-beast
- UDM Beast technical specifications: https://techspecs.ui.com/unifi/cloud-gateways/udm-beast
- UCG-Fiber technical specifications: https://techspecs.ui.com/unifi/cloud-gateways/ucg-fiber
- UniFi Protect supported camera limits: https://help.ui.com/hc/en-us/articles/360063280653-UniFi-Protect-Supported-Camera-Limits
- UniFi Network Video Recorder technical specifications: https://techspecs.ui.com/unifi/cameras-nvrs/unvr
- UniFi Network Video Recorder Pro technical specifications: https://techspecs.ui.com/unifi/cameras-nvrs/unvr-pro
- Flatcar Container Linux documentation: https://www.flatcar.org/docs/latest/
- uCore project: https://github.com/ublue-os/ucore
- NixOS manual: https://nixos.org/nixos/manual/
- NixOS "How Nix Works": https://nixos.org/guides/how-nix-works/
- GNU Guix manual: https://guix.gnu.org/manual/en/
- Fedora CoreOS auto-updates and rollback: https://docs.fedoraproject.org/en-US/fedora-coreos/auto-updates/
- openSUSE MicroOS: https://microos.opensuse.org/
- Ubuntu Core documentation: https://documentation.ubuntu.com/core/
- Bottlerocket: https://bottlerocket.dev/
- Kairos documentation: https://kairos.io/docs/
- TrueNAS SCALE virtualization and apps: https://www.truenas.com/docs/scale/24.04/gettingstarted/configure/vmandappconfigscale/
- Harvester documentation: https://docs.harvesterhci.io/
- VyOS CLI and configuration model: https://docs.vyos.io/en/latest/cli.html
- nixos-anywhere documentation: https://nix-community.github.io/nixos-anywhere/
- nixos-anywhere repository: https://github.com/nix-community/nixos-anywhere
- disko repository: https://github.com/nix-community/disko
- deploy-rs repository: https://github.com/serokell/deploy-rs
- Colmena deployment options: https://colmena.cli.rs/0.3/reference/deployment.html
- Forgejo Actions overview: https://forgejo.org/docs/latest/user/actions/overview/
- Forgejo runner installation: https://forgejo.org/docs/next/admin/runner-installation/
- NixOS automatic upgrades: https://wiki.nixos.org/wiki/Automatic_system_upgrades
- Cachix Deploy documentation: https://docs.cachix.org/deploy/index.html
- Hercules CI effects documentation: https://docs.hercules-ci.com/hercules-ci/effects/
- Attic binary cache documentation: https://docs.attic.rs/
- Garnix CI documentation: https://garnix.io/docs/ci/
- Debian releases: https://www.debian.org/releases/
- Arch Linux overview: https://wiki.archlinux.org/title/Arch_Linux
- Existing Nix config repository: https://github.com/ironicbadger/nix-config
