#!/usr/bin/env bash
# ==============================================================================
# Script Name   : simulate_nfs_failure.sh
# Purpose       : Controlled simulation of NFS server daemon crash.
# Safety Rules  : Explicit confirmation required (--confirm).
# ==============================================================================

set -euo pipefail

if [[ "${1:-}" != "--confirm" ]]; then
    echo "================================================================================"
    echo "SAFETY GATE: NFS Service Crash Simulation"
    echo "This script temporarily stops 'nfs-kernel-server' on this host."
    echo "Client mounts will pause operations until the service is restarted."
    echo ""
    echo "To proceed, run: $0 --confirm"
    echo "================================================================================"
    exit 1
fi

echo "[+] Initiating controlled NFS service interruption simulation..."

# Step 1: Stop NFS kernel server service
echo "[*] Stopping nfs-kernel-server service..."
systemctl stop nfs-kernel-server

echo "[!] NFS service is now STOPPED."
echo "[*] Expected symptom: 'systemctl status nfs-kernel-server' will report inactive (dead)."
echo "[*] Client symptom: In-flight I/O on /mnt/nfs_share will queue and await reconnect."
echo "[*] Monitoring: Prometheus alert 'NFSServiceDown' will trigger after 1 minute."
echo ""
echo "To recover service, run:"
echo "  sudo systemctl start nfs-kernel-server"
echo "  or run: ./reset_lab.sh"
exit 0
