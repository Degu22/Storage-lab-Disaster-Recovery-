# Architecture Specification: Enterprise Storage Service Lifecycle & Disaster Recovery Lab

## 1. Storage Topology & Storage Tiering

This laboratory environment models an enterprise on-premise shared storage architecture supporting high-performance compute clients with automated Disaster Recovery (DR).

### Storage Virtualization with LVM
* **Underlying Physical Disks:** High-performance SAS/NVMe block devices provisioned under Linux Logical Volume Manager (LVM2).
* **Volume Group (`vg_storage`):** Aggregates raw block storage, allowing non-disruptive, live volume scaling.
* **Logical Volume (`lv_data`):** Formatted with the **XFS** enterprise filesystem, chosen for its high scalability, direct I/O throughput, and support for metadata allocation groups.
* **Live Scalability:** The LVM abstraction enables zero-downtime storage expansion using `lvextend -r -L +20G /dev/vg_storage/lv_data` without unmounting the live NFS share.

---

## 2. Protocol Selection & Tuning

### NFSv4 vs NFSv3
* **NFSv4.2 Selected:** Unlike legacy NFSv3 (which requires multiple auxiliary ports like `rpc.statd`, `rpc.lockd`, and portmapper), NFSv4 operates strictly over a single TCP port (**2049**).
* **Stateful Locking:** NFSv4 integrates file locking directly into the protocol, eliminating stale lock bugs common in network partitions.
* **Client Mount Optimization:**
  * `_netdev`: Ensures systemd delays mounting until network interfaces and DNS resolvers are fully initialized.
  * `nofail`: Prevents boot hangs if the storage node is undergoing maintenance during a client reboot.
  * `soft, timeo=150, retrans=3`: Configures reasonable fail-fast timeout behavior (15 seconds, 3 retries) so client application threads do not freeze indefinitely if storage becomes partitioned.

---

## 3. DevSecOps & Security Hardening

1. **Subnet-Level Export Restriction:**
   * Exports configured in `/etc/exports` strictly restrict access to the dedicated internal storage subnet (`192.168.10.0/24`). Requests from any external network are dropped at the kernel level.
2. **Privilege Escalation Prevention (`root_squash`):**
   * Default setting maps remote client root requests (UID 0 / GID 0) to `nfsnobody` (UID 65534). Even if an attacker gains root access on a compute client, they cannot overwrite system binaries or modify storage server files.
3. **Network Security Zone Isolation:**
   * The storage server uses `firewalld` to enforce internal security zone segregation. Only traffic destined for TCP port 2049 originating from approved client IPs is permitted; all management interfaces (SSH, Node Exporter) are restricted to the management plane.

---

## 4. Disaster Recovery & Data Integrity Lifecycle

```
[Primary Live Data] ──(LVM Snapshot)──> [Read-Only Point-in-Time Image]
                                                        │
                                                        ▼
                                           [Generate SHA-256 Hashes]
                                                        │
                                                        ▼
                                           [Rsync Over Secure SSH]
                                                        │
                                                        ▼
                                           [Remote Target: /backup/dr_repo]
                                                        │
                                                        ▼
                                           [Post-Sync Hash Verification]
```

* **Zero-Impact Snapshots:** Taking point-in-time snapshots at the LVM layer bypasses the need to halt running database processes or unmount the filesystem, preventing service interruption.
* **Cryptographic Bit-Level Validation:** The automated DR script produces an immutable hash manifest (`sha256sum`). Following file transfer, the remote DR node validates every file against this manifest. If even a single byte differs (due to network corruption or silent disk bit-rot), the job throws a P1 alert.
