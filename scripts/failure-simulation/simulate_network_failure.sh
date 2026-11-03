#!/usr/bin/env bash
# ==============================================================================
# Script Name   : simulate_network_failure.sh
# Purpose       : Drops inbound NFS port 2049 traffic using UFW to simulate
#                 a network partition / switch port failure.
# Safety Rules  : Leaves SSH (port 22) fully untouched to prevent lockout.
# ==============================================================================

set -euo pipefail

echo "[+] Simulating Storage Network Partition..."
echo "[*] Adding temporary UFW rule to block inbound TCP port 2049..."

# Insert drop rule at the top of UFW
ufw insert 1 deny proto tcp from any to any port 2049

echo "[!] Inbound NFS port 2049 is now BLOCKED."
echo "[*] Client symptom: In-flight client I/O will pause, retrying per mount options (timeo=150, retrans=3)."
echo "[*] Log symptom: Check client kernel logs via 'dmesg -T | grep -i nfs'."
echo ""
echo "To restore network connectivity, run: ./reset_lab.sh"
