#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Configuration
# ==============================================================================

NODE_IP="192.168.0.188"

TALOS_VERSION="v1.13.7"
TALOS_SCHEMATIC="b8e8fbbe1b520989e6c52c8dc8303070cb42095997e76e812fa8892393e1d176"

CILIUM_VERSION="1.18.0"

TALOSCONFIG="$PWD/talosconfig"
KUBECONFIG="$PWD/kubeconfig"

RENDERED_CONFIG="rendered/cp_${NODE_IP}.yaml"

TALOS_INSTALLER="factory.talos.dev/metal-installer/${TALOS_SCHEMATIC}:${TALOS_VERSION}"

# ==============================================================================
# Helpers
# ==============================================================================

wait_for_talos() {
echo
echo "==> Waiting for Talos API at ${NODE_IP}:50000..."

until talosctl version --nodes "$NODE_IP" >/dev/null 2>&1; do
    printf '.'
    sleep 5
done

echo
echo "    Talos API is available."


}

wait_for_talos_version() {
echo
echo "==> Waiting for Talos ${TALOS_VERSION}..."

until talosctl version --nodes "$NODE_IP" 2>/dev/null |
    grep -q "Tag:[[:space:]]*${TALOS_VERSION}"; do

    printf '.'
    sleep 5
done

echo
echo "    Talos ${TALOS_VERSION} is running."


}

wait_for_kubernetes_api() {
echo
echo "==> Waiting for Kubernetes API..."

until kubectl \
    --kubeconfig "$KUBECONFIG" \
    get --raw=/readyz >/dev/null 2>&1; do

    printf '.'
    sleep 5
done

echo
echo "    Kubernetes API is ready."


}

# ==============================================================================
# Render Talos machine configuration
# ==============================================================================

echo
echo "==> Rendering Talos machine configuration..."

talosctl machineconfig patch controlplane.yaml \
--patch "@nodes/cp_${NODE_IP}.yaml" \
--patch @patches/remove_cni.yaml \
--patch @patches/wakeonlan.yaml \
--patch @patches/workload-on-controlplane.yaml \
--output "$RENDERED_CONFIG"

echo " Rendered: $RENDERED_CONFIG"

# ==============================================================================
# Initial Talos configuration
# The machine must currently be booted into Talos maintenance mode.
# ==============================================================================

echo
echo "==> Applying initial Talos configuration..."

talosctl apply-config \
--insecure \
--nodes "$NODE_IP" \
--file "$RENDERED_CONFIG"

# ==============================================================================
# Configure talosctl
# ==============================================================================

echo
echo "==> Configuring talosctl..."

export TALOSCONFIG

talosctl config endpoint "$NODE_IP"
talosctl config node "$NODE_IP"

# ==============================================================================
# Wait for Talos to reboot after apply-config
# ==============================================================================

wait_for_talos

# ==============================================================================
# Upgrade Talos
# ==============================================================================

echo
# echo "==> Upgrading Talos to ${TALOS_VERSION}..."

# echo " Installer:"
# echo " ${TALOS_INSTALLER}"

# talosctl upgrade \
# --nodes "$NODE_IP" \
# --image "$TALOS_INSTALLER"

# ==============================================================================
# Wait for Talos to reboot after upgrade
# ==============================================================================

wait_for_talos

# ==============================================================================
# Verify Talos version
# ==============================================================================

# wait_for_talos_version

echo
echo "==> Talos version:"
talosctl version --nodes "$NODE_IP"

# ==============================================================================
# Bootstrap Kubernetes
# Single control-plane node:
# this initializes the etcd cluster.
# ==============================================================================

echo
echo "==> Bootstrapping Kubernetes..."

talosctl bootstrap \
--nodes "$NODE_IP"

# ==============================================================================
# Generate kubeconfig
# ==============================================================================

echo
echo "==> Generating kubeconfig..."

talosctl kubeconfig "$KUBECONFIG"

export KUBECONFIG

# ==============================================================================
# Wait for Kubernetes API
# IMPORTANT:
# CNI is intentionally disabled and kube-proxy is disabled.
# Therefore, do NOT wait for the Kubernetes node to become Ready here.
# We only wait for the API server to become available.
# ==============================================================================

wait_for_kubernetes_api

# ==============================================================================
# Install Cilium
# ==============================================================================

echo
echo "==> Adding Cilium Helm repository..."

helm repo add cilium https://helm.cilium.io/ 2>/dev/null || true

helm repo update

echo
echo "==> Installing Cilium ${CILIUM_VERSION}..."

helm upgrade --install \
cilium \
cilium/cilium \
--version "$CILIUM_VERSION" \
--namespace kube-system \
--set operator.replicas=1 \ # While single node
--set ipam.mode=kubernetes \
--set kubeProxyReplacement=true \
--set securityContext.capabilities.ciliumAgent="{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}" \
--set securityContext.capabilities.cleanCiliumState="{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}" \
--set cgroup.autoMount.enabled=false \
--set cgroup.hostRoot=/sys/fs/cgroup \
--set k8sServiceHost=localhost \
--set k8sServicePort=7445

# ==============================================================================
# Wait for Cilium
# ==============================================================================

echo
echo "==> Waiting for Cilium daemonset..."

kubectl \
--namespace kube-system \
rollout status daemonset/cilium \
--timeout=10m

# ==============================================================================
# Wait for Kubernetes node to become Ready
# ==============================================================================

echo
echo "==> Waiting for Kubernetes node to become Ready..."

until kubectl get nodes \
    --no-headers 2>/dev/null |
    awk '$2 == "Ready" { found=1 } END { exit !found }'; do
    printf '.'
    sleep 5
done

echo
echo "    Kubernetes node is Ready."


# ==============================================================================
# Final status
#==============================================================================

echo
echo "=============================================================================="
echo " Bootstrap complete"
echo "=============================================================================="

echo
echo "==> Talos:"
talosctl version --nodes "$NODE_IP"

echo
echo "==> Kubernetes:"
kubectl get nodes -o wide

echo
echo "==> Cilium:"
kubectl -n kube-system get pods -l k8s-app=cilium

echo
echo "=============================================================================="
echo " Done"
echo "=============================================================================="
