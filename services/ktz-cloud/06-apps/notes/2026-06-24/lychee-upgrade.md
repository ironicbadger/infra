# Lychee v7 Upgrade

Date: 2026-06-24

Service: `ktz-lychee`

Upgrade:

- From: `lycheeorg/lychee:v6.10.2`
- To: `ghcr.io/lycheeorg/lychee:v7.6.2`
- The v7 container uses FrankenPHP on port `8000`, so Traefik now points at container port `8000`.
- The v6 `/conf`, `/uploads`, `/sym`, `/logs`, and `/lychee-tmp` mounts were replaced with the v7 `/app/...` mount layout.
- `/sym` is intentionally no longer mounted because Lychee v7 removed the symlink storage feature.
- `APP_KEY` was copied from the old v6 `.env` into a local secret file and mounted through `APP_KEY_FILE`.

Backups taken before the compose change:

- Host: `ktz-cloud`
- Directory: `/opt/appdata/ktz-lychee/backups/lychee-v6.10.2-to-v7.6.2-20260624T132841Z`
- Logical Lychee DB dump: `lychee.sql.gz`
- Stopped MariaDB datadir archive: `ktz-lychee-db-datadir.tar.gz`
- Stopped Lychee v6 app/upload/config archive: `ktz-lychee-app-v6.tar.gz`

Host-side files/directories prepared for v7:

- `/opt/appdata/ktz-lychee/app/config/app-key`
- `/opt/appdata/ktz-lychee/app/storage-app`

Validation performed before upgrade:

- `gzip -t lychee.sql.gz`
- `tar -tzf ktz-lychee-db-datadir.tar.gz`
- `tar -tzf ktz-lychee-app-v6.tar.gz`
- Existing v6 containers were restarted after the backup.

Post-upgrade checks:

- The container is using `ghcr.io/lycheeorg/lychee:v7.6.2`.
- `ktz-lychee` reports healthy.
- Startup logs show `php artisan migrate --force` ran and the app became ready.
- `docker exec ktz-lychee curl -fsS http://localhost:8000/up` returned HTTP `200`.
- `https://gallery.ktz.cloud/` returned HTTP `200` through Traefik.
- The v7 album precomputed-field maintenance commands completed for 14 albums:
  - `docker exec ktz-lychee php artisan lychee:recompute-album-sizes`
  - `docker exec ktz-lychee php artisan lychee:recompute-album-stats`
- `QUEUE_CONNECTION=sync` and the `jobs` table had `0` pending jobs after the maintenance commands.

Rollback notes:

- Stop `ktz-lychee`.
- Restore `/opt/appdata/ktz-lychee/app` from `ktz-lychee-app-v6.tar.gz`.
- Restore the DB from either `lychee.sql.gz` or `ktz-lychee-db-datadir.tar.gz`.
- Set the image and mounts back to the v6 compose layout, then start the stack.
