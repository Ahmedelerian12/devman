#!/usr/bin/env bash
set -euo pipefail

uname -a
df -h .
command -v ss >/dev/null 2>&1 && ss -tuln || netstat -an 2>/dev/null || true
curl -I -L --max-time 10 https://example.com
