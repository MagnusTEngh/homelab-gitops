# Tailscale for Gateway API Access

This enables access to your Cilium Gateway API services through Tailscale without installing Tailscale on your nodes. Only Gateway API addresses are exposed via L2 announcements.

## Architecture

```
Your Device (Tailnet)
  --> [Tailscale Subnet Route: 192.168.1.240/29]
  --> [Cilium L2 Announcement: LoadBalancer IP]
  --> cilium-gateway-<name> Service (LoadBalancer type)
  --> Envoy
  --> Gateway API
  --> Your Application
```

The Tailscale Connector advertises the Cilium LoadBalancer IP pool CIDR to your Tailnet. Cilium uses L2 announcements to make LoadBalancer Service IPs reachable on the LAN. The Gateway API creates a LoadBalancer Service that gets an IP from the pool, and Tailscale routes traffic to it.

## Setup

### 1. Create OAuth Client in Tailscale

1. Go to Tailscale admin console → Settings → OAuth clients
2. Create a new OAuth client with:
   - Scope: `devices:core`
   - Tag: `tag:k8s`
3. Note the `clientId` and `clientSecret`

### 2. Create Kubernetes Secrets

```bash
# Create OAuth secret for the operator (must be named tailscale-oauth)
kubectl create secret generic tailscale-oauth -n tailscale \
  --from-literal=clientId=<your-client-id> \
  --from-literal=clientSecret=<your-client-secret>
```

### 3. Approve Subnet Route

Once the Connector pod is running:
1. Go to Tailscale admin console → Machines
2. Find the `k8s-subnet-router` device
3. Approve the `192.168.1.240/29` subnet route

Or set up an auto-approver ACL for `tag:k8s`:
```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["tag:k8s"],
      "dst": ["192.168.1.240/29"]
    }
  ]
}
```

### 4. Access Services

Find your Gateway's LoadBalancer IP:
```bash
kubectl get svc -n gateway-test cilium-gateway-gateway-test-gateway -o jsonpath='{.spec.loadBalancerIP}'
```

Access from any device on your Tailnet:
```bash
curl http://<loadbalancer-ip>:80
```

Or use MagicDNS if enabled:
```bash
curl http://<loadbalancer-ip>.your-tailnet.ts.net
```

## How It Works

1. **CiliumLoadBalancerIPPool** (`infrastructure/cilium/ip-pool.yaml`) - Defines IP range `192.168.1.240/29` for LoadBalancer Services
2. **CiliumL2AnnouncementPolicy** (`infrastructure/cilium/l2-announcement-policy.yaml`) - Enables L2 announcements for LoadBalancer IPs
3. **Cilium HelmRelease** (`infrastructure/cilium/helmrelease.yaml`) - Has `l2announcements.enabled: true` and `externalIPs.enabled: true`
4. **Gateway** (`apps/gateway-test/app.yaml`) - Creates a LoadBalancer Service that gets an IP from the pool
5. **Tailscale Connector** (`infrastructure/tailscale/connector.yaml`) - Advertises `192.168.1.240/29` to Tailnet
6. **Tailscale Operator** - Manages the Connector

Traffic flow:
- Your Device → Tailscale → [Subnet Route] → LAN → [L2 Announcement] → LoadBalancer Service IP → Envoy → Gateway → Your App

**Important:** Only IPs in `192.168.1.240/29` are accessible. Other cluster services are NOT exposed.

## Talos-Specific Configuration

The namespace has `pod-security.kubernetes.io/enforce: privileged` label to allow the Connector's privileged init container (needed for IP forwarding).

## Files

### Cilium Configuration
| File | Purpose |
|------|---------|
| `infrastructure/cilium/helmrelease.yaml` | Cilium with L2 announcements enabled |
| `infrastructure/cilium/ip-pool.yaml` | LoadBalancer IP pool (192.168.1.240/29) |
| `infrastructure/cilium/l2-announcement-policy.yaml` | L2 announcement policy |
| `infrastructure/cilium/kustomization.yaml` | Includes all Cilium resources |

### Tailscale Configuration
| File | Purpose |
|------|---------|
| `infrastructure/tailscale/helmrelease.yaml` | Tailscale operator with OAuth from secret |
| `infrastructure/tailscale/helmrepository.yaml` | Helm chart repository |
| `infrastructure/tailscale/connector.yaml` | Connector CR (subnet router for 192.168.1.240/29) |
| `infrastructure/tailscale/namespace.yaml` | Namespace with privileged label |
| `infrastructure/tailscale/kustomization.yaml` | Kustomization |
| `infrastructure/tailscale/README.md` | This file |

## Troubleshooting

### Connector won't authenticate
```bash
kubectl logs -n tailscale -l app.kubernetes.io/name=tailscale-operator
kubectl get secret -n tailscale tailscale-oauth
kubectl describe secret -n tailscale tailscale-oauth
```

### Subnet route not appearing
```bash
kubectl get connector -n tailscale -o yaml
kubectl logs -n tailscale -l app.kubernetes.io/name=tailscale-connector
```

Check Tailscale admin console → Machines → Find the `k8s-subnet-router` device → Check if subnet route is pending approval.

### Gateway doesn't have an IP
```bash
# Check Gateway status
kubectl get gateway -n gateway-test -o yaml

# Check the LoadBalancer Service
kubectl get svc -n gateway-test cilium-gateway-gateway-test-gateway -o yaml

# Check Cilium L2 announcements
kubectl -n kube-system exec cilium-xxx -- cilium service list
```

### Can't access Gateway
```bash
# From a Tailnet device, test connectivity
tailscale ping <loadbalancer-ip>

# Check if route is active
tailscale status

# Check L2 announcement on node
ip neigh show 192.168.1.240/29
```

## References

- [Tailscale Kubernetes Operator](https://tailscale.com/docs/kubernetes-operator)
- [Tailscale Connector (Subnet Router)](https://tailscale.com/docs/kubernetes-operator/connector)
- [Cilium L2 Announcements](https://docs.cilium.io/en/stable/network/loadbalancer/l2-announcements/)
- [Cilium LoadBalancer IPAM](https://docs.cilium.io/en/stable/network/loadbalancer/)
- [Cilium Gateway API](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/)
- [Tailscale OAuth Clients](https://tailscale.com/kb/oauth-clients)
