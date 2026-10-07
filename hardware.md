# Hardware

Source of truth for node hardware. Config details (IPs, disk paths) live in `talos/nodes/`; link there rather than duplicating.

## Nodes

| Node | Config script | Role | IP | CPU | RAM | OS disk | Data disk(s) | NIC |
|------|----|------|----|-----|-----|---------|--------------|-----|
| cp1 | control-plane | 192.168.0.188 | TODO | TODO | /dev/nvme0n1 | TODO | enp0s3 |

## Per-node details

### cp1

- **Machine:** TODO (make/model)
- **CPU:** TODO (cores/threads)
- **RAM:** TODO
- **Disks:**
  - `/dev/nvme0n1`: TODO size, OS + ephemeral (EPHEMERAL maxSize 40GiB)
  - TODO: data disk, purpose (e.g. Longhorn)
- **Network:** enp0s3, TODO speed, Wake-on-LAN enabled (`talos/patches/wakeonlan.yaml`)
- **Talos:** schematic and extensions in `talos/scripts/control-planes.sh`
- **BIOS/firmware notes:** TODO (e.g. virtualization, boot order, WoL setting)
- **Config:** `talos/nodes/cp_192.168.0.188.yaml`

## Other equipment

| Item | Purpose | Notes |
|------|---------|-------|
|  |  |  |

## Adding a node

1. Add a row to the table and a section above.
2. Create `talos/nodes/<role>_<ip>.yaml`.
3. Check the Talos schematic includes any extensions this hardware needs.
4. Update single-node settings (replica counts, `operator.replicas`) noted in the manifests.