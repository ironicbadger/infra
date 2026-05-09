# Infrastructure Plan: Human Summary

This is the readable version of the infrastructure plan. The long architecture document is still the detailed source for implementation, edge cases, and LLM context. This file is for quickly remembering what we are trying to build, why, and what decisions are still open.

## The Short Version

The goal is to rebuild the homelab around the desired end state, not keep bending new plans around old accidents.

The target shape is:

- Proxmox remains the bare-metal platform.
- Ceph remains the HA storage layer for cluster workloads.
- `meeseeks` remains an important data/hardware node, not something we pretend is generic.
- Two low-power core nodes keep the house recoverable when the main cluster is sick.
- NixOS becomes the default OS for non-appliance Linux hosts and VMs.
- Apps mostly run as containers/Compose on NixOS VMs, not as hand-mutated Debian pets.
- Forgejo and runners become the normal deployment control plane.
- The laptop remains bootstrap and break-glass, not the daily deploy path.
- PBS exists locally for fast restores and off-site on `igloo` for disaster recovery.

The big principle: make the normal system declarative, but make emergency recovery boring.

## What Matters Most

Some services need to survive Proxmox, Ceph, Talos, or app-stack trouble. These are "core" services, and they should live on the small core nodes:

- DNS and ad blocking, probably AdGuard Home.
- Optional Unbound for recursive/caching DNS.
- A shared VIP for core services.
- Caddy for local reverse proxy entry points.
- Tailscale subnet router and exit node.
- NTP.
- NUT/UPS monitoring.
- Break-glass access material.

The core layer exists so the house can still resolve names, reach recovery paths, use Tailscale, and diagnose the cluster when the main platform is down.

Everything else can be important without being core. Home Assistant, Forgejo, Pocket ID, Infisical, Immich, Plex, monitoring, and backups are Tier 1, but they can sit on Proxmox or `meeseeks` with proper HA/backups/runbooks.

## Hardware Reality

The cluster is not abstract cloud capacity. It has real shape.

The three M90q nodes are the symmetrical Proxmox/Ceph base. They are good candidates for HA VMs, Talos VMs, and cluster services. They have 10G links and 1 TB NVMe Ceph OSDs.

`meeseeks` is different. It has the GPU, media/data gravity, large local storage, and can be part of quorum and even critical path. But services tied to `meeseeks` should be described honestly as `meeseeks`-bound, not fake cluster-HA.

The current direction for `meeseeks` storage is:

- Replace the mirrored 970 PRO boot setup with a small boot-only NVMe.
- Use the spare healthy 1 TB Kingston NVMe as a dedicated Ceph OSD if validation passes.
- Keep the Intel 4 TB NVMe mirror for local VM/app/media-adjacent storage.
- Accept that the disks are not enterprise PLP drives and mitigate with UPS, backups, monitoring, and restore drills.

## Runtime Model

The runtime model has shifted to NixOS-first.

NixOS is now the default for:

- Core nodes.
- Important app VMs.
- Tier 2 app VMs.
- Runner/build/deploy VMs.
- Most Linux systems where host state belongs in Git.

Exceptions are explicit:

- Proxmox stays Proxmox.
- Talos is only for Kubernetes nodes.
- Home Assistant OS stays HAOS.
- PBS stays PBS.
- Debian/Ubuntu remain fallback options when vendor docs, GPU/media tooling, or urgent recovery makes NixOS a bad trade.
- Flatcar, uCore, Fedora CoreOS, MicroOS, and similar immutable container hosts are parked as lab ideas unless they clearly beat NixOS for a specific job.

The important distinction is:

NixOS owns the machine. Compose or containers own the application packaging.

That means we are not trying to package every app as a beautiful native Nix module on day one. NixOS should declare users, SSH keys, firewall, mounts, packages, Docker/Podman, Compose systemd units, backups, exporters, timers, and bootstrap secrets. The app itself can still be a boring container stack.

## Deployment Model

Daily deployment should come from Git, not from the laptop.

The preferred model is Forgejo runner-driven deployment:

- Code/config lands in Git.
- Forgejo Actions runners run checks.
- Runners build Nix closures on Linux builders or targets.
- Runners push to a binary cache.
- Runners deploy approved changes using `nixos-rebuild --target-host`, deploy-rs, Colmena, or a wrapper.

The laptop remains the emergency path. It should have a checkout, credentials, and the ability to deploy manually, but it should not be required for normal work.

