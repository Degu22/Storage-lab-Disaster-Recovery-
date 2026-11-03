# Day-2 Operations Runbook: NFS Shared Storage Administration

## 1. Daily Administration Checklist

- [ ] Check active NFS exports: `sudo exportfs -v`
- [ ] Inspect storage pool capacity: `df -h /srv/nfs_share`
- [ ] Check inode usage: `df -i /srv/nfs_share`
- [ ] Verify active TCP connections on port 2049: `ss -tulpn | grep 2049`
- [ ] Check Prometheus target scrape status: `http://<MANAGEMENT_IP>:9090/targets`

---

## 2. Dynamic Volume Resizing (Live LVM & XFS Expansion)

When storage capacity reaches warning thresholds (>80%), expand the storage pool **live without unmounting or restarting NFS**:

### Step 1: Extend the Logical Volume
```bash
# Add 10GB to the existing logical volume
sudo lvextend -L +10G /dev/vg_storage/lv_data
```

### Step 2: Grow the XFS Filesystem
```bash
# XFS filesystems are grown while mounted using xfs_growfs
sudo xfs_growfs /srv/nfs_share
```

### Step 3: Verify Increased Capacity
```bash
df -h /srv/nfs_share
```

---

## 3. Client Mount Administration

### Recommended Client Mount Entry (`/etc/fstab`):
```text
10.0.2.10:/srv/nfs_share  /mnt/nfs_share  nfs4  defaults,_netdev,nofail,hard,timeo=600,retrans=2  0 0
```

### Mount Option Rationale:
* `_netdev`: Informs systemd to delay mounting until network connectivity is fully established.
* `nofail`: Ensures the compute node continues booting even if the storage server is offline.
* `hard`: Protects data integrity by ensuring the client retries in-flight I/O indefinitely rather than returning silent I/O errors (`EIO`) to writing applications.
* `timeo=600, retrans=2`: Sets timeout interval to 60 seconds with 2 retransmissions before re-evaluating connection health.

---

## 4. Common Troubleshooting Scenarios

### Symptom: `mount.nfs: access denied by server while mounting`
1. **Check exports:** Run `sudo exportfs -v` on the NFS server.
2. **Check client IP:** Verify the client's internal IP is within the exported subnet (`10.0.2.0/24`).
3. **Check firewall:** Verify UFW allows port 2049 (`sudo ufw status verbose`).

### Symptom: `mount.nfs: Connection timed out`
1. Check if `nfs-kernel-server` is running: `sudo systemctl status nfs-kernel-server`.
2. Check AWS Security Group rules on the Storage Server for TCP 2049 ingress.
