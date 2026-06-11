# Kubernetes Cheat Sheet

## Goal

Apply manifests, inspect pods, expose an app, and debug events.

## Steps

1. Check cluster: `kubectl config current-context`
2. Check nodes: `kubectl get nodes`
3. Apply manifests: `kubectl apply -f k8s/`
4. Watch pods: `kubectl get pods -w`
5. Read events: `kubectl get events --sort-by=.lastTimestamp`
6. Inspect rollout: `kubectl rollout status deployment/devman-web`
7. See logs: `kubectl logs deploy/devman-web`
8. Clean up: `kubectl delete -f k8s/`

## Done Looks Like

You can explain why a pod is Pending, CrashLoopBackOff, or Ready.
