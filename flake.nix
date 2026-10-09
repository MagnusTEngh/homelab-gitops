{
  description = "Homelab GitOps - Development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
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
          python3
          python3Packages.pip
        ];

        shellHook = ''
          echo "Development environment for homelab-gitops"
          echo "Available tools: kubectl, kubeconform, yq, yamllint, shellcheck, pluto, pre-commit"
        '';
      };
    };
}
