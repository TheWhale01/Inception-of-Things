#!/usr/bin/env bash

# Install k3s server
curl -sfL https://get.k3s.io | sh -

# Start services
apps=("pgadmin" "redis-commander" "nginx")

for app in "${apps[@]}";
do
    kubectl apply -f /vagrant/confs/${app}.yaml
    kubectl apply -f /vagrant/confs/${app}-service.yaml
done

kubectl apply -f /vagrant/confs/ingress.yaml