There should be a separate `runner-control` NixOS VM. The only deploy runner should not live inside the same `infra` VM it may need to deploy or recover.

Runner roles should be separated:

- `check`
- `build-x86`
- `deploy-tier2`
- `deploy-tier1`
- `deploy-core`

Core deploys need manual approval and one-node-at-a-time rollout.

## Apple Silicon Build Problem

The Mac should orchestrate Nix, not build Linux production systems.

Every NixOS host must pin its platform:

- x86 VMs and `core-zima`: `x86_64-linux`
- `core-pi5`: `aarch64-linux`
- Macs: `aarch64-darwin`

Linux closures should build on Linux:

- On the target.
- On a Proxmox x86 Nix builder VM.
- On an aarch64 Linux builder if needed later.
- In Linux CI.

The Mac can evaluate and trigger deploys, but we should avoid letting `aarch64-darwin` leak into Linux configs.

## Avoiding NixOS Lockouts

NixOS deploys can lock you out if SSH, firewall, network, Tailscale, DNS, or VIP config changes badly. This needs first-class protection.

Risky changes should use a safe-switch pattern:

1. Confirm direct SSH, Tailscale, and console/PiKVM/serial paths.
2. Capture the current NixOS generation.
3. Schedule a rollback guard.
4. Apply with `nixos-rebuild test` first.
5. Validate SSH, Tailscale, DNS, Caddy, NTP, NUT, and VIP behavior.
6. Switch only after the test is good.
7. Cancel rollback only after validation passes.
8. Do not touch the second core node in the same step.

Firewall changes should be additive first and restrictive later. Do not combine first-time VLAN/interface migration with a lockdown.

## App Placement

Proposed VM/runtime groups:

- `core-pi5` and `core-zima`: NixOS core nodes for DNS, Caddy, Keepalived, Tailscale, NTP, NUT.
- `infra`: NixOS VM for Forgejo, Pocket ID, Infisical, and small supporting DBs if not externalized.
- `runner-control`: NixOS VM for Forgejo runners and deploy tooling.
- `monitoring`: NixOS VM for Grafana, VictoriaMetrics/Influx, alerting, exporters.
- `haos`: Home Assistant OS VM on Proxmox HA/Ceph.
- `pbs-local`: local PBS appliance VM with datastore placement still to decide.
- `immich`: likely `meeseeks`-adjacent NixOS VM unless the storage design changes.
- `plex`: `meeseeks`-bound because media and hardware acceleration live there.
- `apps`: NixOS VM for Tier 2 apps like Miniflux, Nextcloud, Paperless-ngx, etc.
- `media-ops`: NixOS VM near `meeseeks` for `*arr`, downloads, and related services.
- `talos-*`: Talos VMs for selected Kubernetes workloads later.

VM boundaries should follow failure domains, not service count. One VM per service is too much overhead unless the service has a distinct restore, security, hardware, or lifecycle need.

## Git, Identity, And Secrets

Forgejo, Pocket ID, and Infisical are useful enough to be Tier 1, but they also create bootstrap traps.

The `infra` VM can contain all three, but then we must not depend only on that VM to recover:

- Critical repos need external mirrors.
- GitOps/deployment repos need off-site copies.
- Break-glass secrets must exist outside Infisical.
- Local admin accounts must exist outside Pocket ID.
- Recovery notes must be available without Forgejo.

Forgejo federation is not the answer for live off-site recovery. The practical answer is repo push mirrors plus proper backups of Forgejo database/config/attachments/LFS/actions where relevant.

## Network And VLANs

VLANs are explicitly not final.

The current draft is provisional:

- Main/default clients.
- Core/services.
- Trusted.
- IoT.
- Tailscale demo/work VLAN.
- Cameras.
- Management.
- Guest.
- Optional Kubernetes.
- No dedicated storage/Ceph VLAN initially.

The important rule is that every VLAN must earn its existence. A VLAN should represent a real trust boundary, access policy, operational owner, or traffic pattern. Otherwise it is just complexity.

Open VLAN questions:

- Do fresh devices land in Main or quarantine?
- Do your trusted devices share a network with servers?
- Is IoT one network or split into local-trusted and vendor-hostile?
- Does the NVR live in Cameras or Core/Trusted with access into Cameras?
- Is Management a real VLAN or mostly Tailscale/SSH jump access?
- Do high-volume flows like Plex, backups, NVR, and file copies need to stay within one L2 domain?

