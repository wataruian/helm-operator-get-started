#!/bin/bash

set -o errexit # Bail out on any error

if [[ ! -x "$(command -v kubectl)" ]]; then
    echo "kubectl not found"
    exit 1
fi

if [[ ! -x "$(command -v helm)" ]]; then
    echo "helm not found"
    exit 1
fi

helm -n fluxcd delete flux
kubectl -n istio-system delete istiooperators.install.istio.io --all
helm -n fluxcd delete helm-operator
helm -n istio-system delete flagger
helm -n istio-system delete flagger-grafana
kubectl delete namespace istio-system
kubectl delete namespace istio-operator
kubectl delete namespace fluxcd
