#!/usr/bin/env bash

# Get the node's internal IP
NODE_IP="192.168.0.188"


talosctl machineconfig patch controlplane.yaml \
  --patch @nodes/cp_192.168.0.188.yaml \
  --patch @patches/remove_cni.yaml \
  --patch @patches/wakeonlan.yaml \
  --patch @patches/workload-on-controlplane.yaml \
  --output rendered/cp_192.168.0.188.yaml

# Apply with --insecure (temporary, until talosctl TLS is fixed)
talosctl apply-config --insecure --nodes 192.168.0.188 --file rendered/cp_192.168.0.188.yaml

helm repo add cilium https://helm.cilium.io/
helm repo update

helm install cilium cilium/cilium \
    --version 1.18.0 \
    --namespace kube-system \
    --set ipam.mode=kubernetes \
    --set kubeProxyReplacement=true \
    --set securityContext.capabilities.ciliumAgent="{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}" \
    --set securityContext.capabilities.cleanCiliumState="{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}" \
    --set cgroup.autoMount.enabled=false \
    --set cgroup.hostRoot=/sys/fs/cgroup \
    --set k8sServiceHost=localhost \
    --set k8sServicePort=7445
