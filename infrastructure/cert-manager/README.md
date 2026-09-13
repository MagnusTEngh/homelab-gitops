#

## How to test

1. Check pods by using kubectl get pods -n cert-manager, look for:
    - cert-manager
    - cert-manager-cainjector
    - cert-manager-webhook
2. Make a test issuer + certificate:

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager-test
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: test-selfsigned
  namespace: cert-manager-test
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-cert
  namespace: cert-manager-test
spec:
  secretName: test-cert-tls
  dnsNames:
    - example.com
  issuerRef:
    name: test-selfsigned
EOF

3. Check the certificate with kubectl get certificate -n cert-manager-test

4. Check the TLS secret with kubectl get secret test-cert-tls -n cert-manager-test

5. Run this kubectl describe certificate test-cert -n cert-manager-test and check
    - Type:    Ready
    - Status:  True
    - Reason:  Ready

6. Clean up by running kubectl delete namespace cert-manager-test
