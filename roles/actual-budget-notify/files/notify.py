#!/usr/bin/env python3
"""Pull sanitized status + encrypted backups. Hermes bot credentials stay here."""
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import time

os.umask(0o077)
base=Path('/var/lib/actual-budget-monitor')
backups=base/'backups'
ssh=['ssh','-o','BatchMode=yes','-o','ConnectTimeout=15','root@appnv']

def call(args):
    return subprocess.run(args,check=True,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,timeout=120).stdout

def notify(code):
    # Never interpolate remote data or exceptions into messages.
    messages={
        'healthy':'Actual Budget: infrastructure checks recovered.',
        'sync_setup_required':'Actual Budget: secure server/budget setup and bank authorization are required. No automated import has been verified.',
        'sync_reauthentication_required':'Actual Budget: bank reauthentication is required. Open Actual and SimpleFIN securely; no credentials in Telegram.',
        'sync_failed':'Actual Budget: daily bank sync failed or could not verify every configured account. Review securely in Actual; bank reauthentication may be needed.',
        'backup_failed':'Actual Budget: encrypted backup failed or is overdue.',
        'restore_failed':'Actual Budget: isolated restore test failed or is overdue.',
        'monitor_failed':'Actual Budget: monitoring or encrypted backup copy failed. Check appnv and Hermes.',
    }
    call(['/usr/local/bin/hermes','-p','gilfoyle','send','--to','telegram','--quiet',messages[code]])

def main():
    base.mkdir(mode=0o700,exist_ok=True); backups.mkdir(mode=0o700,exist_ok=True)
    statefile=base/'sent.json'
    previous=json.loads(statefile.read_text()) if statefile.exists() else {}
    codes=[]
    try:
        status=json.loads(call(ssh+['python3 -c '+shlex.quote("import json,pathlib; p=pathlib.Path('/var/lib/actual-budget'); print(json.dumps({x.stem:json.loads(x.read_text()) for x in p.glob('*.json')}))")]))
        now=time.time()
        for job,limit in [('sync',30*3600),('backup',30*3600),('restore',8*86400)]:
            entry=status.get(job,{})
            value=entry.get('status')
            if job=='sync' and value in ('setup_required','reauthentication_required'): codes.append('sync_'+value)
            elif value!='ok' or now-entry.get('time',0)>limit: codes.append(job+'_failed')
        names=json.loads(call(ssh+['python3 -c '+shlex.quote("import json,pathlib; print(json.dumps(sorted(p.name for p in pathlib.Path('/var/lib/actual-budget-backups').glob('*.tar.gz.age'))))")]))
        if not names: raise RuntimeError('no backup')
        for name in names:
            if not re.fullmatch(r'[0-9]{8}T[0-9]{6}\.[0-9]{6}Z\.tar\.gz\.age',name): raise RuntimeError('unexpected filename')
            target=backups/name
            if target.exists(): continue
            partial=backups/(name+'.partial')
            call(['scp','-q','-o','BatchMode=yes','-o','ConnectTimeout=15','root@appnv:/var/lib/actual-budget-backups/'+name,str(partial)])
            digest=call(ssh+['sha256sum /var/lib/actual-budget-backups/'+name]).decode().split()[0]
            with partial.open('rb') as f:
                if hashlib.file_digest(f,'sha256').hexdigest()!=digest: raise RuntimeError('copy mismatch')
            partial.chmod(0o600); partial.replace(target)
        for old in sorted(backups.glob('*.tar.gz.age'))[:-30]: old.unlink()
    except Exception:
        codes.append('monitor_failed')
    codes=sorted(set(codes)) or ['healthy']
    if codes!=previous.get('codes') or (codes!=['healthy'] and time.time()-previous.get('time',0)>86400):
        for code in codes: notify(code)
        tmp=statefile.with_suffix('.tmp')
        tmp.write_text(json.dumps({'codes':codes,'time':int(time.time())})); tmp.replace(statefile)
    print('actual_monitor_ok' if 'monitor_failed' not in codes else 'actual_monitor_failed')

if __name__=='__main__':
    try: main()
    except Exception:
        print('actual_notification_failed')
        raise SystemExit(1)
