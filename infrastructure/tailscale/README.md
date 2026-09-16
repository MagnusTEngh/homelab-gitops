# Tailscale Integration for Gateway API

This directory contains the configuration for integrating Tailscale with your Kubernetes cluster's Gateway API, allowing you to access your Gateway API addresses through Tailscale without installing Tailscale on every node.

## Architecture

The setup uses the **Tailscale Connector** approach:

1. **Tailscale Operator** - Manages Tailscale resources in Kubernetes
2. **Tailscale Connector** - A single pod that joins your Tailnet and can route traffic to Kubernetes services
3. **Cilium Gateway API** - Your existing Gateway API implementation
4. **Gateway Services** - Exposed through Tailscale via the connector

```
+------------------+     +---------------------+     +------------------+
|  Your Machine    |-----|  Tailscale Connector |-----|  Gateway API     |
|  (Tailnet)       |     |  (Kubernetes Pod)   |     |  (Cilium)        |
+------------------+     +---------------------+     +------------------+
```

## Setup Steps

### 1. Create Tailscale Auth Key

You need a Tailscale authentication key to allow the connector to join your Tailnet.

#### Generate an Auth Key:

```bash
# Generate a reusable auth key (recommended)
tailscale key generate --reusable=true --ephemeral=false

# Or generate an ephemeral key (expires in 90 days, single-use)
tailscale key generate --ephemeral=true
```

Copy the generated key (starts with `tskey-`).

#### Create Kubernetes Secret:

```bash
kubectl create secret generic tailscale-auth -n tailscale \
  --from-literal=TS_AUTHKEY=tskey-your-auth-key-here
```

**Important:** The key is sensitive. Treat it like a password. Anyone with this key can join your Tailnet.

### 2. Verify Tailscale Operator Installation

After Flux applies the configuration, verify the operator is running:

```bash
kubectl get pods -n tailscale
```

You should see:
- `tailscale-operator-*` - The operator pod
- `tailscale-connector-*` - The connector pod (after auth key is provided)

### 3. Find Your Connector's Tailscale IP

Once the connector pod is running and authenticated:

```bash
kubectl get pods -n tailscale -l app.kubernetes.io/name=tailscale-connector

# Get the Tailscale IP of the connector
kubectl exec -n tailscale <connector-pod-name> -- tailscale status --json | jq '.Self.TailnetIP'
```

This will output something like `100.x.y.z`. This is the IP that your Gateway API services will be accessible from within your Tailnet.

### 4. Access Your Gateway API Services

The Gateway API services are now accessible through Tailscale. You can access them using:

#### Option A: Direct IP Access

```bash
# Use the connector's Tailscale IP
curl http://100.x.y.z
```

#### Option B: Use Tailscale MagicDNS (Recommended)

Enable MagicDNS in your Tailscale admin console, then:

```bash
# Access using the hostname defined in your HTTPRoute
curl http://echo.gateway-test

# Or if you've configured a specific domain
curl http://echo.gateway-test.your-tailnet.ts.net
```

#### Option C: Add to Local DNS

```bash
# On your local machine, add to /etc/hosts
echo "100.x.y.z echo.gateway-test" | sudo tee -a /etc/hosts

# Then access
curl http://echo.gateway-test
```

## Configuration Files

| File | Purpose |
|------|---------|
| `namespace.yaml` | Creates the `tailscale` namespace |
| `helmrepository.yaml` | Adds the Tailscale Helm chart repository |
| `helmrelease.yaml` | Deploys the Tailscale operator with connector mode |
| `kustomization.yaml` | Bundles all Tailscale resources |

## Customization

### Change Connector Replicas

Edit `helmrelease.yaml`:

```yaml
connector:
  enabled: true
  kind: Deployment
  replicas: 2  # Change from 1 to 2 for redundancy
```

### Change Tailscale Tags

To apply [ACLs](https://tailscale.com/kb/acls/) to your connector:

```yaml
connector:
  enabled: true
  tags:
    - tag: k8s-connector
    - tag: gateway-api
```

Then update your Tailscale ACLs to allow traffic to these tags.

### Configure Subnet Routes (Optional)

If you want the connector to advertise routes to your Kubernetes cluster's internal network:

```yaml
connector:
  enabled: true
  advertiseRoutes:
    - 10.0.0.0/8
    - 172.16.0.0/12
    - 192.168.0.0/16
```

**Warning:** Only enable this if you understand the networking implications and have proper ACLs in place.

## Troubleshooting

### Connector Won't Authenticate

```bash
# Check operator logs
kubectl logs -n tailscale -l app.kubernetes.io/name=tailscale-operator

# Check connector logs
kubectl logs -n tailscale -l app.kubernetes.io/name=tailscale-connector

# Verify the secret exists
kubectl get secret -n tailscale tailscale-auth
```

Common issues:
- Auth key is expired or already used (for ephemeral keys)
- Auth key doesn't have the correct permissions
- Secret name or key doesn't match what's in `helmrelease.yaml`

### Can't Access Gateway Services

```bash
# Check if the connector has a Tailscale IP
kubectl exec -n tailscale <connector-pod> -- tailscale status

# Check Cilium Gateway status
kubectl get gateway -n gateway-test

# Check HTTPRoute status
kubectl get httproute -n gateway-test -o yaml

# Check Cilium logs
kubectl logs -n kube-system -l k8s-app=cilium
```

### Connection Timeout

If you can ping the connector's Tailscale IP but can't access services:

```bash
# Test connectivity from your local machine
tailscale ping 100.x.y.z

# Test if the port is open
nc -zv 100.x.y.z 80

# Check if the service is running in Kubernetes
kubectl get svc -n gateway-test
```

The Gateway needs to be configured to listen on the correct addresses. See the Gateway API configuration in your app manifests.

## Security Considerations

1. **Auth Key Security**: The auth key grants access to your Tailnet. Rotate it regularly.

2. **ACLs**: Configure Tailscale ACLs to restrict which devices/users can access your Gateway services.

3. **Network Policies**: Use Cilium NetworkPolicies to restrict traffic within your cluster.

4. **Minimal Permissions**: Only grant the connector the minimum permissions needed.

## Cleanup

To remove Tailscale integration:

```bash
# Delete the namespace (Flux will recreate it if the kustomization is still active)
kubectl delete ns tailscale

# Or disable in Flux
flux suspend kustomization tailscale -n flux-system
```

## References

- [Tailscale Kubernetes Operator](https://tailscale.com/kb/installation/kubernetes/)
- [Tailscale Connector Documentation](https://tailscale.com/kb/networking/connectors/)
- [Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
- [Cilium Gateway API](https://docs.cilium.io/en/stable/network/gateway-api/)
