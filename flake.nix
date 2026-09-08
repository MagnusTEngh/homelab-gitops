{
  description = "Kubernetes / Talos management environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = f:
        nixpkgs.lib.genAttrs systems (system:
          f nixpkgs.legacyPackages.${system}
        );
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          name = "k8s-tools";

          packages = with pkgs; [
            # Kubernetes
            kubectl
            kubernetes-helm
            kustomize
            cilium-cli
            k9s
            stern

            # Talos
            talosctl

            # GitOps
            fluxcd

            # Useful utilities
            curl
            wget
            git
          ];

          shellHook = ''
            echo "Kubernetes management environment"
            echo
            echo "kubectl:  $(kubectl version --client --output=yaml 2>/dev/null | grep gitVersion | head -1 || true)"
            echo "talosctl: $(talosctl version --client 2>/dev/null | head -1 || true)"
            echo "flux:     $(flux --version 2>/dev/null || true)"
            echo
          '';
        };
      });
    };
}
