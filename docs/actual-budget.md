# Actual Budget on appnv

Primary URL: **https://actual.m.wd.ktz.me**. Traefik Docker labels use the
existing `websecure` entrypoint and Cloudflare DNS certificate resolver.
An Actual-specific IP allowlist admits the existing trusted LAN
`10.42.0.0/21`, Tailscale IPv4/IPv6 ranges, and localhost. No forwarded-header
trust is enabled. This grants network access, not permission to a budget;
set the Actual server password before storing financial data.
The existing tailnet-only `https://appnv.ktz.ts.net:9443/` remains a fallback.
The unrelated Tailscale Serve listener on `8443` is unchanged. No Funnel.

## Deployment and updates

Run from the infra repository with its normal Ansible, SOPS/age and SSH setup:

```sh
just actual
```

This invokes `playbooks/actual-budget.yaml`, the existing Compose generator,
and local operational roles. The fragment lives in
`services/appnv/11-actual-budget/compose.yaml`, so `just compose appnv` also
includes it. The scoped entrypoint renders only Actual, validates the live
`/root/compose.yaml`, and replaces only the Actual service. It deliberately
preserves unrelated live service definitions because the live host and main
branch currently differ. The root Compose document may be serialized as JSON,
which is valid YAML and accepted by Docker Compose.

The original standalone project was adopted into project `root`, service and
container `actual-budget`. The original data bind mount remains
`/mnt/nvmeu2/appdata/apps/actual-budget/data:/data`. Only the old container was
replaced; no volumes or data were removed. Its standalone Compose file is
retained as `/opt/actual-budget/compose.yaml.adopted`, not an active deployment.
The unexecuted Hermes backup draft is superseded, not scheduled.

Server and API are pinned to **26.9.0**. Server digest:
`sha256:552beab3dec8c93d46b8b9245612d63c3f123b8a45063a474f53e229b17621d3`.
The API image builds from that base and an npm lockfile. To upgrade, review the
official release/migration notes, update both server references (`compose.yaml`
and `operate.py`), the sync Dockerfile, API dependency and lockfile, and the
runner image tags. Run the tests below, deploy with `just actual`, and repeat
restore, HTTPS and import/idempotence checks. Every deployment takes an
encrypted cold backup and runs an isolated restore before replacing Actual.
Do not downgrade against a migrated database; restore the matching backup and
matching pinned version if rollback is required.

## Secure setup — Alex must complete

1. Open the private HTTPS URL and set the initial server password. Create or
   import the budget, enable budget encryption if desired, and retain the
   encryption password in your password manager.
2. Enroll with the paid third-party SimpleFIN service and authorize each bank
   in its secure interface. Claim its setup token through Actual's SimpleFIN
   setup UI. Never paste passwords, setup/access tokens or account data into
   chat, Git, deployment variables, shell arguments, or logs.
3. Link each supported account to its correct Actual account. Check coverage
   **per account type**, using a private checklist. Keep unsupported accounts as
   manual/CSV accounts. No payment, transfer, or rule automation is installed.
4. In your own interactive terminal, run:

   ```sh
   ssh -t root@appnv /opt/actual-budget-ops/setup.py
   ```

   All inputs use hidden prompts. Supply the server password, budget Sync ID
   (Settings → Advanced), encryption password if enabled, and only the linked,
   authorized SimpleFIN Actual account IDs. IDs can be taken from each account's
   URL in Actual. The atomic result is root-only
   `/etc/actual-budget/config.json`, outside Git. No SimpleFIN token is needed
   by the job: Actual stores that server-side.
5. Run `ssh root@appnv /opt/actual-budget-ops/operate.py verify-imports`.
   Inspect imports securely in Actual against the institutions. This command
   verifies all configured accounts, requires imported transactions, runs a
   second sync, and requires identical transaction IDs/counts with no duplicate
   imported IDs. If new upstream transactions arrive between runs, review and
   repeat; the command fails conservatively. It never logs financial details.
6. Repeat a backup and isolated restore after real data exists. An initial
   restore of an uninitialized server cannot prove recovery of your encrypted
   budget or real transactions.

Keep the institution/account-type coverage checklist privately, outside Git.
Coverage and import acceptance must be recorded per account; neither bank-wide
coverage nor support for liability accounts should be assumed. All requested
account types remain unverified until secure enrollment and import testing.

Bank-sync credentials are stored server-side by Actual. Budget end-to-end
encryption does **not** protect those credentials. The API cache contains
decrypted budget material: it is root-only under `/var/lib/actual-budget-sync`.
Server data, cache, configuration and backups must remain protected. Docker
logging is disabled for both server and runner; SDK stdout/stderr are discarded.
Traefik access logging/tracing are disabled for this router. Operational records
contain only fixed statuses, timestamps, and per-account status positions.

## Scheduling and failures