The current UniFi topology has a practical bottleneck: gateway to root switch is 2.5G while much of the downstream switching is 10G. Before buying an L3 core switch, first try to get the gateway/root uplink to 10G.

The UDM Beast is a credible gateway/NVR consolidation option, but it is not a full aggregation switch replacement. It also combines gateway and camera recording into one failure domain and only has two NVR drive bays.

## Ceph And Storage

The plan is to keep Ceph converged on the existing 10G network for now.

A separate storage VLAN on the same physical link does not create more bandwidth. A physically separate storage network would need more NICs and switch ports. That may be worth it later, but not without measurements.

Monitoring should track:

- 10G link utilization.
- Ceph latency.
- Slow ops.
- Recovery/backfill.
- Proxmox migrations.
- PBS backup windows.

Do not optimize the storage network based on vibes. Measure first.

## Backups And Replication

Replication is not backup.

Ceph protects against disk/node failure. It does not protect against deletion, bad deploys, ransomware, database corruption, or operator mistakes.

The backup shape is:

- Local PBS at home for fast restores.
- Off-site PBS on `igloo` for disaster recovery.
- PBS sync/restore plan, not native Proxmox replication to `igloo`.
- Restore drills, not just backup jobs.

Important state needs app-consistent backups:

- Forgejo database/config/repos/LFS/actions as relevant.
- Pocket ID database/export.
- Infisical recovery material.
- Immich database and photo library.
- Home Assistant backups.
- NixOS config repo and SOPS/age keys.
- PBS encryption keys.

If backups fail for more than 24 hours, that should alert unless it is planned maintenance.

## Talos And Kubernetes

Talos is still useful, but it is not the default destination for everything.

Talos should run as VMs on Proxmox, backed by Ceph for node disks. It should start with selected workloads:

- Stateless apps.
- Small stateful apps with proven backups.
- Ingress/cert/platform experiments.
- Workloads that benefit from Kubernetes reconciliation.

Do not move critical stateful apps into Kubernetes until PV backup, restore, secrets, ingress, and cluster rebuilds are boring.

Flux or Argo CD is still undecided.

## What Is Mostly Decided

- Proxmox remains the hardware/VM platform.
- Ceph remains the HA VM storage layer.
- `meeseeks` is allowed to be critical path.
- NixOS is the default non-appliance OS.
- Compose/containers are acceptable on NixOS.
- Forgejo runners should become the normal deployment path.
- Laptop is break-glass, not daily deploy.
- Core services live on `core-pi5` and `core-zima`.
- Forgejo, Pocket ID, and Infisical share the Tier 1 `infra` VM.
- PBS exists locally and off-site.
- Off-site recovery uses PBS restore/runbooks, not live Proxmox replication.
- VLANs remain provisional.

## What Is Still Open

The biggest unresolved questions:

1. Final VLAN trust model.
2. UCG-Fiber plus 10G uplink versus UDM Beast versus L3 aggregation.
3. Exact local PBS placement and datastore.
4. PBS sync direction: local pushes to `igloo` or `igloo` pulls.
5. Flux versus Argo CD.
6. How soon Talos should host real workloads.
7. Whether Kubernetes uses external Ceph RBD for PVs.
8. Pocket ID database choice, likely PostgreSQL if it is critical.
9. Immich storage/runtime shape.
10. Restore drill cadence and retention targets.

## Recommended Next Moves

Do these in order:

1. Create a sacrificial NixOS VM and prove ground-up rebuild with `nixos-anywhere` plus `disko`.
2. Build a safe-switch wrapper for NixOS deploys with rollback guard and health checks.
3. Stand up `runner-control` and prove Forgejo runner-driven deploy to the sacrificial VM.
4. Decide the final VLAN policy from an access matrix, not from subnet aesthetics.
5. Fix or test the UniFi 10G gateway/root uplink before buying L3 switching.
6. Decide local PBS placement.
7. Convert one core node to NixOS, probably `core-zima`, and prove failover.
8. Build the `infra` VM as NixOS plus Compose.
9. Add monitoring and backup alerts early, not after everything is migrated.

## The North Star

The perfect end state is not "everything is Kubernetes" or "everything is Nix" or "everything is HA."

The perfect end state is:

- The house keeps working during failures.
- The important services self-heal where realistic.
- The state of machines is visible in Git.
- Normal changes deploy from Forgejo runners.
- Backups are real because restores are tested.
- Data gravity is respected.
- Emergency access does not depend on the thing that is broken.

That is the system to build toward.
