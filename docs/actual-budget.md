# Actual Budget

- URL: https://actual.m.wd.ktz.me (private LAN/tailnet access through Traefik).
- Compose service: `actual-budget` in `services/appnv/06-apps/compose.yaml`.
- Host/project: `appnv`, project `root`, `/root/compose.yaml`.
- Data: `/mnt/nvmeu2/appdata/apps/actual-budget/data:/data`.
- Official image: `actualbudget/actual-server:26.9.0`, pinned by digest.

Use the existing deployment workflow from an up-to-date infra checkout:

```sh
just compose appnv
ssh root@appnv 'docker compose -p root -f /root/compose.yaml up -d --no-deps actual-budget'
```

The first command renders the host Compose configuration; the second applies
only Actual. Review host configuration drift before regenerating the full file.
For upgrades, update the pinned version/digest after reviewing release notes
and taking a backup. Never delete or replace the data directory during an update.

Existing Tailscale Serve listeners on 8443 and 9443 are unchanged.
The former standalone Compose file is retained as
`/opt/actual-budget/compose.yaml.adopted`; do not start a second deployment.

The custom backup, bank-sync, restore-test and Hermes monitoring jobs from #97
have been removed. Existing protected backups, keys, credentials and cache data
are retained; no automated backup or bank-sync job is configured by this change.
