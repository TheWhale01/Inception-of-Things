#!/usr/bin/env bash
curl -sfL https://get.k3s.io | sh -
cp /var/lib/rancher/k3s/server/node-token /vagrant/.env.token