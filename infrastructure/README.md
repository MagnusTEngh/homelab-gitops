# Infrastructure




# Test Spec: Verify local-path-provisioner + Jottacloud Backup (PR #42)

## Goal

Confirm two things end-to-end:
1. A pod can write data to a PVC backed by the `local-path` StorageClass, and that data physically lands on the dedicated 300GiB partition at `/var/mnt/local-path-provisioner`.
2. The `jottacloud-backup` CronJob can read that data and successfully push it to Jottacloud.

This is a manual, one-time functional test — not a CI test. Run it after Flux has reconciled PR #42 and the `rclone-config` Secret has been created manually.

---

## Preconditions (check before testing)

```bash
flux get kustomizations -A
```
Expect `local-path-provisioner` and `jottacloud-backup` both `Ready: True`.

```bash
kubectl get storageclass
```
Expect `local-path` present and marked `(default)`.

```bash
kubectl get secret rclone-config -n jottacloud-backup
```
Expect it to exist. If not, stop and create it per `infrastructure/jottacloud-backup/README.md` first.

---

## Test 1: Storage write path

**1a. Create a test PVC and Pod**

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: storage-test-pvc
  namespace: default
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 100Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: storage-test-writer
  namespace: default
spec:
  restartPolicy: Never
  containers:
    - name: writer
      image: busybox:1.36
      command: ["sh", "-c", "echo 'storage-test-$(date +%s)' > /data/test-file.txt && sleep 30"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: storage-test-pvc
EOF
```

**1b. Confirm the PVC bound and the pod succeeded**

```bash
kubectl get pvc storage-test-pvc -n default
kubectl wait --for=condition=Ready pod/storage-test-writer -n default --timeout=60s || true
kubectl logs storage-test-writer -n default
```
Expect `PVC` status `Bound`, pod runs without error.

**1c. Confirm the file physically exists on the dedicated partition**

This must be checked on the node itself, not just inside the pod, to prove it's really on `/var/mnt/local-path-provisioner` and not some other path.

```bash
talosctl -n 192.168.0.188 ls /var/mnt/local-path-provisioner -l
```

Find the PV's actual subdirectory (named after the PV, not the PVC) and confirm `test-file.txt` is inside it:

```bash
kubectl get pv -o jsonpath='{range .items[?(@.spec.claimRef.name=="storage-test-pvc")]}{.metadata.name}{"\n"}{end}'
talosctl -n 192.168.0.188 ls /var/mnt/local-path-provisioner/<pv-name-from-above>
```
Expect `test-file.txt` listed.

**Pass criteria:** file visible both from inside the pod and directly on the Talos partition.

---

## Test 2: Backup to Jottacloud

**2a. Manually trigger the CronJob**

```bash
kubectl create job --from=cronjob/jottacloud-backup -n jottacloud-backup backup-test-1
kubectl wait --for=condition=complete job/backup-test-1 -n jottacloud-backup --timeout=120s
kubectl logs -n jottacloud-backup job/backup-test-1
```

**Pass criteria in the logs:**
- No `ERROR` or `Failed to` lines.
- rclone summary line shows transferred files/bytes > 0 the first time it runs (if it's run before with nothing changed, `0 B` transferred is also fine — that means it correctly detected nothing new).

**2b. Confirm the test file reached Jottacloud**

Easiest check — from a workstation with the same rclone remote configured:

```bash
rclone ls jottacloud:homelab-backup
```

Look for the PV directory and `test-file.txt` inside it, matching what you found in Test 1c.

If you don't have rclone locally, check via the Jottacloud web UI under the `homelab-backup` folder instead.

**Pass criteria:** the exact file from Test 1 is present in Jottacloud under `homelab-backup`.

---

## Test 3 (optional but recommended): Change detection

Confirms the backup isn't just copying once and silently going stale.

```bash
kubectl exec storage-test-writer -n default -- sh -c "echo 'update-$(date +%s)' >> /data/test-file.txt" 2>/dev/null || \
kubectl run storage-test-updater -n default --rm -i --restart=Never --image=busybox:1.36 \
  --overrides='{"spec":{"containers":[{"name":"updater","image":"busybox:1.36","command":["sh","-c","echo update-$(date +%s) >> /data/test-file.txt"],"volumeMounts":[{"name":"data","mountPath":"/data"}]}],"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"storage-test-pvc"}}]}}'

kubectl create job --from=cronjob/jottacloud-backup -n jottacloud-backup backup-test-2
kubectl wait --for=condition=complete job/backup-test-2 -n jottacloud-backup --timeout=120s
kubectl logs -n jottacloud-backup job/backup-test-2
```

**Pass criteria:** log shows the updated file being transferred again (non-zero transfer), and `rclone ls jottacloud:homelab-backup` (or the web UI) shows the updated content/size.

---

## Cleanup (always run after testing)

```bash
kubectl delete pod storage-test-writer -n default --ignore-not-found
kubectl delete pvc storage-test-pvc -n default --ignore-not-found
kubectl delete job backup-test-1 backup-test-2 -n jottacloud-backup --ignore-not-found
```

Manually delete the test folder/file from Jottacloud (via web UI or `rclone delete jottacloud:homelab-backup/<pv-name>`), since the CronJob does not prune remote files that no longer exist locally (`rclone sync` only pushes local→remote deletions, so once the PVC/PV is deleted, the old backup remains — this is expected `sync` behavior, not a bug, but worth knowing).

---

## Overall pass/fail

| Check | Pass condition |
|---|---|
| StorageClass | `local-path` exists and is default |
| PVC binds | `Bound` status |
| Data lands on correct partition | `test-file.txt` visible via `talosctl ls /var/mnt/local-path-provisioner/<pv>` |
| Backup job runs | Job `Complete`, no errors in logs |
| File reaches Jottacloud | `test-file.txt` visible in `homelab-backup` folder |
| Change detection (optional) | Second sync transfers the update |

If all pass: the feature works end-to-end. If storage passes but backup fails, the problem is isolated to rclone/Secret/network. If storage itself fails, don't bother testing backup yet.
