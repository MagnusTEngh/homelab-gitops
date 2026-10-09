# Homelab Gitops

## Goals

### Role based access through tailscale

Kubernetes platform where Tailscale provides secure identity-based access to the cluster, while Kubernetes RBAC controls what each user or group can do.

- Tailscale — secure access to the Kubernetes API without exposing it publicly; users can belong to multiple groups.
- Kubernetes RBAC — maps groups to permissions, namespaces, and resources.
- Flux — manages workload deployment from Git, allowing developers to deploy without broad Kubernetes write access.
- Cilium — provides networking and network policies between workloads.
- Gateway API — manages ingress and application routing.

#### Groups

- guests: access to a few services
- friends: access to more services
- family: access to all services
- developers: access to deploy their own apps
- admins: full access

### Reproducable

Built using declarative configuration and when actions are required, such as bootstrapping or adding secrets, it should be done using scripts.

Manual steps should be described in setup.md

verification steps to check cluster health should be described in verification.md

### Playground

The cluster infrastructure should have enough features to allow experimentation with different technologies.

As an example, storage options should include regular on disk, Longhorn and Garage.

### Room for expansion

It should be possible to add nodes without too much hassle.

### Low maintenance

The Kubernetes homelab should be designed to be as low maintenance as possible.

### Nix for development and verification environment

A nix flake is used to create the environment for interacting with the cluster, working on the repo and verification of functionality.

The flake includes vscode, nvim and the essential tools for Talos and Kubernetes management. It is important that it is not bloated and is kept focused on the task.

### Backups in Jottacloud

All backup solutions should end up in Jottacloud at the end of the day, and there should be a testable pipeline for restoring the cluster state from that backup.
