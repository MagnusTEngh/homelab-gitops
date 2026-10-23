# SUGGESTIONS.md

Evaluation of the repo against GOAL.md / README.md. Tasks are ordered by priority. Each task is one PR-sized unit; follow AGENTS.md (offline checks, "Human steps", stop after each task).

## 0. Status vs GOAL.md

| Goal | State |
|---|---|
| Simple to add a service | No template or doc; each app needs a hand-written Flux Kustomization |
| Roles / least privilege | Only a Tailscale subnet Connector. No RBAC, no ACL docs, no per-role gateways. Role names differ between GOAL.md (Operator, Service) and README.md (friends) |
| Storage: S3 (Garage) 150 GB | **Missing** |
| Storage: Longhorn 150 GB | **Not deployed** (no Flux Kustomization in `yggdrasil.yaml`). Volume `minSize` is 20GiB, `grow: true`, no `maxSize` |
| Storage: local-path 150 GB + Jottacloud | OK (300GiB partition). Backup job likely blocked by PodSecurity (see T4) |
| Storage: Talos ephemeral 50 GB | **Violation**: `maxSize: 40GiB` (< 50 GB hard minimum) |
| Disk size / total capacity | Unknown (`hardware.md` is TODO), so distribution cannot be checked |
| Backups to Jottacloud, testable restore | local-path only; no etcd, no Garage, no restore test; `rclone sync` deletes remote data |
| Success-condition tests (access, storage) | None exist |
| Observability column of role table | No monitoring stack |
| Nix env | `flake.nix` exists but lacks talosctl/flux/helm/nvim and exposes an unauthenticated web IDE |
| Docs | `setup.md` empty, `docs/secrets.md` missing, `docs/state.md` stale |

## P0: Defects (do first, small PRs)

### T1. Register Longhorn in Flux
- Add Kustomization `longhorn` to `clusters/yggdrasil/yggdrasil.yaml`: `dependsOn: cilium`, `path: ./infrastructure/longhorn`, `wait: true`, `timeout: 15m`.
- Offline: `kubectl kustomize infrastructure/longhorn`, yamllint.
- Human: `flux get ks longhorn` Ready; `kubectl -n longhorn-system get pods`.

### T2. Add a registration check and fix schema checks in `scripts/validate.sh`
- New check `flux-registered`: every dir under `infrastructure/` and `apps/` with a `kustomization.yaml` must appear as a `path:` in `clusters/yggdrasil/yggdrasil.yaml` (would have caught T1). Add to `ALL_CHECKS`, CI matrix, pre-commit.
- Schema locations `CILIUM_SCHEMA` (`v2.0.0`), `TAILSCALE_SCHEMA` (nonexistent repo) and `GATEWAY_API_SCHEMA` (`v1.0.0`) are wrong or point to CRD YAML, not JSON schema. With `-ignore-missing-schemas` they silently skip, so the check gives false assurance. Remove them; rely on the datree catalog and list which kinds remain unvalidated.
- Verify `K8S_VERSION=1.30.4` against the Kubernetes version Talos v1.13.7 actually ships; Gateway API v1.6.1 CRDs use CEL/VAP features. Fix if wrong.

### T3. Fix Tailscale operator credentials
- `valuesFrom` with `targetPath: oauth` reads key `values.yaml` by default, but the README creates keys `clientId` / `clientSecret`. Replace with two entries:
  - `valuesKey: clientId`, `targetPath: oauth.clientId`
  - `valuesKey: clientSecret`, `targetPath: oauth.clientSecret`
- Fix `infrastructure/tailscale/README.md`: the operator OAuth client needs scopes `devices:core` + `auth_keys` (write) and tag `tag:k8s-operator`, with `tagOwners` making it owner of `tag:k8s`.
- Human: recreate secret, `kubectl -n tailscale get pods` Running, Connector device appears in admin console.

### T4. Fix jottacloud-backup
- Namespace has no PodSecurity label; Talos enforces `baseline` by default, which rejects `hostPath`. Add `pod-security.kubernetes.io/enforce: privileged` to `namespace.yaml` (as longhorn does) and confirm.
- `rclone sync` **deletes** remote files that no longer exist locally, so a deleted PV disappears from backup. (`infrastructure/README.md` claims the opposite.) Use `rclone copy` or `sync --backup-dir jottacloud:homelab-backup-archive/$(date)`.
- Destination per source: `jottacloud:homelab-backup/local-path` (leaves room for `/garage`, `/etcd`).
- Add a `nodeSelector` / comment that hostPath is node-local (multi-node: needs one job per node).
- Add chapter to `verification.md` (CronJob last success, Job logs).

