# Capstone Cheat Sheet

## Goal

Build one portfolio workspace that connects Docker, Kubernetes, Terraform, CI,
observability, and runbooks.

## Steps

1. Create starter: `devman learn project devops-capstone-platform`
2. Build image: `docker build -t capstone-web:local .`
3. Run locally: `docker compose up --build`
4. Apply Kubernetes manifests in a local cluster.
5. Run Terraform format and validation.
6. Push through CI and fix pipeline failures.
7. Write architecture and runbook notes.

## Done Looks Like

Someone else can clone the project, read the README, run it, and understand how
to recover it.
