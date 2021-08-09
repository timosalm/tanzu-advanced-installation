#!/bin/bash
VALUES_YAML=values.yaml
CONFIGURED_INGRESS_DOMAIN=$(cat $VALUES_YAML | grep ingress -A 3 | awk '/domain:/ {print $2}')
helm repo add gitlab https://charts.gitlab.io/
helm repo update
kubectl create ns gitlab
helm upgrade --install gitlab gitlab/gitlab \
  --timeout 600s \
  --set global.hosts.domain=$CONFIGURED_INGRESS_DOMAIN \
  --set certmanager.install=false \
  --set global.ingress.configureCertmanager=false \
  --set global.ingress.tls.secretName=tanzu-system-ingress/contour-tls-delegation-cert \
  --set global.ingress.class=contour \
  --set nginx-ingress.enabled=false -n gitlab