### T5. Fix Cilium / Gateway API ordering
- Cilium has `gatewayAPI.enabled: true` but Gateway API CRDs install *after* Cilium (`gateway-api dependsOn cilium`). Cilium only enables its gateway controller if CRDs exist at operator start. Remove `dependsOn` from `gateway-api` and add `dependsOn: gateway-api` to `cilium` (CRDs need no CNI; the bootstrap script already runs Cilium before Flux).
- Human: if no Gateway is `Programmed`, `kubectl -n kube-system rollout restart deploy/cilium-operator`.

### T6. Remove drift and dead config
- `talos/scripts/control-planes.sh`: set `CILIUM_VERSION` from `infrastructure/cilium/helmrelease.yaml` (`yq`), not a literal (currently 1.20.1 vs 1.20.2).
- Renovate `customManagers` for `TALOS_VERSION` (script), Gateway API version (README command + CRD file), `K8S_VERSION`.
- Delete `infrastructure/cilium/namespace.yaml` (not in the kustomization; manages `kube-system`).
- `apps/gateway-test`: `app.yaml` and `gateway.yaml`/`httproute.yaml` define two Gateways and two routes for the same backend. Keep one set.
- Add the `# single node` comment on `operator.replicas: 1` in the Cilium HelmRelease (AGENTS.md rule).
- Fix `hardware.md` table (header has 12 columns, row has 9, stray `!`).

### T7. Harden `flake.nix`
- The `vscode-web` alias serves `0.0.0.0` with `--without-connection-token`. Bind to `127.0.0.1` (or the tailnet address) and use a token.
- Add `talosctl`, `fluxcd`, `kubernetes-helm`, `kustomize`, `neovim`; drop `curl wget gnused gnutar gzip` (README: keep it focused).
- CI: run checks via `nix develop -c scripts/validate.sh` so CI and the dev shell cannot diverge.

## P1: Reach the goal state

### T8. Storage budget (needs human input first)
- **Human first**: fill in disk size, RAM, CPU in `hardware.md`.
- Agent then adds a capacity table in `hardware.md` (minimums: Garage 150, Longhorn 150, local-path 150, ephemeral 50 GB; target 30/30/30/10 %).
- Patches (use `GB` units to avoid GiB/GB mix-ups):
  - `talos/nodes/cp_*.yaml`: EPHEMERAL `minSize/maxSize` >= 50GB.
  - `talos/patches/longhorn.yaml`: `minSize: 150GB`, add `maxSize`, drop open-ended `grow: true`.
  - New `talos/patches/garage.yaml`: `UserVolumeConfig` `garage`, `minSize: 150GB`, `maxSize`.
  - Add `garage.yaml` to the patch list in `control-planes.sh`.
- Do **not** migrate the legacy `machine.disks` local-path partition to a `UserVolumeConfig` unless the human confirms; it is destructive on an existing node.
- Human: apply patches, `talosctl get volumestatus`, expect sizes within targets.

### T9. Add Garage (S3)
- `infrastructure/garage/`: namespace, source, HelmRelease (read chart location and version from upstream, do not invent), registered in `yggdrasil.yaml`.
- `replication_factor: 1` with `# single node` comment; data on the `garage` user volume via a static local PV (`/var/mnt/garage`).
- `scripts/garage-init.sh`: layout, bucket, key creation; key stored via secrets script (T15).
- Backup: CronJob `rclone copy` Garage S3 -> `jottacloud:homelab-backup/garage` (backs up objects, not raw files).
- Add to `docs/secrets.md`, `verification.md` (chapter), and Hello World storage test (T13).

### T10. Complete the backup pipeline
- etcd: add Talos patch `machine.features.kubernetesTalosAPIAccess` (`allowedRoles: [os:etcd:backup]`, `allowedKubernetesNamespaces: [jottacloud-backup]`), a Talos `ServiceAccount`, and a CronJob running `talosctl etcd snapshot` then `rclone copy` to `jottacloud:homelab-backup/etcd`.
- Restore test Job (Flux-managed): `rclone copy` latest backup into `emptyDir`, `rclone check` / checksum the Hello World file. One Job per source (local-path, garage, etcd snapshot readable).
- Image digests: Renovate pins them, but the first value must come from a human (`crane digest`); list this in Human steps.

