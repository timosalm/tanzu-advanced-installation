#!/bin/bash
TANZU_CMD=${TANZU_CMD:-tanzu}
VALUES_YAML=${1:-values.yaml}

kubectl apply -f extensions/tkg-extensions-v1.3.0/extensions/registry/harbor/namespace-role.yaml

kubectl create secret generic harbor-data-values --from-file=values.yaml=overlays/harbor/harbor-data-values.yaml -n tanzu-system-registry

# TODO Add YTT and temp value
kubectl create configmap ingress-secret-name-overlay --from-file=ingress-secret-name-overlay.yaml=overlays/harbor/ingress-secret-name-overlay.yaml -n tanzu-system-registry

kubectl apply -f overlays/harbor/harbor-extension.yaml