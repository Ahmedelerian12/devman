# Observability Cheat Sheet

## Goal

Use logs, metrics, traces, and alerts to explain system behavior.

## Steps

1. Start services: `docker compose up`
2. Check health: `docker compose ps`
3. Read logs: `docker compose logs`
4. Open Prometheus config: `cat prometheus.yml`
5. Write an alert idea in `runbook.md`
6. Stop services: `docker compose down`

## Done Looks Like

Your runbook says what to check first, what normal looks like, and when to alert.
