

flux check

flux get kustomizations -A

flux get helmreleases -A

kubectl get events -n kube-system --sort-by=.lastTimestamp


Monitoring

watch -n 2 -d 'kubectl -n kube-system get pods -o wide'
