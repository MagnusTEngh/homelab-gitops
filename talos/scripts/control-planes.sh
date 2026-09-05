#!/usr/bin/env bash

# Get the node's internal IP
NODE_IP="192.168.0.188"

helm repo add cilium https://helm.cilium.io/
helm repo update

helm template \
    cilium \
    cilium/cilium \
    --version 1.18.0 \
    --namespace kube-system \
    --set ipam.mode=kubernetes \
    --set kubeProxyReplacement=true \
    --set bpf.hostRouting=true \
    --set hostFirewall.enabled=false \
    --set k8sServiceHost="$NODE_IP" \
    --set k8sServicePort=6443 \
    --set cgroup.autoMount.enabled=false \
    --set cgroup.hostRoot=/sys/fs/cgroup > cilium.yaml  # Removed securityContext.capabilities

{
  cat <<'EOF'
cluster:
  inlineManifests:
    - name: cilium
      contents: |
EOF
  sed 's/^/        /' cilium.yaml
} > patches/cilium-patch.yaml

talosctl machineconfig patch controlplane.yaml \
  --patch @nodes/cp_192.168.0.188.yaml \
  --patch @patches/remove_cni.yaml \
  --patch @patches/cilium-patch.yaml \
  --patch @patches/wakeonlan.yaml \
  --patch @patches/workload-on-controlplane.yaml \
  --output rendered/cp_192.168.0.188.yaml

# Apply with --insecure (temporary, until talosctl TLS is fixed)
talosctl apply-config --insecure --nodes 192.168.0.188 --file rendered/cp_192.168.0.188.yaml