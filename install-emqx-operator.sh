#!/usr/bin/env bash

set -euo pipefail

helm repo add jetstack https://charts.jetstack.io
helm repo add emqx https://repos.emqx.io/charts
helm repo update

kubectl create namespace emqx

helm upgrade --install cert-manager jetstack/cert-manager \
     --namespace emqx \
     --set namespace=emqx \
     --set crds.enabled=true

kubectl apply -f rbac/controller-manager-rbac.yaml

helm upgrade --install emqx-operator emqx/emqx-operator \
     --namespace emqx \
     --set namespace=emqx \
     --set serviceAccount.create=false \
     --set serviceAccount.name=controller-manager

kubectl -n emqx wait --for=condition=Ready pods -l "control-plane=controller-manager"
