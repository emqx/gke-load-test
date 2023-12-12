#!/usr/bin/env bash

set -eou pipefail

helm repo add haproxytech https://haproxytech.github.io/helm-charts
helm install haproxy-kubernetes-ingress haproxytech/kubernetes-ingress \
    --create-namespace \
    --namespace haproxy-controller \
    --set controller.service.type=LoadBalancer