### T11. Identity, roles and RBAC
- **Human decisions first**: final role names (GOAL.md: Administrator, Operator, Developer, Service, Family, Guest vs README "friends"). Suggest updating README/GOAL by text only.
- Enable the operator's API server proxy (`apiServerProxyConfig.mode: "true"` in the HelmRelease).
- `infrastructure/rbac/`: ClusterRoles for operator, developer (namespaced), observability-view; ClusterRoleBindings to groups from Tailscale grants (`tailscale.com/cap/kubernetes` -> `impersonate.groups`). Admin -> `cluster-admin` only via group.
- `docs/tailscale-acl.md`: grants policy (manual step) mapping users to groups, and to destination IP:port per role.
- Per-role gateways with fixed IPs from the `/29` pool (annotation `lbipam.cilium.io/ips`) so Tailscale grants can restrict by IP. Max 6 gateways in the pool.
- Developers: namespace + ServiceAccount + RoleBinding + Flux Kustomization using `serviceAccountName`, so they deploy without broad write access.
- Default-deny `CiliumNetworkPolicy` per app namespace; Service accounts get only the secrets/storage they need.
- Decide how admins reach the Kubernetes/Talos API (192.168.0.188 is LAN-reachable by certificate only): advertise `192.168.0.188/32` via the Connector, restricted by ACL to admins.

### T12. Make adding a service simple
- `apps/_template/` (copy-and-edit): Deployment (non-root, read-only rootfs, resource limits, digest-pinned image), Service, HTTPRoute, namespace, kustomization.
- One aggregate Flux Kustomization `apps` (`path: ./apps`, `dependsOn: cilium, gateway-api, rbac`) so a new app = new dir + one line in `apps/kustomization.yaml`.
- `docs/adding-a-service.md` (5 steps). CI builds the template.

### T13. Tests (README "success conditions")
- `tests/access/{admin,family,friend,guest}.sh` and `tests/storage/<type>.sh`: one condition per script, exit 0/1, shellcheck-clean.
- `apps/tests/`: ConfigMap via `configMapGenerator`, Jobs/CronJobs run by Flux. Access tests need a tailnet identity per role (ephemeral tagged auth key per role, userspace Tailscale sidecar).
- Text-only note for the human: README requires backup tests for every storage type, GOAL.md says Longhorn and ephemeral have no backup. Reconcile.

### T14. Observability (role table column)
- After T11. Metrics stack sized to `hardware.md` RAM, enable Hubble, Grafana behind a per-role gateway with read-only roles for Family/Guest, write endpoint for the Service role. Keep resource limits tight.

## P2: Docs and maintenance

### T15. Docs and secrets scripts
- `setup.md`: ordered steps with commands and expected output: generate Talos secrets/config (`controlplane.yaml` is gitignored), run `control-planes.sh`, `flux bootstrap` (command in `clusters/README.md`, needs `GITHUB_TOKEN`), secrets scripts, Tailscale ACL, verification.
- `docs/secrets.md`: `tailscale-oauth` (ns `tailscale`, keys `clientId`, `clientSecret`), `rclone-config` (ns `jottacloud-backup`, key `rclone.conf`), `flux-system` (ns `flux-system`, token-auth keys), plus Garage keys.
- `scripts/secrets/*.sh`: create each secret from the local secrets repo path (README: "should be done using scripts").
- Delete or regenerate `docs/state.md`: it claims no Nix files, Longhorn 1.12.1, and missing validate paths, all outdated.
- `verification.md` fixes: `kubectl -n longhorn-system get nodes` -> `nodes.longhorn.io`; Gateway API "pods" check -> `kubectl get gatewayclass` Accepted; Cilium `version` label does not exist (check HelmRelease/`cilium version`). Add chapters: local-path, jottacloud-backup, Garage, RBAC. Move the PR #42 test spec from `infrastructure/README.md` into `verification.md`.
- `AGENTS.md`: update layout (`validate.yaml` is now a matrix calling `scripts/validate.sh`, not a `kustomize-build` job; real `dependsOn` graph); add "register new paths in `yggdrasil.yaml`" (enforced by T2).

### T16. Low maintenance
- HelmReleases: add `install/upgrade.remediation.retries: 3` everywhere (only Longhorn has it).
- Flux Kustomizations: set `retryInterval`.
- Flux `Provider` + `Alert` for failures (after T14 choose a sink without cloud dependency).

### T17. Expansion readiness
- Parametrize `control-planes.sh` into `talos/scripts/add-node.sh <role> <ip>`; a Talos VIP patch for HA control planes.
- Checklist in `hardware.md` already lists single-node settings; grep for `# single node` and keep it current (Longhorn/Garage replicas, Cilium operator, backup job per node).

## Human decisions needed

1. Disk size, RAM, CPU of cp1 (blocks T8, T14).
2. Final role/group names (blocks T11, T13).
3. Domain/DNS strategy: `echo.gateway-test` is not resolvable, MagicDNS does not name LB IPs.
4. Whether Longhorn/ephemeral need backup (README vs GOAL.md).
5. Whether to migrate the local-path `machine.disks` partition to a `UserVolumeConfig` (destructive).

## Suggested automated health checks

- `flux-registered` validation (T2): prevents unregistered components.
- CronJob/Flux alert on failed backup or restore test (needs T14/T16).