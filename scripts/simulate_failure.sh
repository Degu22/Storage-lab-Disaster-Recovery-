#!/usr/bin/env bash
# ==============================================================================
# Script Name   : simulate_failure.sh
# Purpose       : Chaos engineering and disaster simulation for Storage DevSecOps.
# Author        : Devi Prasad Gudipally
# Scenarios     :
#   1. Disk Space Exhaustion (Fills storage pool to 92% to trigger Prometheus P1 alert)
#   2. Accidental File Deletion / Data Corruption (Tests DR restore runbook)
#   3. Network Partition (Drops NFS port 2049 to test client retransmission/timeouts)
#   4. Clean Reset
# ==============================================================================

set -euo pipefail

NFS_SHARE="/srv/nfs_share"
FILL_FILE="${NFS_SHARE}/simulate_disk_exhaustion.img"

case "${1:-help}" in
    disk-fill)
        echo "[+] Simulating Storage Pool Exhaustion..."
        echo "[+] Creating large dummy file to push utilization past 90% threshold..."
        fallocate -l 42G "${FILL_FILE}" || dd if=/dev/zero of="${FILL_FILE}" bs=1M count=42000 status=progress
        echo "[!] Storage pool now > 90% utilized. Check Grafana & Prometheus Alertmanager for 'StorageVolumeCriticallyFull'."
        df -h "${NFS_SHARE}"
        ;;

    corrupt-data)
        echo "[+] Simulating Data Loss / Ransomware Corruption..."
        echo "MALICIOUS CORRUPTION INJECTED AT $(date)" > "${NFS_SHARE}/critical_dataset_sample.csv"
        echo "[!] Corrupted critical file. Trigger './disaster_recovery_restore.sh' to test automated recovery."
        ;;

    network-partition)
        echo "[+] Simulating Network Partition (dropping port 2049)..."
        iptables -A INPUT -p tcp --dport 2049 -j DROP
        echo "[!] NFS traffic dropped. Inspect client mounts and 'dmesg -T' for NFS server not responding timeouts."
        ;;

    reset)
        echo "[+] Resetting lab to healthy baseline..."
        rm -f "${FILL_FILE}"
        iptables -D INPUT -p tcp --dport 2049 -j DROP 2>/dev/null || true
        echo "[+] Environment reset. Storage healthy."
        df -h "${NFS_SHARE}"
        ;;

    *)
        echo "Usage: $0 {disk-fill | corrupt-data | network-partition | reset}"
        exit 1
        ;;
esac
