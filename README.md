

flux check

flux get kustomizations -A

flux get helmreleases -A

kubectl get events -n kube-system --sort-by=.lastTimestamp