#!/usr/bin/env python3
"""Generate private Talos configs from encrypted secrets and public inventory."""
import json, os, pathlib, subprocess
root=pathlib.Path(__file__).resolve().parent
cfg=json.loads((root/'cluster.json').read_text())
# Sibling repository; infra owns VMs, k8s owns cluster configuration.
k8s=root.parents[2]/'k8s'
base=k8s/'clusters/m90q/talos'
out=base/'clusterconfig'
out.mkdir(parents=True,exist_ok=True); out.chmod(0o700)
env=os.environ.copy(); env['SOPS_AGE_KEY_FILE']=os.environ.get('M90Q_AGE_KEY_FILE', str(pathlib.Path.home()/'.config/sops/age/m90q.txt'))
secret=subprocess.check_output(['sops','decrypt',str(base/'secrets.sops.yaml')],env=env)
(out/'secrets.yaml').write_bytes(secret); (out/'secrets.yaml').chmod(0o600)
schematic=json.loads((root/'schematic.json').read_text())['id']
for n in cfg['nodes']:
    patch={'machine':{'network':{'nameservers':cfg['dns'],'interfaces':[{'interface':'ens18','dhcp':False,'addresses':[n['ip']+'/21'],'routes':[{'network':'0.0.0.0/0','gateway':cfg['gateway']}],'vip':{'ip':'10.42.1.120'}}]},'nodeLabels':{'topology.kubernetes.io/zone':n['proxmoxNode']},'features':{'kubePrism':{'enabled':True,'port':7445}}},'cluster':{'allowSchedulingOnControlPlanes':True,'network':{'cni':{'name':'none'},'podSubnets':[cfg['podSubnet']],'serviceSubnets':[cfg['serviceSubnet']]},'proxy':{'disabled':True}}}
    patchfile=base/(n['name']+'.patch.yaml');patchfile.write_text(json.dumps(patch,indent=2)+'\n---\napiVersion: v1alpha1\nkind: HostnameConfig\nauto: null\nhostname: '+n['name']+'\n')
    subprocess.run(['talosctl','gen','config','m90q',cfg['endpoint'],'--with-secrets',str(out/'secrets.yaml'),'--talos-version',cfg['talosVersion'],'--kubernetes-version',cfg['kubernetesVersion'],'--install-image',f"factory.talos.dev/installer/{schematic}:{cfg['talosVersion']}",'--config-patch','@'+str(patchfile),'--with-docs=false','--with-examples=false','--output-types','controlplane','--output',str(out/(n['name']+'.yaml')),'--force'],check=True)
    generated=out/(n['name']+'.yaml')
    # talosctl 1.13 adds auto: stable; explicit hostnames are mutually exclusive.
    generated.write_text(generated.read_text().replace('auto: stable\n',''))
    generated.chmod(0o600)
    subprocess.run(['talosctl','validate','--config',str(generated),'--mode','metal'],check=True)
subprocess.run(['talosctl','gen','config','m90q',cfg['endpoint'],'--with-secrets',str(out/'secrets.yaml'),'--output-types','talosconfig','--output',str(out/'talosconfig'),'--force'],check=True)
subprocess.run(['talosctl','--talosconfig',str(out/'talosconfig'),'config','endpoint',*[n['ip'] for n in cfg['nodes']]],check=True)
for p in out.iterdir():
    if p.is_file():p.chmod(0o600)
