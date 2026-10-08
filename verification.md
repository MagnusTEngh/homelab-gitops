# Verification

This document describes verification steps primarily intended for humans with access to the cluster, but can be used by agents that have access as well.

## Verify the required tools are present and working
talosctl version --client
flux --version
kubectl version --client
kubeconform -v

### Flux

Check that Flux is healthy and reconciled:

```bash
flux check
```

Expected output: All checks should show `OK` or `healthy`.

List all Kustomizations:

```bash
flux get kustomizations -A
```

Expected output: All kustomizations should show `Ready` with `reconciled at` timestamp.

List all HelmReleases:

```bash
flux get helmreleases -A
```

Expected output: All releases should show `Ready` with latest revision deployed.

### Kubernetes Cluster

Check cluster events for errors:

```bash
kubectl get events -n kube-system --sort-by=.lastTimestamp
```

Expected output: No repeated errors or warnings.

Monitor pod status:

```bash
watch -n 2 -d 'kubectl -n kube-system get pods -o wide'
```

Expected output: All pods should be `Running` or `Completed`.

### Talos Linux

Check Talos version and health:

```bash
talosctl version --nodes 192.168.0.188
```

Expected output: Shows the Talos version matching `TALOS_VERSION` in `talos/scripts/control-planes.sh`.

Verify extensions are installed (required for Longhorn):

```bash
talosctl -n 192.168.0.188 get extensions
```

Expected output: Should list `siderolabs/iscsi-tools` and `siderolabs/util-linux-tools`. If missing, update `TALOS_SCHEMATIC` in `talos/scripts/control-planes.sh` with a schematic ID that includes both extensions from [factory.talos.dev](https://factory.talos.dev).

Check kubelet extra mounts (required for Longhorn):

```bash
talosctl -n 192.168.0.188 get machineconfig -o yaml | grep -A5 extraMounts
```

Expected output: Should show `/var/mnt/longhorn` with `rshared` and `rw` options.

### Cilium

Check Cilium pod status:

```bash
kubectl -n kube-system get pods -l k8s-app=cilium
```

Expected output: All Cilium pods should be `Running`.

Verify Cilium version matches `infrastructure/cilium/helmrelease.yaml`:

```bash
kubectl -n kube-system get pods -l k8s-app=cilium -o jsonpath='{.items[0].metadata.labels.version}'
```

Expected output: Should match the version in the HelmRelease (e.g., `1.20.2`).

### Longhorn

Check Longhorn pod status:

```bash
kubectl -n longhorn-system get pods
```

Expected output: All Longhorn pods (manager, driver-deployer, ui, etc.) should be `Running`.

Verify Longhorn nodes are ready:

```bash
kubectl -n longhorn-system get nodes
```

Expected output: Node should show `Ready` with no errors.

Check Longhorn volumes and settings:

```bash
kubectl -n longhorn-system get settings
```

Expected output: `default-data-path` should be `/var/mnt/longhorn`, `default-replica-count` should be `1` (single node).

Verify Longhorn UI is accessible:

```bash
kubectl -n longhorn-system get svc longhorn-frontend
```

Expected output: Service should be `ClusterIP` with port `80`.

### Gateway API

Check Gateway API pod status:

```bash
kubectl -n gateway-api get pods
```

Expected output: All pods should be `Running`.

### Cert-Manager

Check cert-manager pod status:

```bash
kubectl -n cert-manager get pods
```

Expected output: All pods should be `Running`.

### Tailscale

Check Tailscale pod status:

```bash
kubectl -n tailscale get pods
```

Expected output: All pods should be `Running`.

Verify Tailscale connectivity:

```bash
kubectl -n tailscale get svc
```

Expected output: Should show Tailscale services with external IPs.
