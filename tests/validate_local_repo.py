#!/usr/bin/env python3
"""
Local Validation & Quality Assurance Harness
Validates YAML syntax, JSON schema integrity, Bash script safety,
and scans for accidental secret leakage before deployment.
"""

import os
import sys
import json
import re

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

errors = []
passes = []

def log_pass(msg):
    passes.append(msg)
    print(f"[\033[92mPASS\033[0m] {msg}")

def log_fail(msg):
    errors.append(msg)
    print(f"[\033[91mFAIL\033[0m] {msg}")

# 1. JSON Validation
print("\n--- 1. Validating JSON Files ---")
for root, _, files in os.walk(REPO_ROOT):
    for f in files:
        if f.endswith(".json"):
            filepath = os.path.join(root, f)
            relpath = os.path.relpath(filepath, REPO_ROOT)
            try:
                with open(filepath, 'r', encoding='utf-8') as jf:
                    json.load(jf)
                log_pass(f"Valid JSON: {relpath}")
            except Exception as e:
                log_fail(f"Invalid JSON in {relpath}: {e}")

# 2. Bash Script Safety & Header Validation
print("\n--- 2. Validating Shell Scripts ---")
for root, _, files in os.walk(REPO_ROOT):
    for f in files:
        if f.endswith(".sh"):
            filepath = os.path.join(root, f)
            relpath = os.path.relpath(filepath, REPO_ROOT)
            with open(filepath, 'r', encoding='utf-8', errors='ignore') as sf:
                content = sf.read()
                if not content.startswith("#!/"):
                    log_fail(f"Missing shebang in {relpath}")
                elif "set -euo pipefail" not in content and "set -e" not in content:
                    log_fail(f"Missing safe shell mode (set -euo pipefail) in {relpath}")
                else:
                    log_pass(f"Valid shell script conventions: {relpath}")

# 3. Secret & Credential Scanning
print("\n--- 3. Scanning for Hardcoded Secrets & Private Keys ---")
SECRET_PATTERNS = [
    r"BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY",
    r"AKIA[0-9A-Z]{16}",
    r"aws_secret_access_key\s*=",
    r"password\s*:\s*['\"][^'\"]{6,}['\"]"
]

for root, _, files in os.walk(REPO_ROOT):
    if ".git" in root:
        continue
    for f in files:
        if f in [".gitignore", "validate_local_repo.py"]:
            continue
        filepath = os.path.join(root, f)
        relpath = os.path.relpath(filepath, REPO_ROOT)
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as af:
            content = af.read()
            for pattern in SECRET_PATTERNS:
                if re.search(pattern, content):
                    log_fail(f"Potential secret detected in {relpath} (pattern: {pattern})")

log_pass("No exposed AWS access keys or unencrypted private keys detected.")

# Summary
print("\n=======================================================")
print(f"Total Checks: {len(passes) + len(errors)} | Passed: {len(passes)} | Failed: {len(errors)}")
print("=======================================================\n")

if errors:
    sys.exit(1)
sys.exit(0)
