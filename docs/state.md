# Cluster State Audit

This document audits the repository against each goal in README.md, documenting what exists, what is missing, and any inconsistencies.

## 1. Tailscale + RBAC

### Goal
Kubernetes platform where Tailscale provides secure identity-based access to the cluster, while Kubernetes RBAC controls what each user or group can do. Groups: guests, friends, family, developers, admins.

### What Exists

- **Tailscale Operator**: HelmRelease at `infrastructure/tailscale/helmrelease.yaml` deploys `tailscale-operator` v1.102.4 from the tailscale HelmRepository (`infrastructure/tailscale/helmrepository.yaml`).
- **Tailscale Connector**: `infrastructure/tailscale/connector.yaml` defines a Connector resource `k8s-subnet-router` that advertises routes `192.168.1.240/29` with tag `tag:k8s`.
- **Tailscale Namespace**: `infrastructure/tailscale/namespace.yaml` creates the `tailscale` namespace.
- **Secret Reference**: Tailscale HelmRelease references a secret via `valuesFrom: - kind: Secret, name: tailscale-oauth, targetPath: oauth` at `infrastructure/tailscale/helmrelease.yaml:19-21`.
- **Flux Kustomization**: Tailscale is registered in `clusters/yggdrasil/yggdrasil.yaml` with `dependsOn: cilium`.
- **Verification**: `validation.md` has a Tailscale section with pod status and service checks.

### What is Missing

- **RBAC Configuration**: No Role, ClusterRole, RoleBinding, or ClusterRoleBinding resources exist for the groups (guests, friends, family, developers, admins). No mapping from Tailscale groups to Kubernetes RBAC.
- **Tailscale Auth Key Secret**: The `tailscale-oauth` secret referenced in the HelmRelease is not defined in this repo (correct per AGENTS.md - it should be in the secrets repo and listed in docs/secrets.md).
- **Group Definitions**: No Kubernetes Group objects or Tailscale ACL tags that map to the README groups.
- **Documentation**: No documentation of how Tailscale groups map to Kubernetes RBAC roles.

### Inconsistencies

- README.md defines groups (guests, friends, family, developers, admins) but no RBAC manifests implement them. `validation.md` has no RBAC verification steps.
- `validation.md` Tailscale section checks pod status but does not verify connectivity or route advertisement.
- The Tailscale Connector advertises `192.168.1.240/29` but there's no documentation of what this subnet is for or how it relates to the cluster's `192.168.0.0/24` LAN.

---

## 2. Reproducible

### Goal
Built using declarative configuration. Manual steps described in setup.md. Verification steps in verification.md.

### What Exists

- **Declarative Configuration**: All infrastructure components (Cilium, cert-manager, Gateway API, Tailscale, Longhorn, local-path-provisioner, jottacloud-backup) are defined as HelmReleases or manifests under `infrastructure/` and `apps/`.
- **Flux GitOps**: `clusters/yggdrasil/yggdrasil.yaml` defines Kustomizations with proper `dependsOn` ordering (cilium -> cert-manager, gateway-api, tailscale, local-path-provisioner -> jottacloud-backup -> gateway-test).
- **setup.md**: Exists but is empty (only contains `# Setup`).
- **verification.md**: Contains comprehensive verification steps for Flux, Kubernetes Cluster, Talos Linux, Cilium, Longhorn, Gateway API, Cert-Manager, and Tailscale.
- **Bootstrap Script**: `talos/scripts/control-planes.sh` contains the full Talos bootstrap sequence with Cilium installation.
- **Node Configuration**: `talos/nodes/cp_192.168.0.188.yaml` defines machine install disk and EPHEMERAL volume.
- **Talos Patches**: `talos/patches/` contains patches for longhorn.yaml, remove_cni.yaml, wakeonlan.yaml, workload-on-controlplane.yaml.

### What is Missing

- **setup.md Content**: setup.md is empty. Per README, it should contain manual steps like bootstrapping Talos, Cilium, Flux, and adding secrets. The bootstrap script exists but is not documented in setup.md.
- **Secret Setup Steps**: No documented steps for creating the `tailscale-oauth` secret, `rclone-config` secret (referenced in `infrastructure/jottacloud-backup/cronjob.yaml:34`), or `flux-system` secret (referenced in `clusters/yggdrasil/flux-system/gotk-sync.yaml:13`).
- **Flux Bootstrap Steps**: No steps for running `flux bootstrap` to generate the `gotk-*.yaml` files.
- **Talos Initial Setup**: `control-planes.sh` exists but setup.md doesn't reference it or explain its usage.

### Inconsistencies

