This is a description of the desired state of the cluster as a whole.

## Cluster Storage

The cluster should provide the following storage types.

| Storage type | Minimum capacity | Desired distribution | Replicas |
|---|---:|---:|---:|
| S3 (Garage) | 150 GB | 30% | 1 |
| Longhorn | 150 GB | 30% | 1 |
| local-path-provisioner| 150 GB | 30% | 1 |
| Talos ephemeral | 50 GB | 10% | 1|

The desired distribution is a target, not a hard requirement.
Minimum capacities are hard requirements.

Agents should evaluate the current cluster configuration against these
requirements and prefer changes that move the cluster toward the desired
distribution without violating minimum capacities.