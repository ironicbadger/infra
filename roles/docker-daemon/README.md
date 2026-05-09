# Docker Daemon

Host-agnostic Docker daemon fixes for Proxmox 9 hosts.

## DNS

Docker containers inherit daemon DNS behavior, but Proxmox hosts often have a
host-oriented resolver stack: Tailscale MagicDNS, systemd resolver stubs, search
domains, or local DNS services that are valid for the host but fragile inside
containers.

Set `docker_daemon_config.dns` to stable LAN resolvers so containers can resolve
public and internal names without adding DNS overrides to each compose service.

## AppArmor

Proxmox 9 ships with AppArmor enabled, and Docker applies the `docker-default`
profile to containers by default. Some workloads hit AppArmor 4/kernel policy
edge cases, especially around Unix sockets and process-internal helper threads.
That can look like DNS, networking, or application health failures even when the
network path is otherwise fine.

Docker does not expose a daemon.json switch to disable AppArmor globally. When
`docker_daemon_disable_apparmor` is true, this role keeps Docker's default
profile name but installs it as `flags=(unconfined)`, then loads it with
`apparmor_parser`. Containers still report `docker-default`, but the profile no
longer enforces policy.

## Variables

- `docker_daemon_config`: rendered directly to `/etc/docker/daemon.json`.
- `docker_daemon_disable_apparmor`: installs an unconfined `docker-default`
  AppArmor profile for Docker containers.
