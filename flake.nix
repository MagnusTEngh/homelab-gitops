{
  description = "Homelab GitOps - Development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      devShells.${system}.default = pkgs.mkShell {
        name = "homelab-gitops";

        buildInputs = with pkgs; [
          kubectl
          kubeconform
          yq-go
          yamllint
          shellcheck
          pluto
          pre-commit
          git
          curl
          wget
          gnused
          gnutar
          gzip
          vscode-fhs
        ];

        shellHook = ''
          alias vscode-web='code serve-web --host 0.0.0.0 --port 8000 --without-connection-token --accept-server-license-terms'

          echo "Development environment for homelab-gitops"
          echo "Available tools: kubectl, kubeconform, yq, yamllint, shellcheck, pluto, pre-commit, code"
          echo ""
          echo "Launch VS Code web UI (LAN, NO PASSWORD):"
          echo "  vscode-web"
        '';
      };
    };
}
