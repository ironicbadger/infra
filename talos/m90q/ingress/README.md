# M90q ingress

- VIP: **10.42.0.54/21**, VRRP ID 54 on core-pi5/core-zima.
- Existing DNS/Caddy VIP remains **10.42.0.53** (VRRP ID 53).
- `*.m90q.ktz.me` is a DNS-only Cloudflare A record pointing to 10.42.0.54.
- Clients need LAN access or Tailscale subnet routing to 10.42.0.54. No public
  forwarding or Cloudflare proxy is configured.

## Traffic and TLS

Client -> core VIP TCP 80/443 -> HAProxy -> Talos NodePorts 30080/30443 -> Traefik
-> application Service. HAProxy performs TCP passthrough; TLS terminates in
Traefik using cert-manager's Let's Encrypt wildcard. HTTP redirects to HTTPS.
PROXY v2 preserves the client IP; Traefik trusts only core addresses.

Traefik has two replicas with required node anti-affinity. Local NodePort traffic
policy and HAProxy health checks select only nodes running a local ready endpoint.
One node having no ready NodePort endpoint is expected with two replicas on three
nodes. No app is pinned to a host or assigned a per-app NodePort.

Cert-manager uses Cloudflare DNS-01 and public resolvers for validation. The
certificate covers *.m90q.ktz.me and m90q.ktz.me. Its Secret stays in namespace
traefik; the default TLSStore supplies it to TLS-enabled app Ingresses across
namespaces. Wildcard does not cover deeper names like foo.bar.m90q.ktz.me.
Credentials are SOPS-encrypted in the sibling k8s repo. The existing core Caddy
Cloudflare token is reused; its permissions were not expanded.

## Core ownership

`group_vars/core.yaml` defines VIP/backend inventory. `core-m90q-ingress` owns:
- /etc/haproxy/m90q.cfg and m90q-ingress.service
- /etc/keepalived/conf.d/m90q-ingress.conf and its main-config include
- /usr/local/bin/check-m90q-ingress
- net.ipv4.ip_nonlocal_bind=1, so standby proxies can bind the absent VIP

Core Caddy binds existing addresses plus 10.42.0.53, excluding 10.42.0.54. Its
HTTP redirects use the same explicit bind list. The parent repo's `core-caddy`
role owns that template and reuses the shared role only for installation; no
submodule changes are required. Pre-change Caddyfiles are saved on each core
node as /etc/caddy/Caddyfile.pre-m90q (root-only).

The new VIP has its own health check and does not depend on AdGuard's health
check. A failed proxy or loss of every reachable Traefik backend removes the VIP
from that core node. Both instances use BACKUP/nopreempt to avoid unnecessary
failback; a recovered higher-priority node does not automatically take it back.
The existing DNS VRRP behavior is preserved.

## Apply / verify

Run backup node first, then primary. Existing Tailscale SSH access works as root;
LAN root SSH does not currently accept this Mac's key. The ingress-only playbook
does not need the legacy SOPS secrets plugin because it preserves existing Caddy
and DNS Keepalived configuration.

```sh
ANSIBLE_VARS_ENABLED=host_group_vars ansible-playbook playbooks/m90q-ingress.yaml --limit core-zima -e ansible_user=root -e ansible_host=core-zima
ANSIBLE_VARS_ENABLED=host_group_vars ansible-playbook playbooks/m90q-ingress.yaml --limit core-pi5 -e ansible_user=root -e ansible_host=core-pi5
python3 talos/m90q/ingress/sync-dns.py
```

`sync-dns.py` decrypts the cluster secret using ~/.config/sops/age/m90q.txt
(or M90Q_AGE_KEY_FILE) and refuses to overwrite conflicting DNS records. Existing
recursive resolvers may cache NXDOMAIN for up to 30 minutes after a new name is
first queried; clear AdGuard cache through its API/UI when necessary.

The old DNS VRRP password exceeds eight characters. Keepalived already uses only
the first eight; the validator tolerates that exact existing warning and rejects
other validation failures. No authentication value is changed by this role.

Verified: both core proxies healthy; wildcard Certificate Ready; application
routing over valid TLS through a temporary Headlamp route; ingress VIP moved from
core-zima to core-pi5 when only zima's proxy was stopped. Zima's proxy was restored,
the temporary route removed, and existing DNS/Caddy services verified afterward.

SmokePing remains a zero-replica local draft in the k8s repo. Its new intended URL
is https://smokeping.m90q.ktz.me/smokeping. NFS/ICMP validation and data migration
are separate pending steps. Grafana and Headlamp's original access URLs remain
available; moving their login URLs also requires updating their OIDC callbacks.
