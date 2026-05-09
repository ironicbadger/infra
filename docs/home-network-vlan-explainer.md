# Home Network VLAN Explainer

This is the simple version of the network plan.

Think of VLANs like rooms in a house. Devices in the same room can easily talk to each other. Devices in different rooms have to go through a doorway. The firewall decides who can pass through each doorway and what they are allowed to access.

The goal is not to make the network painful to use. The goal is to keep normal devices, servers, cameras, IoT devices, guests, and admin interfaces from all living in one giant room.

## Proposed Networks

| Network | VLAN | Subnet | Who Lives There |
| --- | ---: | --- | --- |
| Main | Native/untagged | `10.42.0.0/24` | Normal/default household devices |
| Core | `10` | `10.42.10.0/24` | DNS, Caddy, NTP, core nodes |
| Trusted | `13` | `10.42.13.0/24` | My laptop/phone/admin devices and servers |
| IoT | `40` | `10.42.40.0/24` | Smart devices, ESPHome, appliances |
| Cameras | `98` | `10.42.98.0/24` | Cameras and NVR-related devices |
| Management | `99` | `10.42.99.0/24` | Proxmox, UniFi, switch/AP admin interfaces |
| Guest | `100` | `10.42.100.0/24` | Guest Wi-Fi |

## Main

Main is the normal/default network. If a regular device joins the house Wi-Fi or plugs into a normal network port, it lands here.

This is for things like Apple TVs, normal phones, tablets, casual laptops, and other household devices.

Main should be able to use normal services, such as Plex, Immich, Home Assistant, DNS, and web apps. Main should not be able to access infrastructure admin interfaces, SSH ports, databases, Proxmox, switch management, or backup systems.

Main is not the same as "fully trusted." It is more like "normal household trust." Devices can be promoted into Trusted when they need more access.

## Core

Core is the small utility room.

It holds things the rest of the network depends on:

- DNS
- Caddy / reverse proxy
- NTP / time
- Core VIP, likely `10.42.10.53`
- Core Pi/Zima nodes

Almost every network needs to talk to Core for DNS and possibly web entry points. Core should stay small and boring. Random apps should not live here.

## Trusted

Trusted is the workbench.

This is where my own trusted devices and server workloads live:

- My laptop
- My phone
- Admin workstation
- Proxmox VMs/LXCs
- Server app backends
- Internal services I actively work on

This is the main usability compromise. Instead of separating my laptop from my servers and then writing firewall exceptions all day, they live together in Trusted.

Trusted can access more than Main. It can reach server apps, Git, dashboards, SSH where appropriate, and selected management paths.

## Management

Management is the locked wiring closet.

It is for admin interfaces only:

- Proxmox host management
- UniFi management
- Switch/AP management
- Proxmox Backup Server admin
- Other infrastructure admin surfaces

Normal devices should not reach this network. Even Trusted should reach it deliberately, ideally through Tailscale ACLs, SSH ProxyJump, or very specific firewall rules.

Management is not for Plex, Immich, Forgejo, or normal app traffic. It is for controlling the infrastructure.

## IoT

IoT is the playpen.

IoT devices are inconsistent. Some are nice local devices like ESPHome. Others are vendor cloud devices that phone home constantly, show ads, or stop getting updates.

The IoT network keeps those devices away from laptops, servers, cameras, and management interfaces.

IoT usually gets:

- DNS to Core
- NTP/time to Core
- Specific Home Assistant access when needed
- Internet only by explicit choice or per-device exception

We may later split IoT into "local/trusted IoT" and "vendor/untrusted IoT", but one IoT VLAN is easier to maintain initially.

## Cameras

Cameras get their own network because cameras are special.

They should generally talk only to:

- UniFi NVR
- DNS
- NTP

Cameras should not browse the LAN, talk to Proxmox, reach laptops, reach servers, or access the internet unless a specific UniFi Protect requirement needs it.

## Guest

Guest is simple: internet-only.

Guest devices should not reach Main, Trusted, Management, IoT, Cameras, or internal services.

Guest devices should also be isolated from each other if the Wi-Fi/controller supports client isolation.

## Inter-VLAN Traffic

Traffic inside one VLAN is switched locally. It does not need to go through the router.

Traffic between VLANs is routed. If the gateway/router is the only thing routing between VLANs, traffic may have to go from a switch to the router and back again. This is sometimes called router-on-a-stick.

At home scale, that is usually fine for DNS, web apps, management, dashboards, and normal control traffic.

It can become a problem for high-bandwidth traffic:

- Media streaming
- Backups
- Large file copies
- Storage traffic
- VM migration
- Anything that constantly pushes lots of data between VLANs

That is why the plan should avoid splitting devices that constantly talk to each other unless there is a clear security reason.

For example, if Apple TVs stream heavily from Plex, we should make sure that path is either fast enough through the router or designed so it does not become an avoidable bottleneck.

If inter-VLAN routing becomes a bottleneck, the fixes are:

- Put chatty devices in the same VLAN.
- Route selected VLANs on a capable Layer 3 switch.
- Expose services through a frontend that avoids unnecessary cross-VLAN bulk traffic.
- Stop segmenting that specific path if the security benefit is not worth the performance cost.

## Traffic Rules

The rough policy:

| From | To | Allowed? |
| --- | --- | --- |
| Main | Core DNS/NTP | Yes |
| Main | Caddy/app frontends | Yes |
| Main | Trusted apps | Only selected ports/services |
| Main | Management | No |
| Trusted | Core | Yes |
| Trusted | Server apps | Yes |
| Trusted | Management | Yes, but deliberately |
| IoT | Core DNS/NTP | Yes |
| IoT | Home Assistant | Only needed ports/devices |
| IoT | Internet | Default no, or per-device exception |
| Cameras | NVR/DNS/NTP | Yes |
| Cameras | Everything else | No |
| Guest | Internet | Yes |
| Guest | Internal networks | No |

## Why This Is Useful

The point is not to stop an Apple TV from watching Plex.

The point is to let the Apple TV reach Plex without also giving it access to:

- Proxmox
- UniFi admin
- SSH on servers
- Databases
- Backup systems
- Switch/AP management
- Camera networks
- Admin devices

The same applies to guest phones, random IoT plugs, TVs, and compromised cameras.

## Why This Should Stay Maintainable

This only works if every VLAN has a clear reason to exist.

The current plan has a job for each network:

- Main: normal clients
- Trusted: my trusted devices and servers
- Core: shared network services
- Management: admin-only interfaces
- IoT: constrained devices
- Cameras: camera isolation
- Guest: internet-only

That is about the maximum complexity that makes sense for a home network. More VLANs should only be added when there is real operational pain.

The default network posture can also be tightened over time.

The strictest model is: unknown devices land in IoT or a quarantine-style network, then get promoted to Main or Trusted.

The more convenient model is: normal household devices land in Main, and obviously risky devices move to IoT, Cameras, or Guest.

The current plan is the convenient model, with the option to move toward default-low-trust later.

## Guiding Principle

Trusted gets convenience.

Main gets normal app access.

IoT, Cameras, and Guest get containment.

Management gets protection.

Core gets stability.
