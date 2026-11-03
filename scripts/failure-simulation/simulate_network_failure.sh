#!/usr/bin/env bash
# ==============================================================================
# Script Name   : simulate_network_failure.sh
# Purpose       : Drops inbound NFS port 2049 traffic using UFW to simulate
#                 a network partition / switch failure.
# Safety Rules  :
#   - Explicit confirmation required (--confirm)
#   - Uses specific rule comment (LAB_TEST_NFS_PARTITION) for targeted rollback
#   - Leaves SSH (port 22) fully untouched to guarantee admin access
# ==============================================================================

set -euo pipefail

if [[ "${1:-}" != "--confirm" ]]; then
    echo "================================================================================"
    echo "SAFETY GATE: Network Partition Simulation"
    echo "This script adds a temporary UFW firewall rule to drop inbound NFS TCP 2049."
    echo "SSH administrative access (Port 22) will NOT be affected."
    echo ""
    echo "To proceed, run: $0 --confirm"
    echo "================================================================================"
    exit 1
fi

echo "[+] Simulating Storage Network Partition..."
echo "[*] Adding temporary UFW rule with comment 'LAB_TEST_NFS_PARTITION'..."

# Insert drop rule at top of UFW with unique tracking comment
ufw insert 1 deny proto tcp from any to any port 2049 comment "LAB_TEST_NFS_PARTITION"

echo "[!] Inbound NFS port 2049 is now BLOCKED."
echo "[*] Client symptom: In-flight client I/O will pause, queuing per mount options (hard, timeo=600, retrans=2)."
echo "[*] Log symptom: Inspect client kernel logs via 'dmesg -T | grep -i nfs'."
echo ""
echo "To restore network connectivity, run: ./reset_lab.sh"
exit 0
