#!/usr/bin/env python3
"""Actual-only operations. Never print exceptions, SDK output, or file contents."""
import datetime
import fcntl
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import sys
import tarfile
import tempfile
import time

os.umask(0o077)
BASE = Path('/etc/actual-budget')
STATE = Path('/var/lib/actual-budget')
BACKUPS = Path('/var/lib/actual-budget-backups')
DATA = Path('/mnt/nvmeu2/appdata/apps/actual-budget/data')
IMAGE = 'actualbudget/actual-server:26.9.0@sha256:552beab3dec8c93d46b8b9245612d63c3f123b8a45063a474f53e229b17621d3'
COMPOSE = Path('/root/compose.yaml')

def run(*args, timeout=300):
    return subprocess.run(args, check=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=timeout).stdout

def atomic(path, content):
    tmp = path.with_suffix(path.suffix + '.tmp')
    tmp.write_text(content)
    tmp.chmod(0o600)
    tmp.replace(path)

def record(job, status):
    # Each job has its own status, so a backup cannot erase a sync failure.
    atomic(STATE / (job + '.json'), json.dumps({'job':job, 'status':status, 'time':int(time.time())}))
    print('actual_' + job + '_' + status, flush=True)

def healthy(name='actual-budget'):
    for _ in range(60):
        try:
            run('docker','exec',name,'node','-e',"fetch('http://127.0.0.1:5006/').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))",timeout=10)
            return
        except Exception:
            time.sleep(1)
    raise RuntimeError('health check failed')

def backup():
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
    dest = BACKUPS / (stamp + '.tar.gz.age')
    partial = dest.with_suffix('.partial')
    age = None
    try:
        live = json.loads(run('docker','inspect','actual-budget'))[0]
        labels = live['Config']['Labels']
        source = COMPOSE if labels.get('com.docker.compose.project') == 'root' else Path('/opt/actual-budget/compose.yaml')
        rendered = json.loads(run('docker','compose','-f',str(source),'config','--format','json'))
        service = rendered['services'][labels['com.docker.compose.service']]
        service['image'] = live['Config']['Image']
        recovery_compose = json.dumps({'services':{'actual-budget':service}}).encode()
        try:
            run('docker','stop','--time','30','actual-budget')
            with partial.open('wb') as out:
                age = subprocess.Popen(['age','-R',str(BASE/'recipients.txt')],stdin=subprocess.PIPE,stdout=out,stderr=subprocess.DEVNULL)
                with tarfile.open(fileobj=age.stdin,mode='w|gz') as archive:
                    manifest = {}
                    for p in sorted(DATA.rglob('*')):
                        if p.is_symlink(): raise RuntimeError('unexpected data symlink')
                        if p.is_file():
                            with p.open('rb') as f: manifest[str(p.relative_to(DATA))] = hashlib.file_digest(f,'sha256').hexdigest()
                    archive.add(DATA, arcname='data')
                    for name,content in [('compose.yaml',recovery_compose),('metadata.json',json.dumps({'image':live['Config']['Image']}).encode())]:
                        entry=tarfile.TarInfo(name); entry.size=len(content); entry.mode=0o600
                        archive.addfile(entry,io.BytesIO(content))
                    if (BASE/'config.json').exists(): archive.add(BASE/'config.json',arcname='config.json')
                    payload = json.dumps(manifest).encode()
                    info = tarfile.TarInfo('manifest.json'); info.size=len(payload); info.mode=0o600
                    archive.addfile(info,io.BytesIO(payload))
                age.stdin.close()
                if age.wait(timeout=300) != 0: raise RuntimeError('encryption failed')
                out.flush(); os.fsync(out.fileno())
        finally:
            if age and age.poll() is None: age.kill(); age.wait()
            run('docker','start','actual-budget')
        healthy()
        partial.replace(dest)
        # Retention only after a complete encrypted backup and successful restart.
        for old in sorted(BACKUPS.glob('*.tar.gz.age'))[:-30]: old.unlink()
        return dest
    finally:
        partial.unlink(missing_ok=True)

def restore_test(path=None):
    archives = sorted(BACKUPS.glob('*.tar.gz.age'))
    path = Path(path) if path else archives[-1]
    # Same name only for the disposable restore container; never touches production.
    name = 'actual-budget-restore-test'
    with tempfile.TemporaryDirectory(prefix='restore-',dir=STATE) as scratch:
        scratch = Path(scratch)
        proc = subprocess.Popen(['age','-d','-i',str(BASE/'backup-key.txt'),str(path)],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL)
        try:
            with tarfile.open(fileobj=proc.stdout,mode='r|gz') as archive:
                archive.extractall(scratch,filter='data')
            if proc.wait(timeout=300) != 0: raise RuntimeError('decrypt failed')
        finally:
            if proc.poll() is None: proc.kill(); proc.wait()
        manifest = json.loads((scratch/'manifest.json').read_text())
        metadata = scratch/'metadata.json'
        restore_image = json.loads(metadata.read_text())['image'] if metadata.exists() else IMAGE
        if not restore_image.startswith('actualbudget/actual-server:') or '@sha256:' not in restore_image:
            raise RuntimeError('untrusted restore image')
        for filename, digest in manifest.items():
            with (scratch/'data'/filename).open('rb') as f:
                if hashlib.file_digest(f,'sha256').hexdigest() != digest: raise RuntimeError('restore mismatch')
        databases = list((scratch/'data').rglob('*.sqlite'))
        if not databases: raise RuntimeError('no server database')
        for database in databases:
            with sqlite3.connect('file:'+str(database)+'?mode=ro',uri=True) as db:
                if db.execute('pragma quick_check').fetchone()[0] != 'ok': raise RuntimeError('database invalid')
        created = False
        try:
            run('docker','run','-d','--name',name,'--network','none','--log-driver','none','--cap-drop','ALL','--security-opt','no-new-privileges','--memory','1g','--cpus','2','-v',str(scratch/'data')+':/data',restore_image)
            created = True
            healthy(name)
        finally:
            if created: run('docker','rm','-f',name)

