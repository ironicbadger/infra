# Proxmox VM Provisioning

This repo creates Proxmox VMs. It does not build NixOS images and it does not
configure NixOS hosts.

Ownership split:

- `infra`: Proxmox endpoint details, VM IDs, clone-time CPU/memory/disk/network
  metadata, Caddy routes, and non-NixOS Ansible-managed infrastructure.
- `ironicbadger/nix-config`: NixOS template builds, NixOS host definitions,
  NixOS services, users, firewall policy, secrets, and deployment workflows.

The NixOS Proxmox template referenced here is an external input. Build and
promote it from `ironicbadger/nix-config`; then use this repo to create VMs
from that template.

## Commands

```sh
just vm list-templates
just vm list-configs
just vm create forgejo
```

VM declarations live in:

```text
nix/data/vms.nix
```

Proxmox connection details and external template IDs live in:

```text
nix/data/proxmox.nix
```

For NixOS VMs, the next step after `just vm create ...` is a deploy from
`ironicbadger/nix-config`.
