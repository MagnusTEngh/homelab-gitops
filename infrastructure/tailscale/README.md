# Tailscale for Gateway API Access

This enables access to your Cilium Gateway API services through Tailscale without installing Tailscale on your nodes.

## Architecture

```
Your Machine (Tailnet) --> [Subnet Route via Connector] --> Gateway Service (ClusterIP) --> Your Services
```

A Tailscale Connector pod joins your Tailnet and advertises your Kubernetes Service CIDR. This allows direct access to Gateway API services via their ClusterIP addresses from any device on your Tailnet.

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

### 3. Update Connector CIDR

Edit `connector.yaml` and update the `advertiseRoutes` to match your Kubernetes Service CIDR:

```yaml
spec:
  subnetRouter:
    advertiseRoutes:
      - "10.96.0.0/12"  # Default Kubernetes Service CIDR
```

If your cluster uses a different Service CIDR (check with `kubectl cluster-info dump | grep service-cluster-ip-range`), update accordingly.

### 4. Access Services

Once the Connector is running and the subnet route is accepted:

1. Find your Gateway's ClusterIP:
   ```bash
   kubectl get gateway -n gateway-test -o jsonpath='{.status.addresses[0].value}'
   ```

2. Access the service from any device on your Tailnet:
   ```bash
   curl http://<gateway-cluster-ip>:80
   ```

   Or use MagicDNS if enabled:
   ```bash
   curl http://<gateway-cluster-ip>.your-tailnet.ts.net
   ```

## Files

- `helmrelease.yaml` - Tailscale operator installation
- `helmrepository.yaml` - Helm chart repository
- `connector.yaml` - Connector custom resource (subnet router)
- `namespace.yaml` - Namespace
- `kustomization.yaml` - Kustomization

## How It Works

1. **Tailscale Operator** manages the Connector custom resource
2. **Connector Pod** joins your Tailnet and advertises the Service CIDR route
3. **Cilium Gateway API** creates a Service with a ClusterIP for each Gateway
4. **Subnet Route** allows Tailnet devices to reach ClusterIPs directly
5. Traffic flows: Your Device → Tailscale → Connector → Kubernetes Service (ClusterIP) → Gateway → Your App

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

### Can't access Gateway
```bash
# Check Gateway status
kubectl get gateway -n gateway-test -o yaml

# Check if Connector has the route
kubectl exec -n tailscale <connector-pod> -- tailscale status
```

### Verify routing
From a device on your Tailnet:
```bash
# Try to ping the Gateway ClusterIP
tailscale ping <gateway-ip>

# Check if route is active
tailscale status
```

## References

- [Tailscale Kubernetes Operator](https://tailscale.com/docs/kubernetes-operator)
- [Tailscale Connector (Subnet Router)](https://tailscale.com/docs/kubernetes-operator/connector)
- [Cilium Gateway API](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/)
- [Tailscale OAuth Clients](https://tailscale.com/kb/oauth-clients)
