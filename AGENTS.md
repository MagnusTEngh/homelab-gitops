AGENTS.md
Project Context

This repository manages a Talos Linux Kubernetes homelab cluster using Flux CD for GitOps-based management.

The current environment is:

Kubernetes distribution/OS: Talos Linux

Cluster type: Homelab

Infrastructure: Bare metal

Node count: Single node

Location: Runs on the owner's own physical machine

Cluster management: Flux CD / GitOps

Repository role: This repository is the source of truth for the cluster's declarative configuration.

Important Environment Assumptions

When working in this repository, assume that:

The Kubernetes cluster is a single-node cluster unless the repository explicitly documents otherwise.

The cluster runs on bare-metal hardware, not a cloud provider or virtualized managed Kubernetes service.

The underlying operating system is Talos Linux. Do not assume a traditional Linux userspace, SSH access, systemd, package managers, or the ability to modify the host interactively.

Flux is responsible for reconciling the desired Kubernetes state from this repository.

Changes should generally be made declaratively through Git, rather than by manually modifying resources in the running cluster.

Kubernetes resources should be designed with the constraints of a single-node homelab in mind.

Avoid introducing cloud-provider-specific resources or assumptions unless they are explicitly required by the existing configuration.

Do not assume that high availability, node redundancy, automatic failover, or multiple availability zones exist.

GitOps Workflow

Treat the repository as the desired state of the cluster.

When making changes:

Prefer modifying the appropriate manifests, Helm values, Kustomizations, or other declarative configuration in Git.

Follow the existing repository structure and conventions before introducing new ones.

Prefer changes that Flux can reconcile automatically.

Do not rely on manual kubectl changes as the permanent solution.

If a manual cluster operation is required, clearly distinguish it from the declarative change that should ultimately be committed to the repository.

Validate manifests and configuration where practical before committing changes.

Talos Linux Considerations

Talos Linux is an immutable, minimal operating system designed specifically for Kubernetes.

Agents must not assume that host-level configuration can be performed using conventional Linux administration techniques.

In particular:

Do not suggest SSH-based host administration as a normal workflow.

Do not assume apt, dnf, yum, systemctl, or similar tools are available.

Prefer Talos-native configuration and management mechanisms for host-level changes.

Kubernetes-level configuration should normally be handled through the repository and Flux.

Single-Node Considerations

Because this is currently a single-node cluster:

Workloads do not have node-level redundancy.

Pod anti-affinity and topology constraints intended for multi-node clusters may be inappropriate unless there is a specific reason to use them.

Pod disruption budgets should be considered carefully because unnecessarily strict disruption requirements can prevent workloads from being rescheduled.

Do not add replicas solely for high availability without considering the fact that all replicas currently run on the same node.

Resource requests and limits should be appropriate for a homelab with finite physical resources.

Storage configuration should account for the fact that there is currently only one physical node.

Making Changes

Before changing infrastructure or application configuration:

Inspect the existing repository structure.

Identify how the relevant component is currently deployed and reconciled by Flux.

Reuse existing patterns and conventions where possible.

Make the smallest declarative change that solves the problem.

Validate the resulting configuration where practical.

Consider the implications for a single-node bare-metal cluster.

Avoid introducing unnecessary dependencies on cloud infrastructure or multi-node capabilities.

Repository-Specific Knowledge

Details such as:

Hardware specifications

Talos version

Kubernetes version

Flux version

CNI

Ingress/load-balancing implementation

Storage provider

DNS configuration

Secrets management

Backup strategy

Repository directory structure

Naming conventions

should be determined from the repository itself and its configuration rather than assumed.

If these details conflict with the assumptions in this document, the actual repository configuration takes precedence.

Agent Principle

Treat this as a personal bare-metal homelab, not as a production cloud Kubernetes environment.

Prefer simple, maintainable, declarative solutions that fit the existing Talos + Kubernetes + Flux architecture. Avoid adding operational complexity, infrastructure dependencies