# Shell Cheat Sheet

## Goal

Write scripts that fail clearly and help you debug faster.

## Steps

1. Start with strict mode: `set -euo pipefail`
2. Check tools: `command -v jq >/dev/null || exit 1`
3. Print useful messages before risky commands.
4. Quote variables: `"$file"`
5. Return meaningful exit codes.
6. Test success: `bash devops-health.sh`
7. Test failure by removing or changing one expected input.

## Done Looks Like

`devman learn validate shell .` passes, and `devops-health.sh` gives a clear
message when something is missing.
