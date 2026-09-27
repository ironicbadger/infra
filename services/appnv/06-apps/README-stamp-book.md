# Stamp Book

URL: https://stampbook.wd.ktz.me

`stamp-book.yaml` is merged into `/root/compose.yaml` on appnv by the
Compose generator. It uses the existing `root` project and Traefik network.
AdGuard rewrites on core-pi5 and core-zima point the hostname at 10.42.1.111;
the source record is in `files/adguardhome/AdGuardHome.yaml`.

## Storage

Dedicated dataset on meeseeks: `nvmeu2/appdata/apps/stamp-book`, mounted at
`/mnt/nvmeu2/appdata/apps/stamp-book` and exposed to appnv through its existing
appdata virtiofs mount. SQLite and uploads live in `data/` (UID 1000).
The initial deployment imported 438 records from the image's vault.
Do not rerun the import during routine updates.

Provisioning commands for a fresh installation (run ZFS commands on meeseeks):

```sh
zfs create -o atime=off nvmeu2/appdata/apps/stamp-book
```

Then on appnv, create `data/` owned by 1000:1000 and a root-owned, mode-0700
`secrets/` directory. Store the issued OIDC secret as
`secrets/oidc-client-secret`, owned by 1000:1000 with mode 0400. The secret
is not stored in Git. Preserve the entire dataset when backing up/restoring.
Pre-release snapshots: `@pre-v1.1.0-20260927`, `@pre-v1.1.1-20260927` and
`@pre-v1.1.2-20260927`; existing zrepl retention manages older snapshots.

## Authentication

Issuer: `https://idp.ktz.ts.net`. Client name: `Stamp Book (appnv)`.
Exact callback: `https://stampbook.wd.ktz.me/auth/oidc/callback`.
Client authentication: `client_secret_post`, authorization code flow with PKCE.

The running issuer emits Alex's subject as `userid:58536423898758261`.
The prefix is required: the bare numeric Tailscale user ID is rejected.
Cat is also allowed as `userid:5480194786358962`. They share one collection,
and new revisions record the editor's name and stable identity. Reading is unauthenticated;
there is no application password.

## Operations

On appnv:

```sh
cd /root
docker compose pull stamp-book
docker compose up -d --no-deps stamp-book
docker compose ps stamp-book
```

First installation only, after mounting the dataset and configuring the secret:

```sh
docker compose run --rm stamp-book npm run web:import -- --vault vault --data /data
```

Verified 2026-09-27: trusted HTTPS, container health, discovery from the Docker
network, complete tsidp login, authenticated catalogue access (438 records),
logout, and matching DNS answers from both AdGuard servers.

## Versioned updates and recovery

Production is pinned to v1.1.2 and its registry digest. Every startup creates a
verified SQLite + uploads snapshot before migrations, retaining the last seven
successful startup snapshots under `data/backups/`. Manual release backups are
in `manual-backups/` and are outside that rotation. Migration failure or failed
backup verification prevents startup. Never rerun import to repair an upgrade.

Recovery instructions: https://github.com/ironicbadger/ktz-usa-stamp-tracker/blob/main/docs/web-app/releases.md
Restore into a separate empty directory and change the data bind only after
verification; preserve the original database and WAL.

The pre-1.1.0 production backup was restored in an isolated container, migrated,
and compared field-for-field across all nine original tables. The dataset is
included in recursive appdata zrepl jobs, but replication health must be checked.
A separate pre-upgrade archive is retained on igloo under
`/z2tank/backups/stamp-book-manual/`.

The v1.1.2 homepage shares the reader shell, starts directly with book progress,
and places the sun/moon icon beside Edit mode in the top navigation. Desktop and
320px mobile navigation were checked; there is no horizontal overflow.

Replication verified (2026-09-27): igloo's appdata job completed and the received
dataset exists at `z2tank/backups/meeseeks/data/nvmeu2/appdata/apps/stamp-book`.
The manual pre-1.1.0 and pre-1.1.1 archives on igloo were verified independently.
Snowball is still unreachable and is not a second verified replica.
