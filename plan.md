# Home Network Rebuild – LLM-Friendly Summary

## Objective

Rebuild a home network from a **clean slate** (“nuke and pave”) with:

- Minimal single points of failure
- **DNS always available**, even if Kubernetes / Proxmox / storage nodes are down
- Declarative, reproducible configuration
- Clear separation between **recovery-critical infrastructure** and **experimental workloads**

The design favors **boring, predictable core services** and flexibility at the edge.

---

## Core Principles

1. **DNS is foundational**
   - DNS must not depend on Kubernetes, Ceph, or large storage hosts
   - DNS must survive reboots, upgrades, and breakage elsewhere

2. **Stable client contracts**
   - Clients receive **one DNS IP**
   - That IP must always work
   - Failover must be transparent to clients

3. **Decouple concerns**
   - DNS answers names
   - Ingress/reverse proxy routes traffic
   - App location (k8s, Docker, VM, bare metal) is an implementation detail

4. **Boring core, flexible lab**
   - Core infra is simple and stable
   - Kubernetes is where experimentation happens

---

## Hardware Roles

### Edge Nodes (outside Kubernetes)
- Raspberry Pi 5 (PoE)
- Raspberry Pi 4 **or** Zimaboard

Responsibilities:
- DNS + ad blocking
- DoH
- VIP ownership (VRRP via keepalived)
- Nothing else

These nodes must be:
- Always on
- Low power
- Independent from k8s and storage

---

### Kubernetes Cluster
- 3× Lenovo M720q (Talos)
- Optional Talos VM with GPU on c137 (non-core workloads only)

Responsibilities:
- Ingress / reverse proxy
- Platform services
- Applications

---

### Legacy / Data Nodes
- c137: Proxmox + ZFS + large storage + Docker
- MS-01: Proxmox + Home Assistant VM + misc services

---

## VIP (Virtual IP) Model

- Use **VRRP** (via keepalived)
- One **VIP** represents DNS (e.g. `10.0.0.53`)
- Only one node owns the VIP at a time
- Backup node automatically takes over in ~1–3 seconds if the master fails
- Clients never change configuration

**Why VIP instead of multiple DNS IPs:**
- Client DNS failover is unreliable
- VIP gives a single stable contract

**Health-gated VIP ownership:**
- Node only claims VIP if DNS service is healthy
- Prevents blackholing DNS

---

## Time Synchronization

- Use **chrony** on each edge node
- Sync directly to public NTP pools
- No local NTP server required

Rationale:
- VRRP does not require tight clock sync
- TLS / DoH require correct time
- Local NTP adds unnecessary dependency and failure coupling

---

## Base OS Choice

- **Debian 13 (trixie)** recommended for edge nodes
  - Stable networking
  - Predictable behavior
  - Minimal surprises during recovery

(NixOS is viable if used carefully, but Debian is preferred for first-pass nuke-and-pave.)

---

## DNS Service Choice

### AdGuard Home
- Commonly used in multi-node setups
- No native clustering
- Correct HA model is **config replication**, not shared runtime state

What must be synced:
- DNS rewrites
- Blocklists
- Upstream resolvers
- Policies

What is NOT synced:
- Cache
- Logs
- Statistics

**Recommended sync model:**
- Treat AdGuard config as a deployed artifact
- Push identical config to all nodes
- Restart service on change (DNS disruption is minimal and masked by VIP)

(Technitium DNS was discussed as an alternative due to native clustering, but AdGuard + declarative config is acceptable and common.)

---

## Rebuild Phases

### Phase 0 – Decisions
- Choose internal domain (e.g. `home.arpa`)
- Define IP plan (static IPs + DNS VIP)
- Create a new repo with no legacy config

---

### Phase 1 – Edge Rebuild (DNS + VIP)
1. Install Debian 13 on edge nodes
2. Configure static networking
3. Enable chrony time sync
4. Install and configure keepalived (VRRP)
5. Install AdGuard Home (fresh)
6. Make AdGuard config declarative
7. Switch DHCP to hand out DNS VIP
8. Test failover (power loss, reboots)

**Success condition:**  
DNS works even if Kubernetes, Proxmox, or storage nodes are down.

---

### Phase 2 – Front Door (Ingress)
- Deploy ingress controller in Kubernetes
- DNS wildcard points to ingress, not a specific host
- Ingress routes to:
  - k8s services
  - Docker on c137
  - VMs (Home Assistant, Proxmox UIs, etc.)

---

### Phase 3 – Gradual Evolution
- Migrate stateless apps to k8s
- Keep large state on ZFS/c137 initially
- Optionally add auth (Authelia/Authentik)
- Optionally add ingress HA (kube-vip or external LB)

---

## Non-Goals

- No DNS inside Kubernetes
- No shared storage for DNS state
- No big-bang app migration
- No service mesh
- No “clever” HA where boring works better

---

## Mental Model

> **DNS and VIP are infrastructure you recover *with*.**  
> **Kubernetes is infrastructure you experiment *on*.**

Never invert that dependency.