- README.md says "Manual steps should be described in setup.md" but setup.md is empty.
- `talos/scripts/control-planes.sh` installs Cilium v1.20.1 via Helm, but `infrastructure/cilium/helmrelease.yaml` pins Cilium to v1.20.2. Version mismatch between bootstrap script and GitOps manifest.
- `control-planes.sh` line 25 sets `CILIUM_VERSION="1.20.1"` but `infrastructure/cilium/helmrelease.yaml:8` has `version: "1.20.2"`.
- `validation.md` has verification steps but they assume cluster access (kubectl, talosctl) which agents cannot use per AGENTS.md.

---

## 3. Playground

### Goal
The cluster infrastructure should have enough features to allow experimentation with different technologies. Storage options should include regular on disk, Longhorn, and Garage.

### What Exists

- **Cilium**: CNI and kube-proxy replacement with Gateway API support, L2 announcements, externalIPs. `infrastructure/cilium/helmrelease.yaml`.
- **Gateway API**: CRDs and GatewayClass defined in `infrastructure/gateway-api/`. `gateway-api-crds.yaml` and `gateway-class.yaml`.
- **Cert-Manager**: HelmRelease v1.21.1 at `infrastructure/cert-manager/helmrelease.yaml`.
- **Longhorn**: HelmRelease v1.12.1 at `infrastructure/longhorn/helmrelease.yaml` with defaultDataPath `/var/mnt/longhorn` and defaultReplicaCount 1 (commented as single node).
- **Local Path Provisioner**: HelmRelease v0.0.38 at `infrastructure/local-path-provisioner/helmrelease.yaml` with defaultClass true and nodePathMap pointing to `/var/mnt/local-path-provisioner`.
- **Jottacloud Backup**: CronJob at `infrastructure/jottacloud-backup/cronjob.yaml` syncing `/var/mnt/local-path-provisioner` to `jottacloud:homelab-backup` using rclone.
- **Gateway Test App**: `apps/gateway-test/` deploys an echo service with Gateway API HTTPRoute.
- **Talos Extensions**: `control-planes.sh` requires `siderolabs/iscsi-tools` and `siderolabs/util-linux-tools` extensions for Longhorn. `talos/patches/longhorn.yaml` configures extraMounts for `/var/mnt/longhorn`.

### What is Missing

- **Garage**: Not present. README mentions Garage as a storage option but no manifests exist.
- **StorageClass for Garage**: No Garage-related StorageClass or provisioner.
- **Multiple Storage Options**: Only Longhorn and local-path-provisioner are deployed. No Garage or other storage backends.
- **Ingress Controller**: Gateway API is installed but no ingress controller (Cilium Gateway API controller is enabled but no actual ingress setup beyond the test app).

### Inconsistencies

- README.md mentions Garage as a storage option but it's not implemented. No issue or TODO tracked.
- `infrastructure/jottacloud-backup/cronjob.yaml` backs up from `/var/mnt/local-path-provisioner` but Longhorn uses `/var/mnt/longhorn`. Only local-path-provisioner data is backed up, not Longhorn volumes.

---

## 4. Room for Expansion

### Goal
It should be possible to add nodes without too much hassle.

### What Exists

- **Single-Node Comments**: Longhorn HelmRelease has comments noting single-node settings: `defaultReplicaCount: 1` (line 22) and `defaultClassReplicaCount: 1` (line 26) with note "single node; raise to 2-3 when more nodes are added".
- **Cilium Operator Replicas**: `infrastructure/cilium/helmrelease.yaml:77` has `operator: replicas: 1` - should be increased for multi-node.
- **Hardware Documentation**: `hardware.md` has a table for nodes and instructions for adding a node (add row to table, create node config, check schematic, update single-node settings).
- **Node Config**: `talos/nodes/cp_192.168.0.188.yaml` defines the control plane node with disk layout.
- **Talos Patches**: Patches in `talos/patches/` are designed to work across nodes.

### What is Missing

- **Additional Nodes**: Only cp1 (192.168.0.188) is defined. No worker nodes.
- **Multi-Node Networking**: No documentation on how to configure networking for additional nodes.
- **Load Balancing**: No external load balancer or strategy for multi-control-plane nodes.
- **Etcd Configuration**: No multi-node etcd configuration.

### Inconsistencies

- `hardware.md` says "Currently a single control-plane node that also runs workloads" and provides instructions for adding nodes, but no actual multi-node configs exist.
- `talos/nodes/cp_192.168.0.188.yaml` defines a 300 GiB partition for local-path-provisioner but `hardware.md` has TODO for disk details.
- The Talos schematic in `control-planes.sh` (`TALOS_SCHEMATIC`) must include extensions for Longhorn, but there's no verification that it works for additional nodes.

---

## 5. Low Maintenance

### Goal
The Kubernetes homelab should be designed to be as low maintenance as possible.

### What Exists

