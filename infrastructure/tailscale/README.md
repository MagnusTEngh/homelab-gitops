# Tailscale for Gateway API Access

This enables access to your Cilium Gateway API services through Tailscale without installing Tailscale on your nodes. Only Gateway API addresses are exposed - not the entire cluster.

## Architecture

```
Your Machine (Tailnet)
  --> [Tailscale Subnet Route: 192.168.100.0/24]
  --> [Cilium LB IP Pool: 192.168.100.0/24]
  --> Gateway Service (LoadBalancer IP from pool)
  --> Your Application
```

A dedicated IP pool is created for Gateway API, and a Tailscale Connector advertises only that pool's CIDR to your Tailnet. This ensures **only Gateway API addresses** are accessible through Tailscale, not other cluster services.

## Setup

### 1. Create OAuth Client in Tailscale

1. Go to Tailscale admin console → OAuth clients
2. Create a new OAuth client with tag: `tag:k8s-operator`
3. Note the `clientId` and `clientSecret`

### 2. Create Kubernetes Secrets

```bash
# Create OAuth secret for the operator
kubectl create secret generic operator-oauth -n tailscale \
  --from-literal=clientId=<your-client-id> \
  --from-literal=clientSecret=<your-client-secret>
```

### 3. Update IP Pool CIDR (Optional)

Edit `ippool.yaml` if you want a different CIDR for Gateway API:

```yaml
spec:
  blocks:
    - cidr: "192.168.100.0/24"  # Or any other /24 not used elsewhere
```

Then update `connector.yaml` to match:

```yaml
spec:
  subnetRouter:
    advertiseRoutes:
      - "192.168.100.0/24"
```

### 4. Access Services

Once the Connector is running and the subnet route is accepted:

```bash
# The Gateway will get IP 192.168.100.1 (as configured in gateway-test/app.yaml)
curl http://192.168.100.1
```

Or use MagicDNS if enabled:
```bash
curl http://192-168-100-1.your-tailnet.ts.net
```

## How It Works

1. **CiliumLoadBalancerIPPool** (`ippool.yaml`) - Defines a dedicated IP range for Gateway API
2. **Gateway** (`apps/gateway-test/app.yaml`) - Uses the IP pool, gets `192.168.100.1`
3. **Tailscale Connector** (`connector.yaml`) - Advertises only `192.168.100.0/24` to Tailnet
4. **Tailscale Operator** - Manages the Connector

Traffic flow:
- Your Device → Tailscale → Connector → Cilium LoadBalancer IP → Gateway → Your App

**Important:** Only IPs in `192.168.100.0/24` are accessible. Other cluster services (with different IPs) are NOT exposed.

## Security

- **Isolated exposure**: Only the dedicated IP pool is advertised to Tailscale
- **No node access**: Tailscale is not installed on nodes
- **Controlled via ACLs**: Use Tailscale ACLs to restrict which devices can access `192.168.100.0/24`
- **Gateway API only**: Regular Services (ClusterIP) are not exposed

## Files

| File | Purpose |
|------|---------|
| `helmrelease.yaml` | Tailscale operator installation |
| `helmrepository.yaml` | Helm chart repository |
| `connector.yaml` | Connector CR (subnet router for 192.168.100.0/24) |
| `ippool.yaml` | Cilium LoadBalancer IP Pool (NEW) |
| `namespace.yaml` | Namespace |
| `kustomization.yaml` | Kustomization |
| `README.md` | This file |

## Troubleshooting

### Connector won't authenticate
```bash
kubectl logs -n tailscale -l app.kubernetes.io/name=tailscale-operator
kubectl get secret -n tailscale operator-oauth
```

### Subnet route not appearing
```bash
kubectl get connector -n tailscale -o yaml
kubectl logs -n tailscale -l app.kubernetes.io/name=tailscale-connector
```

Check Tailscale admin console → Machines → Find the Connector device → Check if subnet route is pending approval.

### Gateway doesn't have the right IP
```bash
# Check Gateway status
kubectl get gateway -n gateway-test -o yaml

# Check IP pool
kubectl get ciliumloadbalancerippool -n tailscale

# Check if Cilium is using the pool
kubectl get svc -n gateway-test -o yaml | grep cilium.io/lb-ipam
```

### Can't access Gateway
```bash
# From a Tailnet device, test connectivity
tailscale ping 192.168.100.1

# Check if route is active
tailscale status

# Check Cilium LB IPAM
kubectl -n kube-system exec cilium-xxx -- cilium lb ip list
```

## References

- [Tailscale Kubernetes Operator](https://tailscale.com/docs/kubernetes-operator)
- [Tailscale Connector (Subnet Router)](https://tailscale.com/docs/kubernetes-operator/connector)
- [Cilium LoadBalancer IPAM](https://docs.cilium.io/en/stable/network/loadbalancer/
- [Cilium Gateway API](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/)
- [Tailscale OAuth Clients](https://tailscale.com/kb/oauth-clients)
