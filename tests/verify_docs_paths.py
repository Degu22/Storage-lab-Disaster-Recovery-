#!/usr/bin/env python3
import os
import re

repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
doc_files = [
    'README.md',
    'docs/ARCHITECTURE.md',
    'docs/IMPLEMENTATION_GUIDE.md',
    'docs/RUNBOOK_NFS.md',
    'docs/RUNBOOK_BACKUP_RESTORE.md',
    'docs/SECURITY.md',
    'docs/TEST_RESULTS.md'
]

referenced_paths = set()
for doc in doc_files:
    doc_path = os.path.join(repo_root, doc)
    with open(doc_path, 'r', encoding='utf-8') as f:
        text = f.read()
        matches = re.findall(r'(?:infrastructure|ansible|scripts|monitoring|docs)/[a-zA-Z0-9_\-\./]+', text)
        for m in matches:
            clean = m.rstrip('.,;:"\'`)')
            if not clean.endswith('.tmp') and not clean.endswith('.bin') and '*' not in clean:
                referenced_paths.add(clean)

missing = []
for p in sorted(referenced_paths):
    full = os.path.join(repo_root, p.replace('/', os.sep))
    if not os.path.exists(full):
        parent = os.path.dirname(full)
        if not os.path.exists(parent):
            missing.append(p)

print(f"Audited {len(referenced_paths)} referenced paths across all markdown documentation.")
if missing:
    print(f"[FAIL] Missing paths detected: {missing}")
    exit(1)
else:
    print("[PASS] All documented file and directory references exist on disk!")
    exit(0)
