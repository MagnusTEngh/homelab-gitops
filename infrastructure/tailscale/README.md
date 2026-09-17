# Tailscale for Gateway API Access

This enables access to your Cilium Gateway API services through Tailscale without installing Tailscale on your nodes.

## Architecture

```
Your Machine (Tailnet) --> Tailscale Connector Pod --> Cilium Gateway API --> Your Services
```

A single Tailscale Connector pod joins your Tailnet and exposes the Gateway API addresses.

## Setup

### 1. Create Tailscale Auth Key

```bash
# Generate a reusable auth key
tailscale key generate --reusable

# Create Kubernetes secret (replace with your actual key)
kubectl create secret generic tailscale-auth -n tailscale \
  --from-literal=TS_AUTHKEY=tskey-xxxxxxxxxxxxxxxxx
```

### 2. Get Connector IP

```bash
kubectl get pods -n tailscale
kubectl exec -n tailscale <connector-pod> -- tailscale status
```

Note the Tailscale IP (e.g., `100.x.y.z`).

### 3. Access Services

Access your Gateway API services at `http://100.x.y.z:80` or via MagicDNS if enabled.

## Files

- `helmrelease.yaml` - Tailscale operator with connector
- `helmrepository.yaml` - Helm chart repository
- `namespace.yaml` - Namespace
- `kustomization.yaml` - Kustomization

## References

- [Tailscale Kubernetes](https://tailscale.com/kb/installation/kubernetes/)
- [Cilium Gateway API](https://docs.cilium.io/en/stable/network/gateway-api/)
