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

The Tailscale Connector advertises the dedicated Cilium LoadBalancer IP pool CIDR to your Tailnet. The pool is restricted to Cilium Gateway API Services using the `gateway.networking.k8s.io/gateway-name` and `gateway.networking.k8s.io/gateway-namespace` labels, so ordinary LoadBalancer Services cannot claim addresses from this advertised range. Cilium uses L2 announcements to make the assigned Gateway Service IPs reachable on the LAN.

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

The example HTTPRoute matches the hostname `echo.gateway-test`. Preserve that hostname in the request with `curl --resolve`:
```bash
curl --resolve echo.gateway-test:<loadbalancer-ip>:80 \
  http://echo.gateway-test:<loadbalancer-ip>/
```

You can also send the `Host` header explicitly:
```bash
curl -H 'Host: echo.gateway-test' \
  http://<loadbalancer-ip>:80/
```

MagicDNS does not automatically create a hostname for an arbitrary LoadBalancer IP. If a DNS name is desired, create a DNS record that resolves to the LoadBalancer IP and configure the HTTPRoute hostname to match it.

## How It Works

1. **CiliumLoadBalancerIPPool** (`infrastructure/cilium/ip-pool.yaml`) - Defines IP range `192.168.1.240/29` for Cilium Gateway API Services only
2. **CiliumL2AnnouncementPolicy** (`infrastructure/cilium/l2-announcement-policy.yaml`) - Enables L2 announcements for LoadBalancer IPs
3. **Cilium HelmRelease** (`infrastructure/cilium/helmrelease.yaml`) - Has `l2announcements.enabled: true` and `externalIPs.enabled: true`
4. **Gateway** (`apps/gateway-test/app.yaml`) - Creates a LoadBalancer Service that gets an IP from the pool
5. **Tailscale Connector** (`infrastructure/tailscale/connector.yaml`) - Advertises `192.168.1.240/29` to Tailnet
6. **Tailscale Operator** - Manages the Connector

Traffic flow:
- Your Device → Tailscale → [Subnet Route] → LAN → [L2 Announcement] → LoadBalancer Service IP → Envoy → Gateway → Your App

**Important:** Only Gateway API Service IPs in `192.168.1.240/29` are advertised to the Tailnet. Other LoadBalancer Services and other cluster services are NOT exposed through this route.

## Talos-Specific Configuration

The namespace has `pod-security.kubernetes.io/enforce: privileged` label to allow the Connector's privileged init container (needed for IP forwarding).

## Files

### Cilium Configuration
| File | Purpose |
|------|---------|
| `infrastructure/cilium/helmrelease.yaml` | Cilium with L2 announcements enabled |
| `infrastructure/cilium/ip-pool.yaml` | Gateway-only LoadBalancer IP pool (192.168.1.240/29) |
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

# Check the LoadBalancer Service and its Gateway labels
kubectl get svc -n gateway-test cilium-gateway-gateway-test-gateway --show-labels -o yaml

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
