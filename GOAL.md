This is a description of the desired state of the cluster as a whole.

## Services

Adding a new service should be simple. It should be possible to add an app in a Docker container easily.

## Roles and Access

Access should follow least privilege. Roles describe the intended level of access regardless of how that access is implemented.

| Role          | Cluster config | Workloads     | Secrets       | Storage       | Observability   |
| ------------- | -------------- | ------------- | ------------- | ------------- | --------------- |
| Administrator | Full           | Full          | Full          | Full          | Full            |
| Operator      | Read / deploy  | Manage        | Limited       | Manage        | Full            |
| Developer     | Read           | Own workloads | Own workloads | Own workloads | Read            |
| Service       | None           | None          | Required only | Required only | Write telemetry |
| Family         | None           | None          | None          | None          | Limited read    |
| Guest         | None           | None          | None          | None          | Limited read    |

### Identity and Access

Human access MUST be tied to an authenticated user identity.

Tailscale SHOULD provide the primary network access layer to cluster resources. Access through Tailscale SHOULD be associated with individual user identities rather than shared credentials.

Authorization SHOULD be enforced at the appropriate layer. Tailscale access policies determine which users can reach services over the network, while Kubernetes RBAC and application-level authorization determine what authenticated users are permitted to do.

The intended access model is:

**User identity → Tailscale network access → Kubernetes or application authorization**

### Principles

* Access MUST follow least privilege.
* Human access SHOULD use individual identities rather than shared credentials.
* Network access MUST NOT implicitly grant administrative access to Kubernetes or applications.
* Services MUST only access secrets and storage required for their function.
* Administrative access SHOULD be reserved for cluster management and recovery.
* Agents SHOULD evaluate configured Tailscale policies, Kubernetes RBAC, and application authorization against this model and report unnecessary or excessive privileges.


## Cluster Storage

The cluster should provide the following storage types.

| Storage type | Minimum capacity | Desired distribution | Replicas | Backup|
|---|---:|---:|---:|
| S3 (Garage) | 150 GB | 30% | 1 | Jottacloud|
| Longhorn | 150 GB | 30% | 1 |None |
| local-path-provisioner| 150 GB | 30% | 1 | Jottacloud|
| Talos ephemeral | 50 GB | 10% | 1|None |

The desired distribution is a target, not a hard requirement.
Minimum capacities are hard requirements.

Agents should evaluate the current cluster configuration against these
requirements and prefer changes that move the cluster toward the desired
distribution without violating minimum capacities.