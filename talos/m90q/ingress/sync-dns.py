#!/usr/bin/env python3
"""Reconcile declared m90q DNS records; refuse conflicting existing records."""
import json, os, pathlib, subprocess, urllib.parse, urllib.request
root = pathlib.Path(__file__).resolve().parent
config = json.loads((root / 'dns.json').read_text())
secret = root.parents[3] / 'k8s/clusters/m90q/ingress/cloudflare-secret.sops.yaml'
env = os.environ.copy()
env['SOPS_AGE_KEY_FILE'] = os.environ.get('M90Q_AGE_KEY_FILE', str(pathlib.Path.home() / '.config/sops/age/m90q.txt'))
data = json.loads(subprocess.check_output(['sops', 'decrypt', '--output-type', 'json', str(secret)], env=env))
token = data['stringData']['api-token']
def api(path, payload=None):
    req = urllib.request.Request('https://api.cloudflare.com/client/v4/' + path,
        data=None if payload is None else json.dumps(payload).encode(),
        headers={'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=30) as response:
        result = json.load(response)
    if not result['success']:
        raise RuntimeError('Cloudflare request failed')
    return result['result']
zones = api('zones?' + urllib.parse.urlencode({'name': config['zone']}))
assert len(zones) == 1, 'Expected one matching Cloudflare zone'
base = 'zones/' + zones[0]['id'] + '/dns_records'
for desired in config['records']:
    existing = api(base + '?' + urllib.parse.urlencode({'name': desired['name']}))
    if existing:
        assert len(existing) == 1 and all(existing[0].get(k) == v for k, v in desired.items()), 'Conflicting existing DNS record; inspect before changing'
        print('Already correct:', desired['name'])
    else:
        api(base, desired)
        print('Created:', desired['name'], '->', desired['content'], '(DNS only)')