Host timezone: America/New_York. Persistent systemd timers run encrypted backup
daily at 03:00 and bank sync at 06:00, each with up to ten minutes of jitter.
An isolated restore runs Sundays at 04:00. `/run/lock/actual-budget.lock` prevents
overlap across backup, restore, adoption and sync. A contending invocation exits
75; it does not run another SDK process. Run jobs manually if a contention
skipped a scheduled run. Overdue runs alert through monitoring.

The official API sequence is `init`, `downloadBudget(syncId, {password})`,
`runBankSync({accountId})` for each configured account, `sync`, `shutdown`.
The tagged implementation throws collected bank errors but returns no detailed
success report. The runner also checks SimpleFIN linkage, closed state, fresh
`last_sync`, and `bank_sync_status === 'ok'`. One failed account fails the whole
run; successful accounts are still synced. Exception text is never logged.

Hermes polls every five minutes and sends allowlisted operational alerts through
the existing **Gilfoyle Telegram bot**, using `hermes -p gilfoyle send`.
Bot credentials stay on Hermes. Changes alert immediately on the next poll;
unresolved failures repeat daily. Recovery alerts are sent once. A missing
configuration alerts as setup required, not as successful sync. Failed/overdue
backup, restore, sync and backup-copy checks also alert. Hermes itself being
offline cannot send Telegram; monitor its availability separately.

```sh
ssh root@appnv systemctl start actual-budget@backup.service
ssh root@appnv systemctl start actual-budget@restore.service
ssh root@appnv systemctl start actual-budget@sync.service
ssh root@appnv journalctl -u 'actual-budget@*' --since today
ssh root@hermes systemctl start actual-budget-monitor.service
```

Run these sequentially. To reauthenticate, open Actual and SimpleFIN securely,
repair the affected authorization, and relink only if instructed by the provider.
Do not create a duplicate Actual account. If server/encryption passwords or the
Sync ID changed, rerun `setup.py`. Run `verify-imports` again and confirm the
recovery alert. Unsupported accounts require CSV/manual reconciliation.

## Backup and restoration

The thirty most recent complete encrypted archives are retained on appnv in
`/var/lib/actual-budget-backups`, copied with SHA-256 verification to
Hermes `/var/lib/actual-budget-monitor/backups` (also thirty). These are
separate-host copies, not a claimed off-site disaster-recovery system.

Only Actual stops for the cold snapshot. The archive streams directly into
age encryption, then Actual restarts even if archive/encryption fails. Partial
archives are never promoted or used for retention. Each archive contains the
complete server data, a file-hash manifest, the pinned Actual Compose fragment,
and sync configuration if present. The API cache is recoverable from the server
and is not backed up. Neither the full unrelated root Compose configuration nor
the host backup private key is included in the archive.

Archives encrypt to two recipients: the existing repo SOPS recovery recipient
and a generated root-only appnv key `/etc/actual-budget/backup-key.txt`, used for
automated restore tests. Keep the existing SOPS identity securely backed up
outside appnv/Hermes; its local configured path is
`~/.config/sops/age/keys.txt`. Recovery was tested using this off-host identity
against an encrypted archive copied from Hermes.

`operate.py restore [archive-path]` decrypts under a temporary root-only directory,
verifies every archived data-file hash and SQLite `quick_check`, boots a disposable
container with **no network and no published ports**, probes HTTP from inside it,
then removes only that test container and its scratch directory. It cannot access
banks or production data. Use this command routinely; it does not perform a
production rollback.

For a deliberate production restore, first stop the sync/backup/restore timers
and acquire the same operation lock. Take a fresh backup if possible. Decrypt a
chosen archive into a root-only staging directory with `age -d -i KEY ARCHIVE`,
using a pipeline into `tar -xz -C STAGING`; never put the key in an argument or
write plaintext into a shared directory. Test the archive in isolation first.
Stop only `actual-budget`, **rename** the current data directory to a protected
rollback directory on the same filesystem, and put the staged `data` directory
at the exact original bind path. Retain the rollback directory until acceptance
passes. Restore `config.json` with mode 0600 only if needed. Use the archived
server version through the repo workflow; start only the Actual service in
project `root`. Check HTTPS, unlock the encrypted budget, and reconcile securely
before reenabling timers. Never run `docker compose down -v`, restore over an
active database, or start a second production instance.

## Validation

```sh
node --test roles/actual-budget/tests/logic.test.mjs
python3 -m unittest discover -s roles/actual-budget/tests
ansible-playbook playbooks/actual-budget.yaml --syntax-check
```

Full completion additionally requires trusted TLS, private-access denial tests,
one production container in project `root`, unchanged bind storage and `8443`,
successful encrypted backup/isolated restore/restart persistence, Telegram
delivery, and **real authorized imports plus a duplicate-free second sync for
every supported account**. Infrastructure passing alone is not completion.

References: [Docker](https://actualbudget.org/docs/install/docker/),
[API](https://actualbudget.org/docs/api/reference/),
[tagged API implementation](https://github.com/actualbudget/actual/blob/v26.9.0/packages/loot-core/src/server/api.ts),
[SimpleFIN setup](https://actualbudget.org/docs/advanced/bank-sync/simplefin/).
