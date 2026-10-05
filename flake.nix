{
  description = "Development environment for Talos Linux + Kubernetes + Flux homelab";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        packages = {
          inherit (pkgs)
            talosctl
            kubectl
            helm
            flux
            code-server
            jq
            yq
            tree
            exa
            k9s
            kubectx
            kubens
            direnv
            just
            ;
        };

        devShells.default = pkgs.mkShell {
          name = "talos-k8s-flux-env";

          packages = with pkgs; [
            talosctl
            kubectl
            helm
            flux
            code-server
            jq
            yq
            tree
            exa
            k9s
            kubectx
            kubens
            direnv
            just
            git
            curl
            wget
            htop
          ];

          shellHook = ''
            # ============================================================================
            # Talos Linux + Kubernetes + Flux Development Environment
            # ============================================================================
            echo ""
            echo "  ████████╗██████╗ ██████╗ ██╗     ███████╗██████╗ ███████╗"
            echo "  ╚══██╔══╝██╔══██╗██╔══██╗██║     ██╔════╝██╔══██╗██╔════╝"
            echo "     ██║   ██████╔╝██║  ██║██║     █████╗  ██████╔╝█████╗  "
            echo "     ██║   ██╔══██╗██║  ██║██║     ██╔══╝  ██╔══██╗██╔══╝  "
            echo "     ██║   ██║  ██║██████╔╝███████╗███████╗██║  ██║███████╗"
            echo "     ╚═╝   ╚═╝  ╚═╝╚═════╝ ╚══════╝╚══════╝╚═╝  ╚═╝╚══════╝"
            echo ""
            echo "  ╔══════════════════════════════════════════════════════════════════════╗"
            echo "  ║  Talos Linux + Kubernetes + Flux Development Environment        ║"
            echo "  ╚══════════════════════════════════════════════════════════════════════╝"
            echo ""

            # ==========================================================================
            # Talos Linux Environment Variables
            # ==========================================================================
            export TALOS_VERSION="${TALOS_VERSION:-v1.13.7}"
            export TALOS_ENDPOINT="${TALOS_ENDPOINT:-192.168.0.188}"
            export TALOS_NODE="${TALOS_NODE:-$TALOS_ENDPOINT}"
            export TALOSCONFIG="${TALOSCONFIG:-$PWD/talosconfig}"
            export KUBERNETES_VERSION="${KUBERNETES_VERSION:-v1.31.0}"

            echo "  📋 Configuration:"
            echo "    Talos Version:     $TALOS_VERSION"
            echo "    Talos Endpoint:    $TALOS_ENDPOINT"
            echo "    Talos Node:        $TALOS_NODE"
            echo "    Kubernetes Ver:    $KUBERNETES_VERSION"
            echo "    Talos Config:      $TALOSCONFIG"
            echo ""

            # ==========================================================================
            # Kubernetes Environment Variables
            # ==========================================================================
            export KUBECONFIG="${KUBECONFIG:-$PWD/kubeconfig}"
            export KUBE_EDITOR="code-server --wait"

            echo "  ☸️  Kubernetes:"
            echo "    Kubeconfig:        $KUBECONFIG"
            echo ""

            # ==========================================================================
            # Tool Versions
            # ==========================================================================
            echo "  🛠️  Tool Versions:"
            echo "    talosctl:          $(talosctl version --client 2>/dev/null | head -1 || 'not available')"
            echo "    kubectl:           $(kubectl version --client --short 2>/dev/null | head -1 || 'not available')"
            echo "    helm:              $(helm version --short 2>/dev/null | head -1 || 'not available')"
            echo "    flux:              $(flux version 2>/dev/null | head -1 || 'not available')"
            echo "    code-server:       $(code-server --version 2>/dev/null | head -1 || 'not available')"
            echo ""

            # ==========================================================================
            # Aliases
            # ==========================================================================
            echo "  📝 Available Aliases:"
            echo ""

            # code-web alias - Microsoft's official VS Code in browser
            alias code-web='code-server --bind-addr 0.0.0.0:8080 --auth none .'
            echo "    code-web           Start code-server on 0.0.0.0:8080 (no auth)"

            # Talos aliases
            alias talos-version='talosctl version --nodes $TALOS_NODE'
            alias talos-health='talosctl health --nodes $TALOS_NODE'
            alias talos-logs='talosctl logs --nodes $TALOS_NODE'
            alias talos-shell='talosctl shell --nodes $TALOS_NODE'
            echo "    talos-version      Check Talos version"
            echo "    talos-health       Check Talos health"
            echo "    talos-logs         View Talos logs"
            echo "    talos-shell        Open shell on Talos node"

            # Kubernetes aliases
            alias k='kubectl'
            alias kx='kubectx'
            alias kn='kubens'
            alias kget='kubectl get'
            alias kdesc='kubectl describe'
            alias klogs='kubectl logs'
            alias kexec='kubectl exec'
            alias kapply='kubectl apply'
            alias kdel='kubectl delete'
            echo "    k                  kubectl"
            echo "    kx                 kubectx"
            echo "    kn                 kubens"
            echo "    kget, kdesc, etc.  kubectl shortcuts"

            # Flux aliases
            alias flux-check='flux check'
            alias flux-reconcile='flux reconcile source git'
            alias flux-get-kustomizations='flux get kustomizations -A'
            alias flux-get-helmreleases='flux get helmreleases -A'
            alias flux-logs='flux logs --all-namespaces'
            echo "    flux-check          Check Flux health"
            echo "    flux-reconcile     Reconcile Flux sources"
            echo "    flux-get-*         Flux resource getters"

            # Utility aliases
            alias j='just'
            alias g='git'
            alias yq='yq'
            alias jq='jq'
            echo "    j                  just"
            echo "    g                  git"
            echo ""

            # ==========================================================================
            # Helper Functions
            # ==========================================================================
            echo "  🎯 Helper Functions:"
            echo ""

            # Talos helper functions
            talos-extensions() {
              talosctl -n $TALOS_NODE get extensions
            }

            talos-machineconfig() {
              talosctl -n $TALOS_NODE get machineconfig -o yaml
            }

            talos-disk-usage() {
              talosctl -n $TALOS_NODE df -h
            }

            echo "    talos-extensions    List Talos extensions"
            echo "    talos-machineconfig  Get machine config"
            echo "    talos-disk-usage     Check disk usage on Talos node"

            # Kubernetes helper functions
            k-node-ready() {
              kubectl wait --for=condition=Ready nodes --all --timeout=300s
            }

            k-pods-ready() {
              kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}' | grep -v Running | grep -v Completed | grep -v "Terminating" || echo "All pods are ready or terminating"
            }

            k-clean-evicted() {
              kubectl get pods -A --field-selector=status.phase==Failed -o name | xargs -r kubectl delete
            }

            echo "    k-node-ready        Wait for all nodes to be ready"
            echo "    k-pods-ready        Check if all pods are ready"
            echo "    k-clean-evicted     Remove evicted pods"

            # Flux helper functions
            flux-sync() {
              flux reconcile source git flux-system && \
              flux reconcile kustomization flux-system --with-source
            }

            flux-watch() {
              watch -n 2 -d 'flux get kustomizations -A'
            }

            echo "    flux-sync           Reconcile Flux sources and kustomizations"
            echo "    flux-watch          Watch Flux kustomizations"

            # Combined helper functions
            cluster-status() {
              echo "=== Talos Status ==="
              talosctl version --nodes $TALOS_NODE
              echo ""
              echo "=== Kubernetes Status ==="
              kubectl get nodes -o wide
              echo ""
              echo "=== Flux Status ==="
              flux check
            }

            echo "    cluster-status      Show Talos, Kubernetes, and Flux status"
            echo ""

            # ==========================================================================
            # Environment Setup
            # ==========================================================================
            echo "  ℹ️  Environment Setup:"
            echo ""

            # Set up talosctl config if talosconfig exists
            if [ -f "$TALOSCONFIG" ]; then
              export TALOSCONFIG
              echo "    ✓ Talos config loaded from: $TALOSCONFIG"
            else
              echo "    ⚠ Talos config not found at: $TALOSCONFIG"
              echo "      Create it with: talosctl config endpoint $TALOS_ENDPOINT"
            fi

            # Set up kubeconfig if it exists
            if [ -f "$KUBECONFIG" ]; then
              export KUBECONFIG
              echo "    ✓ Kubernetes config loaded from: $KUBECONFIG"
            else
              echo "    ⚠ Kubernetes config not found at: $KUBECONFIG"
              echo "      Create it with: talosctl kubeconfig $KUBECONFIG"
            fi

            echo ""
            echo "  ✨ Development environment is ready!"
            echo ""
            echo "  Quick Start:"
            echo "    1. Set up Talos: talosctl config endpoint $TALOS_ENDPOINT"
            echo "    2. Set up Kubernetes: talosctl kubeconfig $KUBECONFIG"
            echo "    3. Start coding: code-web"
            echo "    4. Check cluster: cluster-status"
            echo ""
          ;''
        };
      }
    );
}
