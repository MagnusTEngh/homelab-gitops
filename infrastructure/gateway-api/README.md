# Gateway API

Get standard install by running

curl -L \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml \
  -o infrastructure/gateway-api/gateway-api-crds.yaml



## How to test

1. create test gateway

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: gateway-test
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echo
  namespace: gateway-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: echo
  template:
    metadata:
      labels:
        app: echo
    spec:
      containers:
        - name: echo
          image: hashicorp/http-echo:1.0
          args:
            - "-text=hello from gateway api"
          ports:
            - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: echo
  namespace: gateway-test
spec:
  selector:
    app: echo
  ports:
    - port: 80
      targetPort: 5678
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: test-gateway
  namespace: gateway-test
spec:
  gatewayClassName: cilium
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: Same
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: echo
  namespace: gateway-test
spec:
  parentRefs:
    - name: test-gateway
  rules:
    - backendRefs:
        - name: echo
          port: 80
EOF



2. kubectl get gateway -n gateway-test. Should return something like
NAME           CLASS    ADDRESS        PROGRAMMED
test-gateway   cilium   192.168.1.50   True

3. kubectl describe gateway test-gateway -n gateway-test

4. kubectl get httproute -n gateway-test

5. kubectl describe httproute echo -n gateway-test
Accepted: True
ResolvedRefs: True

6. get gateway daress and run curl http://$GATEWAY
GATEWAY=$(kubectl get gateway test-gateway \
  -n gateway-test \
  -o jsonpath='{.status.addresses[0].value}')

echo "$GATEWAY"

Simple test: curl http://<talos-node-ip>

cleanup: kubectl delete namespace gateway-test
