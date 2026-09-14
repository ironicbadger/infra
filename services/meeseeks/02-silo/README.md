# Silo on meeseeks

The compose generator merges this stack with Jellyfin into `/root/compose.yaml`:

```sh
just compose meeseeks
ssh root@meeseeks 'docker compose -f /root/compose.yaml up -d --wait silo'
```

Open http://meeseeks:8090 to complete onboarding. Jellyfin-compatible clients use
port 8097; Audiobookshelf-compatible clients use port 13378.

Media is mounted read-only under `/mnt/media`: `movies`, `tv`, `audiobooks`,
`books`, and `comics`. Select library subdirectories such as
`/mnt/media/movies/library`, `/mnt/media/movies/kids`, `/mnt/media/tv/library`,
`/mnt/media/tv/kids`, and `/mnt/media/tv/documentaries` during setup.

Persistent state lives under `/mnt/nvmeu2/appdata/mediaservers/silo`. Database and
Redis ports are not published. PostgreSQL is capped at 2 GiB with Silo's automatic
host-wide tuning disabled so it can coexist with Jellyfin.

Secrets are in `group_vars/meeseeks.sops.yaml`, encrypted with the repository's
age recipient. Preserve that file and the age private key separately from database
backups: losing `silo_secret_key` makes Silo's encrypted credentials unrecoverable.
Back up PostgreSQL with `pg_dump`; filesystem snapshots alone are not a logical
database backup. Silo is pre-release; take a database backup before pulling updates.

Deployment reference: https://siloserver.org/docs/deployment/docker/
