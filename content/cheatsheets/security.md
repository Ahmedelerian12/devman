# Security Cheat Sheet

## Goal

Find risky defaults before attackers or production incidents find them.

## Steps

1. Inspect Dockerfile: `cat Dockerfile.insecure`
2. Look for root user, broad permissions, and unpinned versions.
3. Scan image or files with the tools you have available.
4. Write findings in `security-review.md`
5. Suggest safer alternatives.

## Done Looks Like

Each finding has impact, evidence, and a specific fix.
