# Jottacloud Backup

This directory contains the Kubernetes manifests for backing up the local-path-provisioner data directory to Jottacloud using rclone.

## Manual Setup Required

The rclone configuration file (`rclone.conf`) contains sensitive credentials and must NOT be committed to Git.

### One-time setup steps:

1. **Install rclone on your workstation** if not already installed:
   ```bash
   # On macOS
   brew install rclone

   # On Linux
   # Follow instructions at https://rclone.org/install/
   ```

2. **Configure rclone remote for Jottacloud**:
   ```bash
   rclone config
   ```
   - Select `n` for new remote
   - Enter name: `jottacloud`
   - Select storage type: choose the Jottacloud backend
   - Follow the prompts to authenticate with Jottacloud
   - This creates `~/.config/rclone/rclone.conf`

3. **Create the Kubernetes Secret** (after Flux has created the namespace):
   ```bash
   kubectl create secret generic rclone-config \
     --namespace jottacloud-backup \
     --from-file=rclone.conf=/path/to/your/rclone.conf
   ```

4. **Verify the Secret was created**:
   ```bash
   kubectl get secret rclone-config -n jottacloud-backup
   ```

## Testing the Backup

To manually trigger a backup test:
```bash
kubectl create job --from=cronjob/jottacloud-backup -n jottacloud-backup test-run-1
kubectl logs -n jottacloud-backup job/test-run-1 -f
```

Check that files appear in your Jottacloud under the `homelab-backup` folder.

## Notes

- The CronJob runs daily at 03:00 UTC by default (adjust in `cronjob.yaml` if needed)
- The backup source path (`/var/mnt/local-path-provisioner`) must match the path configured in the local-path-provisioner
- The rclone remote name (`jottacloud`) must match what you configured in step 2
