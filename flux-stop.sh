#!/bin/bash

set -o errexit # Bail out on any error

if [[ ! -x "$(command -v kubectl)" ]]; then
    echo "kubectl not found"
    exit 1
fi

kubectl -n fluxcd scale deployment flux --replicas=0
kubectl -n fluxcd scale deployment helm-operator --replicas=0
