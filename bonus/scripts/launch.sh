#!/bin/bash

GITLAB_PERSONAL_ACCESS_TOKEN=$(tr -dc 'a-zA-Z' < /dev/urandom | head -c 26)

# Create a k3d cluster
k3d cluster delete argocd || true
k3d cluster create argocd --api-port 127.0.0.1:6443 -p "8888:80@loadbalancer" -p "8080:443@loadbalancer"
rm -rf jrossett

# Install Argo CD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Install Gitlab
helm repo add gitlab https://charts.gitlab.io/
helm repo update
kubectl create namespace gitlab
helm install gitlab gitlab/gitlab -n gitlab -f ./confs/gitlab-values.yaml
echo "Waiting for webservice to be ready..."
kubectl wait --for=condition=ready pod -l app=webservice,release=gitlab -n gitlab --timeout=600s
kubectl port-forward svc/gitlab-webservice-default -n gitlab 8181:8181 &
kubectl --namespace gitlab exec -it deployment/gitlab-toolbox -- /srv/gitlab/bin/rails runner "token = User.find_by_username('root').personal_access_tokens.create(scopes: ['api', 'read_repository', 'write_repository'], name: 'Outstanding token', expires_at: 125.days.from_now); token.set_token('${GITLAB_PERSONAL_ACCESS_TOKEN}'); token.save!"
curl --request POST --header "PRIVATE-TOKEN: ${GITLAB_PERSONAL_ACCESS_TOKEN}" \
        --url "http://gitlab.iot.com:8181/api/v4/projects" \
        --form "visibility=public" --form "name=jrossett"
git clone https://github.com/J-Rossetti/jrossett.git
cd jrossett
git remote add gitlab http://gitlab.iot.com:8181/root/jrossett
git push gitlab main

# Wait until Argo CD installation is complete
kubectl wait --for=condition=Established --timeout=120s crd/applications.argoproj.io crd/appprojects.argoproj.io
kubectl -n argocd wait --for=condition=Ready pod --all --timeout=180s
kubectl -n kube-system wait --for=condition=Ready --timeout=120s pod -l app.kubernetes.io/name=traefik

# ByPass HTTPS connection
kubectl -n argocd patch configmap argocd-cmd-params-cm --type merge -p '{"data":{"server.insecure":"true"}}'
kubectl -n argocd rollout restart deploy/argocd-server
kubectl -n argocd wait --for=condition=Available deploy/argocd-server --timeout=120s

# Apply the Argo CD Application
kubectl apply -n argocd -f /home/whale/code/Inception-of-Things/bonus/confs/argocd-application.yaml
kubectl apply -n argocd -f /home/whale/code/Inception-of-Things/bonus/confs/argocd-ingress.yaml
