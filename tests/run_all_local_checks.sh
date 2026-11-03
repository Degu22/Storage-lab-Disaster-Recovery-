#!/usr/bin/env bash
# ==============================================================================
# Script Name   : run_all_local_checks.sh
# Purpose       : Executes all local linting, syntax, and static analysis checks.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=== 1. Running Python QA & Security Scanner ==="
python3 "${SCRIPT_DIR}/validate_local_repo.py"

echo "=== 2. Running Shell Script Syntax Checks (bash -n) ==="
find "${REPO_ROOT}/scripts" -name "*.sh" -exec bash -n {} +
echo "[PASS] All shell scripts passed syntax checks."

echo "=== 3. Checking YAML Files ==="
find "${REPO_ROOT}/ansible" "${REPO_ROOT}/monitoring" -name "*.yml" -o -name "*.yaml" | while read -r yfile; do
    python3 -c "import yaml; yaml.safe_load(open('$yfile'))" 2>/dev/null || {
        echo "[FAIL] Invalid YAML in $yfile"
        exit 1
    }
done
echo "[PASS] All YAML configurations are structurally valid."

echo "=== ALL LOCAL PRE-FLIGHT VALIDATION CHECKS PASSED ==="
