#!/usr/bin/env python3
"""Enable short-lived ACME profiles in an existing Compose file without regenerating it.

Usage: python3 traefik-shortlived.py /path/to/compose.yaml
Validate with docker compose config --quiet before recreating only Traefik.
Existing certificates are retained and adopt the new profile on renewal.
"""
import os
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
source = path.read_text()
resolvers = sorted(set(re.findall(r'--certificatesresolvers\.([\w-]+)\.acme\.storage=', source)))
if not resolvers:
    raise SystemExit('No ACME resolver storage arguments found; nothing changed.')
updated = source
for resolver in resolvers:
    prefix = '--certificatesresolvers.' + resolver + '.acme.'
    for option, value in [('profile', 'shortlived'), ('certificatesduration', '160')]:
        pattern = r'(?mi)^(\s*-\s*[\"\x27]?' + re.escape(prefix + option) + r'=)[^\"\x27\r\n]+([\"\x27]?\s*)$'
        if re.search(pattern, updated):
            updated = re.sub(pattern, lambda m: m[1] + value + m[2], updated)
        else:
            anchor = re.search(r'(?m)^([ \t]*)-\s*[\"\x27]?' + re.escape(prefix + 'storage=') + r'[^\r\n]*$', updated)
            if not anchor:
                raise SystemExit('Cannot locate resolver storage line; nothing changed.')
            updated = updated[:anchor.end()] + '\n' + anchor[1] + '- ' + prefix + option + '=' + value + updated[anchor.end():]
if updated != source:
    backup = path.with_name(path.name + '.before-shortlived')
    fd = os.open(backup, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'w') as output:
        output.write(source)
    path.write_text(updated)
    print('Enabled shortlived/160 for: ' + ', '.join(resolvers))
else:
    print('Already configured: ' + ', '.join(resolvers))
