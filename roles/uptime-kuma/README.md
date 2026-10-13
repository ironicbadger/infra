# Private app status on ktz-cloud

Deploy through the infrastructure playbook:

```sh
just run ktz-cloud --tags uptime-kuma
```

The role generates the normal host Compose file and deploys `uptime-kuma` and its shared Traefik proxy.
The service definition is in `services/ktz-cloud/02-infra/compose.yaml`; the image
is pinned by digest. Persistent database storage is local at
`/opt/appdata/apps/uptime-kuma`, not an NFS mount. Include it in host backups.

The initial status page is https://status.apps.glowbug.io/ and the administrator
UI is https://status.apps.glowbug.io/dashboard. Both require Tailscale. DNS has an
explicit `status.apps` A record to ktz-cloud's Tailscale address, overriding the
wildcard pointing to appnv. ktz-cloud's own Traefik obtains and renews its separate
DNS-01 certificate. Its router applies an IP allowlist using the connection's
source address, without trusting a client-supplied forwarded-for header.
A systemd unit prevents Tailscale subnet-route masquerading from hiding client
addresses on connections to ktz-cloud’s Tailscale IPv4 address, TCP 443. It does
not grant access or alter public ingress. The unit restarts with Docker or
tailscaled and is enabled at boot. ACME uses Cloudflare recursive resolvers to
avoid the observed Quad9 negative cache blocking DNS-01 propagation checks.
Public requests to this hostname must be denied, even though ktz-cloud's shared
Traefik serves other public websites on the same HTTPS port.

The Tailscale policy permits only ktz-cloud to appnv TCP 443 for these checks.
No extra SSH, HTTP, database, or UDP access is granted by that rule.
The monitor therefore survives an appnv or igloo outage. It still depends on
ktz-cloud and its own Tailscale connection.

The role generates an initial administrator named `alex` with a random password.
Retrieve the initial credential over Tailscale SSH:

```sh
tailscale ssh root@ktz-cloud cat /opt/appdata/uptime-kuma-private/admin.json
```

Never commit that file. Change the password in Kuma after signing in. The initial
credential file is not updated when the password changes in the UI.

The bootstrap uses the authenticated Socket.IO API and runs only until
`/opt/appdata/apps/uptime-kuma/.infra-bootstrap-complete` exists. Subsequent
Ansible deployments preserve monitor and status-page edits made through the UI.
`files/monitors.json` is the initial inventory, not a continuous overwrite policy.
Checks run every 60 seconds, with a 15-second timeout and two retries 30 seconds
apart. They validate DNS, trusted TLS, and HTTP responses, following up to five
redirects. They do not test authenticated application workflows. History retention
is 90 days. No notification providers or notifications are configured.

Smokeping uses `/smokeping/` over HTTPS because its root redirects to HTTP,
which is intentionally outside the monitor's ACL grant.

Stampbook's root response is checked rather than its liveness endpoint. Its
previous HTTP 400 from a Limited edition stamp was resolved by upgrading the
application from v1.1.3 to v1.2.8 on 2026-10-12; historical failures remain visible.

## Short-lived certificates

Traefik on ktz-cloud and appnv selects Let's Encrypt's `shortlived` ACME profile
and uses `certificatesDuration=160` hours for renewal scheduling. The installed
Traefik 3.7 versions start renewal with two days remaining and retry every two
hours. The profile requests the shorter lifetime; the duration setting alone
does not change what the CA issues.

Existing certificates remain in their ACME stores and switch profiles when they
next renew. This deployment does not force replacement of valid certificates.

The appnv runtime Compose file retains migration-specific settings that are not
all represented in the older service fragments. To update only ACME profile
arguments without replacing those settings, use `scripts/traefik-shortlived.py`
on the host's existing Compose file, validate it with `docker compose config
--quiet`, and recreate only the Traefik service. The script discovers all existing
ACME resolvers, including appnv's `glowbug` resolver, and saves a root-readable
backup before its first change. Do not regenerate appnv's full Compose file from
the older fragments without reconciling the migration settings first.
