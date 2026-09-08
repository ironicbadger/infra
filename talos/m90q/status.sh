#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export TALOSCONFIG="$script_dir/../../../k8s/clusters/m90q/talos/clusterconfig/talosconfig"
export KUBECONFIG="$script_dir/../../../k8s/clusters/m90q/talos/clusterconfig/kubeconfig"
kubectl get nodes -o wide
kubectl get deployments,daemonsets -A
flux get kustomizations -A
flux get helmreleases -A
kubectl get storageclass
