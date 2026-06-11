#!/usr/bin/env bash
set -euo pipefail

required=(git curl jq)
missing=0

for cmd in "${required[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "ok: $cmd"
    else
        echo "missing: $cmd" >&2
        missing=1
    fi
done

echo '{"status":"ok","source":"devman"}' | jq -r '.status'
exit "$missing"
