# Lychee MariaDB Upgrade

Date: 2026-06-24

Service: `ktz-lychee-db`

Upgrade:

- From: `mariadb:10.8.2-focal`
- To: `mariadb:11.8.8`
- `MARIADB_AUTO_UPGRADE=1` is enabled so the official image runs `mariadb-upgrade` when the upgraded container first starts.

Backups taken before the compose change:

- Host: `ktz-cloud`
- Directory: `/opt/appdata/ktz-lychee/backups/mariadb-10.8-to-11.8-20260624T132128Z`
- Logical Lychee DB dump: `lychee.sql.gz`
- Stopped datadir archive: `ktz-lychee-db-datadir.tar.gz`

Validation performed:

- `gzip -t lychee.sql.gz`
- `tar -tzf ktz-lychee-db-datadir.tar.gz`
- Containers were restarted on the old `mariadb:10.8.2-focal` image after the backup and the DB responded to `mariadb-admin ping`.
- The upgraded container started as `mariadb:11.8.8`.
- `mariadb-upgrade` started and finished successfully in the container logs.
- `/opt/appdata/ktz-lychee/db/mariadb_upgrade_info` reports `11.8.8-MariaDB`.
- `ktz-lychee` was restarted after the DB upgrade and reported healthy.

Notes:

- The logical dump was taken with the Lychee application DB user and excludes routines/events because the old system table lookup for `mysql.proc` returned error `1728`. The stopped datadir archive is the full raw MariaDB fallback.
- If rollback is needed before the upgraded DB is trusted, stop `ktz-lychee` and `ktz-lychee-db`, restore `/opt/appdata/ktz-lychee/db` from `ktz-lychee-db-datadir.tar.gz`, set the image back to `mariadb:10.8.2-focal`, and start the stack.
