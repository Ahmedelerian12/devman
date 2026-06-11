# DevOps Capstone Platform

A full starter project with Docker, Kubernetes, Terraform notes, CI, and operations docs.

## Quick Start

```bash
docker build -t capstone-web:local .
docker run --rm -p 8080:80 capstone-web:local
kubectl apply -f k8s/
```

## Evidence

- Build logs
- Kubernetes rollout output
- Terraform plan notes
- CI checks
- Runbook updates