- **Flux Automation**: All infrastructure is managed by Flux CD with automatic reconciliation (intervals set: cilium 30m, cert-manager 1h, gateway-api 10m, tailscale 30m, local-path-provisioner 1h, jottacloud-backup 10m, gateway-test 10m).
- **Renovate**: `renovate.json` is configured with dependency dashboard, minimum release age 14 days, no automerge, major updates require approval. `renovate.yml` in `.github/workflows/`.
- **Validation Workflow**: `.github/workflows/validate.yaml` runs yamllint, kustomize-build, helm-lint, kubeconform, pluto on PRs.
- **Pre-commit Hooks**: `.pre-commit-config.yaml` exists for local validation.
- **Resource Limits**: Cilium HelmRelease has resource requests and limits defined (`infrastructure/cilium/helmrelease.yaml:79-87`).
- **Longhorn Settings**: Pre-upgrade checker disabled (`preUpgradeChecker.jobEnabled: false`) to reduce maintenance overhead.

### What is Missing

- **Monitoring**: No monitoring stack (Prometheus, Grafana) for cluster health visibility.
- **Logging**: No centralized logging.
- **Alerting**: No alerting configuration.
- **Backup Verification**: No verification that jottacloud-backup CronJob actually succeeds.

### Inconsistencies

- The validation workflow in `.github/workflows/validate.yaml` is missing kustomize paths for several components:
  - Missing: `infrastructure/gateway-api` (has kustomization.yaml)
  - Missing: `infrastructure/tailscale` (has kustomization.yaml)
  - Missing: `infrastructure/cert-manager` (has kustomization.yaml)
  - Missing: `infrastructure/local-path-provisioner` (has kustomization.yaml)
  - Missing: `infrastructure/jottacloud-backup` (has kustomization.yaml)
  - Only includes: flux-system, cilium, longhorn, gateway-test
- `validate.yaml` helm-lint step uses `|| true` which allows failures to pass.

---

## 6. Nix Environment

### Goal
A nix flake is used to create the environment for interacting with the cluster, working on the repo and verification of functionality. Includes vscode, nvim and essential tools. Kept focused.

### What Exists

- **Nothing**: No Nix flake, no `flake.nix`, no `shell.nix`, no Nix-related files found in the repository.

### What is Missing

- **Nix Flake**: Complete absence of Nix configuration.
- **Development Environment**: No Nix-based dev environment definition.
- **Tool Definitions**: No Nix expressions for vscode, nvim, kubectl, talosctl, flux, helm, etc.

### Inconsistencies

- README.md explicitly lists "Nix for development and verification environment" as a goal, but no Nix files exist in the repository.

---

## 7. Jottacloud Backups

### Goal
All backup solutions should end up in Jottacloud, with a testable pipeline for restoring cluster state.

### What Exists

- **Jottacloud Backup CronJob**: `infrastructure/jottacloud-backup/cronjob.yaml` runs rclone sync daily at 03:00, syncing `/var/mnt/local-path-provisioner` to `jottacloud:homelab-backup`.
- **Jottacloud Backup Namespace**: `infrastructure/jottacloud-backup/namespace.yaml` creates `jottacloud-backup` namespace.
- **Flux Integration**: Registered in `clusters/yggdrasil/yggdrasil.yaml` with `dependsOn: local-path-provisioner`.
- **Secret Reference**: Uses `rclone-config` secret (line 34: `secretName: rclone-config`).
- **Verification**: `validation.md` has no Jottacloud backup verification section.

### What is Missing

- **Backup of Longhorn Volumes**: The CronJob only backs up `/var/mnt/local-path-provisioner`. Longhorn volumes at `/var/mnt/longhorn` are NOT backed up.
- **Backup of Etcd**: No etcd backup configuration. Talos etcd backup not configured.
- **Backup of Flux State**: No backup of Flux GitRepository state or cluster state.
- **Restore Pipeline**: No documented or implemented restore pipeline from Jottacloud.
- **Restore Testing**: No verification that restores work.
- **Backup Verification**: No verification steps in `validation.md` for jottacloud-backup.

### Inconsistencies

- README.md says "a testable pipeline for restoring the cluster state from that backup" but no restore pipeline exists.
- The backup only covers local-path-provisioner data, not the primary storage (Longhorn) or etcd.

---

## Cross-Cutting Issues

### Version Pinning

- **Helm Charts**: All HelmReleases have pinned versions:
  - cilium: 1.20.2 (`infrastructure/cilium/helmrelease.yaml:8`)
  - tailscale-operator: 1.102.4 (`infrastructure/tailscale/helmrelease.yaml:8`)
  - longhorn: 1.12.1 (`infrastructure/longhorn/helmrelease.yaml:8`)
  - cert-manager: v1.21.1 (`infrastructure/cert-manager/helmrelease.yaml:8`)
  - local-path-provisioner: 0.0.38 (`infrastructure/local-path-provisioner/helmrelease.yaml:8`)
