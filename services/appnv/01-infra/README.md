# Arcane

Arcane is available through Traefik at `https://arcane.m.wd.ktz.me`.
Its database and project data persist in `/mnt/nvmeu2/appdata/apps/arcane`.
It uses the host Docker socket to manage appnv containers.

Before deploying to a fresh host, create the encryption key once on appnv:

```sh
sudo mkdir -p /mnt/nvmeu2/appdata/apps
sudo sh -c 'umask 077; test -f /mnt/nvmeu2/appdata/apps/arcane.env || { printf "ENCRYPTION_KEY="; openssl rand -hex 32; } > /mnt/nvmeu2/appdata/apps/arcane.env'
```

Keep this file with the application backups; do not rotate it casually or
commit its contents. The Compose service loads it using `env_file`.

Render the configuration with `just compose appnv`, then start only Arcane:

```sh
ssh root@appnv.ktz.ts.net 'docker compose -f /root/compose.yaml up -d --no-deps arcane'
```

Existing containers are visible through Docker. The Ansible-managed
`/root/compose.yaml` is not mounted as an editable Arcane project.

## Remote environments

`meeseeks` and `immich-app` run `ghcr.io/getarcaneapp/agent:latest` as
`arcane-agent`. Each connects outbound to this manager over HTTPS using
edge polling; no host port is published. Arcane may show **Standby** while
an agent is idle and **Online** when its tunnel is active.

| Environment | Agent data directory | Token file |
| --- | --- | --- |
| meeseeks | `/mnt/nvmeu2/appdata/apps/arcane-agent` | `/mnt/nvmeu2/appdata/apps/arcane-agent.env` |
| immich-app | `/mnt/appdata/apps/arcane-agent` | `/mnt/appdata/apps/arcane-agent.env` |

The token files contain `AGENT_TOKEN=...`, are mode `0600`, and stay on their
respective hosts. Preserve them with the agent data when backing up.
To rebuild, create an Edge environment in Arcane, save its generated token
in the corresponding file, render the host's Compose configuration, and run
`docker compose -f /root/compose.yaml up -d --no-deps arcane-agent` there.
For API-based provisioning, set `isEdge: true` and use `edge://meeseeks` or
`edge://immich-app` for `apiUrl`; an empty URL prevents container proxying.
