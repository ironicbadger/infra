# ironicbadger/tailscale-routes-fix

An Ansible role to override the routing table on Linux once `--accept-routes` is specified on a network with more than one subnet router. This causes an infinite loop and loss of connectivity on the local LAN IP.

Usage as part of an Ansible playbook:

```
---
  - hosts: example
    roles:
      - role: ironicbadger.tailscale-routes-fix
```

This presupposes you have added the role as git submodule to your Ansible repo. See [ironicbadger/infra](https://github.com/ironicbadger/infra) for more details there (check the `justfile` for a git submodule helper command).

The role exposes two default values for customization:

+ `tailscale_routes_fix_lan_subnet` - the local subnet of the box in question (the local IP that stopped working)
+ `tailscale_routes_table` - specifies the routing table that should be used to look up routes for traffic matching destination subnet. Appropriate values are `local` or `main` (defaults to `main`).
