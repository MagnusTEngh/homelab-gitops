# Clusters

Command to bootstrap flux:

nix run nixpkgs#fluxcd -- bootstrap github --token-auth --owner=MagnusTEngh --repository=homelab-gitops --branch=main --path=clusters/yggdrasil --personal

Monitoring:

nix run nixpkgs#fluxcd -- get kustomizations --watch