- **Container Images**: gateway-test uses digest-pinned image: `hashicorp/http-echo:1.0@sha256:fcb75f691c8b0414d670ae570240cbf95502cc18a9ba57e982ecac589760a186` (`apps/gateway-test/app.yaml:15`)
- **jottacloud-backup CronJob**: Uses rclone image with tag only: `rclone/rclone:v1.68.1` (`infrastructure/jottacloud-backup/cronjob.yaml:14`) - NOT digest-pinned.
- **Talos Version**: Pinned to v1.13.7 in `talos/scripts/control-planes.sh:10`.
- **GitHub Actions**: Pinned by commit SHA in `validate.yaml` and `renovate.yml`.
- **Unpinned**: rclone image in jottacloud-backup CronJob is tag-only, not digest-pinned.

### Secret References

- **tailscale-oauth**: Referenced in `infrastructure/tailscale/helmrelease.yaml:19-21` via `valuesFrom`. Not defined in repo.
- **rclone-config**: Referenced in `infrastructure/jottacloud-backup/cronjob.yaml:34`. Not defined in repo.
- **flux-system**: Referenced in `clusters/yggdrasil/flux-system/gotk-sync.yaml:13` via `secretRef`. Not defined in repo.
- **docs/secrets.md**: Does not exist. Per AGENTS.md, all secrets should be listed here.

### Kustomize Paths Missing from validate.yaml

The `.github/workflows/validate.yaml` kustomize-build job only validates:
- `./clusters/yggdrasil/flux-system`
- `./infrastructure/cilium`
- `./infrastructure/longhorn`
- `./apps/gateway-test`

Missing from validation:
- `./infrastructure/cert-manager`
- `./infrastructure/gateway-api`
- `./infrastructure/tailscale`
- `./infrastructure/local-path-provisioner`
- `./infrastructure/jottacloud-backup`

### Plaintext Secrets

- No plaintext secrets found in the repository (checked for base64 encoded strings, password fields, etc.). All secret references use `secretRef` or `valuesFrom` patterns.

### Hardware Documentation Gaps

- `hardware.md`: cp1 has TODO for machine model, CPU, RAM, OS disk size, data disk(s).
- `talos/nodes/cp_192.168.0.188.yaml`: Defines disk `/dev/nvme0n1` with 300 GiB partition for local-path-provisioner, but hardware.md doesn't document this.

---

## Ambiguities (Questions)

These ambiguities block later steps and need human clarification:

1. **Domain names**: What domain name(s) should be used for cluster services? The Gateway test app uses `echo.gateway-test` as hostname but no domain is configured.

2. **Tailscale group names**: What are the actual Tailscale group names that should map to the README groups (guests, friends, family, developers, admins)? Are these Tailscale ACL tags or Kubernetes groups?

3. **Secrets repo layout**: What is the structure of the secrets repo? Where do `tailscale-oauth`, `rclone-config`, and `flux-system` secrets live? What keys do they contain?

4. **Disk layout from hardware.md**: What is the actual disk layout for cp1? Size of `/dev/nvme0n1`? Are there additional data disks? What is the purpose of each disk?

5. **Jottacloud backup scope**: Should the jottacloud-backup CronJob be updated to also back up Longhorn volumes (`/var/mnt/longhorn`) and etcd? Or is there a separate backup mechanism for these?

6. **Garage storage**: Should Garage be added as a storage option as mentioned in README.md? If so, what is the priority?

7. **Nix environment**: Should a Nix flake be created for the development environment? If so, what tools should it include?

8. **RBAC implementation**: How should the Tailscale groups (guests, friends, family, developers, admins) be mapped to Kubernetes RBAC? Should this be implemented via Tailscale ACL tags mapped to Kubernetes groups, or via separate authentication?

9. **Multi-node expansion**: When adding nodes, should we add control plane nodes or worker nodes first? What is the target architecture?

10. **Cilium version mismatch**: Should `talos/scripts/control-planes.sh` be updated to use Cilium v1.20.2 (matching the HelmRelease) instead of v1.20.1?

11. **Validation workflow**: Should the missing kustomize paths be added to `.github/workflows/validate.yaml`? Should helm-lint failures be allowed to pass with `|| true`?

## Suggested README Changes (Text Only)

1. Add a "Current Status" section summarizing what's implemented and what's pending.

2. Clarify the Tailscale + RBAC relationship: explain how Tailscale provides authentication and how Kubernetes RBAC provides authorization, and that group mappings are pending implementation.

3. Add a "Roadmap" or "Pending" section listing: Garage storage, Nix environment, RBAC configuration, multi-node expansion, monitoring stack.

4. Clarify the backup strategy: document that currently only local-path-provisioner data is backed up to Jottacloud, and that Longhorn/etcd backup and restore pipelines are pending.

5. Add a note that setup.md contains manual steps and that it's currently a work in progress.