def deploy():
    desired = json.loads(run('docker','compose','-f',str(BASE/'render/compose.yaml'),'config','--format','json'))
    current = json.loads(run('docker','compose','-p','root','-f',str(COMPOSE),'config','--format','json'))
    container = json.loads(run('docker','inspect','actual-budget'))[0]
    project = container['Config']['Labels'].get('com.docker.compose.project')
    if project not in ('root','actual-budget'): raise RuntimeError('unexpected deployment owner')
    mounts = container['Mounts']
    if not any(m['Source']==str(DATA) and m['Destination']=='/data' for m in mounts): raise RuntimeError('unexpected data mount')
    # Protect rollback before changing ownership. Do not remove volumes or data.
    original = COMPOSE.read_bytes()
    backup()
    restore_test()
    merged = dict(current)
    merged['services'] = dict(current['services'])
    merged['services']['actual-budget'] = desired['services']['actual-budget']
    candidate = BASE/'candidate.json'
    atomic(candidate,json.dumps(merged))
    validated = json.loads(run('docker','compose','-p','root','-f',str(candidate),'config','--format','json'))
    for key,value in current['services'].items():
        if key != 'actual-budget' and validated['services'][key] != value: raise RuntimeError('unrelated service changed')
    rollback = BASE/'root-compose.before-adoption.yaml'
    if not rollback.exists(): rollback.write_bytes(original); rollback.chmod(0o600)
    try:
        atomic(COMPOSE,json.dumps(merged,indent=2)+'\n')
        if project == 'actual-budget':
            run('docker','stop','--time','30','actual-budget')
            run('docker','rm','actual-budget')
        run('docker','compose','-p','root','-f',str(COMPOSE),'up','-d','--no-deps','actual-budget')
        healthy()
    except Exception:
        COMPOSE.write_bytes(original); COMPOSE.chmod(0o600)
        if project == 'actual-budget':
            existing = run('docker','ps','-a','--filter','name=^actual-budget$','--format','{{.Names}}').strip()
            if existing: run('docker','rm','-f','actual-budget')
            run('docker','compose','-p','actual-budget','-f','/opt/actual-budget/compose.yaml','up','-d')
        else:
            run('docker','compose','-p','root','-f',str(COMPOSE),'up','-d','--no-deps','actual-budget')
        raise
    old = Path('/opt/actual-budget/compose.yaml')
    if old.exists(): old.rename(old.with_name('compose.yaml.adopted'))

def sync(verify=False):
    if not (BASE/'config.json').is_file():
        record('sync','setup_required')
        return False
    cache = Path('/var/lib/actual-budget-sync')
    (cache/'budget').mkdir(mode=0o700,exist_ok=True)
    result_file = cache/'result.json'
    result_file.unlink(missing_ok=True)
    try:
        run('docker','run','--rm','--name','actual-budget-sync','--network','host','--log-driver','none','--cap-drop','ALL','--security-opt','no-new-privileges','--read-only','--tmpfs','/tmp:rw,noexec,nosuid,size=128m','--memory','1g','--cpus','2','-v',str(BASE/'config.json')+':/credentials/config.json:ro','-v',str(cache)+':/cache','local/actual-budget-sync:26.9.0',*(['--verify-imports'] if verify else []),timeout=1200)
    except Exception:
        # A timed-out SDK must not outlive the host lock.
        subprocess.run(['docker','rm','-f','actual-budget-sync'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    result = json.loads(result_file.read_text()) if result_file.exists() else {}
    status = result.get('status','sync_failed')
    if status not in ('ok','sync_failed','reauthentication_required'): status='sync_failed'
    record('sync',status)
    if verify: record('acceptance','ok' if result.get('acceptance')=='imports_and_second_sync_verified' and status=='ok' else 'failed')
    return status=='ok'

def main():
    job = sys.argv[1]
    if job not in ('backup','restore','deploy','sync','verify-imports'): raise SystemExit(2)
    with open('/run/lock/actual-budget.lock','w') as lock:
        try: fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError:
            print('actual_operation_busy',flush=True); return 75
        try:
            if job=='backup': backup()
            elif job=='restore': restore_test(sys.argv[2] if len(sys.argv)>2 else None)
            elif job=='deploy': deploy()
            else: return 0 if sync(job=='verify-imports') else 1
            record(job,'ok')
            return 0
        except Exception:
            record('sync' if job in ('sync','verify-imports') else job,'failed')
            return 1

if __name__=='__main__': sys.exit(main())
