#!/usr/bin/env python3
"""Temporary PVC test: write on node 1, read on node 2, remove test resources."""
import json,pathlib,subprocess
config=pathlib.Path(__file__).resolve().parents[3]/'k8s/clusters/m90q/talos/clusterconfig/kubeconfig'
k=['kubectl','--kubeconfig',str(config)]
ns='m90q-storage-check'
def run(args, data=None):
    return subprocess.check_output(k+args,input=json.dumps(data) if data else None,text=True)
def apply(obj):return run(['apply','-f','-'],obj)
run(['create','namespace',ns])
pv=None
try:
    apply({'apiVersion':'v1','kind':'PersistentVolumeClaim','metadata':{'name':'check','namespace':ns},'spec':{'accessModes':['ReadWriteOnce'],'storageClassName':'ceph-rbd','resources':{'requests':{'storage':'1Gi'}}}})
    run(['wait','-n',ns,'pvc/check','--for=jsonpath={.status.phase}=Bound','--timeout=120s'])
    pv=json.loads(run(['get','pvc','check','-n',ns,'-o','json']))['spec']['volumeName']
    # Only this disposable test PV is deleted automatically; app PVs remain Retain.
    run(['patch','pv',pv,'--type=merge','-p','{"spec":{"persistentVolumeReclaimPolicy":"Delete"}}'])
    for i in [1,2]:
        command='echo m90q-ceph-pass > /data/check; sync; cat /data/check; nslookup kubernetes.default.svc.cluster.local' if i==1 else 'test "$(cat /data/check)" = m90q-ceph-pass && cat /data/check'
        apply({'apiVersion':'v1','kind':'Pod','metadata':{'name':'check','namespace':ns},'spec':{'restartPolicy':'Never','nodeSelector':{'kubernetes.io/hostname':f'talos-m90q-{i}'},'containers':[{'name':'check','image':'busybox:1.37','command':['sh','-ec',command],'volumeMounts':[{'name':'data','mountPath':'/data'}]}],'volumes':[{'name':'data','persistentVolumeClaim':{'claimName':'check'}}]}})
        run(['wait','-n',ns,'pod/check','--for=jsonpath={.status.phase}=Succeeded','--timeout=180s'])
        print(f'Node {i}: '+run(['logs','-n',ns,'check']),flush=True)
        run(['delete','pod','check','-n',ns,'--wait=true','--timeout=60s'])
finally:
    print(run(['delete','namespace',ns,'--wait=true','--timeout=120s']),flush=True)
    if pv:print(run(['wait','--for=delete','pv/'+pv,'--timeout=120s']),flush=True)
