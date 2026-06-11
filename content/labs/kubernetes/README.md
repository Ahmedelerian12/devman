# Kubernetes Lab

```bash
minikube start
kubectl apply -f k8s/
kubectl get deploy,svc,pods
kubectl rollout status deployment/devman-web
kubectl port-forward service/devman-web 8080:80
```
