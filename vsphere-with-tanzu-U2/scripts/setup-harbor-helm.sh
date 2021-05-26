#!/bin/bash

helm repo add harbor https://helm.goharbor.io
helm repo update
kubectl create ns harbor
kubectl create clusterrolebinding psp:authenticated --clusterrole=psp:vmware-system-privileged --group=system:authenticated
ytt -f overlays/harbor-helm/harbor-helm-values.yaml -f values.yaml \
  | helm template harbor/harbor --name-template harbor --version 1.4.6 -f- \
  | ytt -f- -f overlays/harbor-helm/harbor-dependencies.yaml -f values.yaml -f overlays/harbor-helm/integrate-contour-overlay.yaml --ignore-unknown-comments \
  | kapp deploy -a harbor -n harbor -f- --diff-changes --yes
