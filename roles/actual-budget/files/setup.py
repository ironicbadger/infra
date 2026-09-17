#!/usr/bin/env python3
"""Run interactively over SSH; never supply secrets as command-line arguments."""
import getpass
import json
import os
import sys
from pathlib import Path
os.umask(0o077)
if os.geteuid() != 0 or not sys.stdin.isatty() or not sys.stderr.isatty():
    raise SystemExit('Use an interactive root terminal (ssh -t); no input was read.')
base=Path('/etc/actual-budget')
config={
    'password': getpass.getpass('Actual server password: '),
    'syncId': getpass.getpass('Budget Sync ID (Settings > Advanced): '),
    'budgetEncryptionPassword': getpass.getpass('Budget encryption password (blank only if disabled): '),
    'accountIds': [x.strip() for x in getpass.getpass('Authorized SimpleFIN Actual account IDs, comma separated: ').split(',') if x.strip()],
}
if not config['password'] or not config['syncId'] or not config['accountIds']:
    raise SystemExit('Incomplete configuration; nothing saved.')
tmp=base/'config.json.tmp'
tmp.write_text(json.dumps(config)); tmp.chmod(0o600); tmp.replace(base/'config.json')
print('Configuration saved securely. Run the sync acceptance command next.')
