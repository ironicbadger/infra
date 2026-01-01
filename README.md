# infra (core rebuild)

This repo is the clean-slate core infrastructure rebuild, aligned with `plan.md`.

Focus: **edge DNS + VIP** on the core nodes (Zimaboard + Pi 5) with boring, reproducible Ansible.

## Layout

- `inventory/` - hosts and vars
- `playbooks/` - playbooks for core nodes
- `roles/` - minimal, local roles (network, chrony, adguard, keepalived)
- `files/` - declarative config artifacts (AdGuard Home)
- `legacy/` - previous repo structure, preserved for reference

## Quick start

1) Update `inventory/hosts.ini` with hostnames/IPs.
2) Set variables in `inventory/group_vars/core.yaml` and per-host files in `inventory/host_vars/`.
3) Copy `files/adguardhome/AdGuardHome.yaml.example` to `files/adguardhome/AdGuardHome.yaml`, replace it with your exported AdGuard config, then set `adguard_config_src` in `inventory/group_vars/core.yaml`.
4) Run the playbook:

```bash
just core <host>        # apply to a single host
just core-all           # apply to all core nodes
```

## Notes

- The VIP is health-gated on the AdGuard service.
- DNS config is treated as a deployed artifact.
