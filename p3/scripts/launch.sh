#!/bin/bash

# Create a k3d cluster
k3d cluster delete argocd || true
k3d cluster create argocd --api-port 127.0.0.1:6443 -p "8888:80@loadbalancer" -p "8080:443@loadbalancer"

# Install Argo CD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait until Argo CD installation is complete
kubectl wait --for=condition=Established --timeout=120s crd/applications.argoproj.io crd/appprojects.argoproj.io
kubectl -n argocd wait --for=condition=Ready pod --all --timeout=180s
kubectl -n kube-system wait --for=condition=Ready --timeout=120s pod -l app.kubernetes.io/name=traefik

# kubectl -n argocd patch deploy argocd-server \
#   -p '{"spec":{"template":{"spec":{"containers":[{"name":"argocd-server","args":["--insecure"]}]}}}}'

# Apply the Argo CD Application
kubectl apply -n argocd -f ./confs/argocd-application.yaml
# sleep 5
kubectl apply -n argocd -f ./confs/argocd-ingress.yaml
