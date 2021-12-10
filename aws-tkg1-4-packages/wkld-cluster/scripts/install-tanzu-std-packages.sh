#!/bin/bash

# install cert manager 
tanzu package install cert-manager --package-name cert-manager.tanzu.vmware.com --namespace cert-manager --version 1.1.0+vmware.1-tkg.2 --create-namespace
ytt --ignore-unknown-comments -f values.yaml -f overlays/cert-manager | kubectl apply -f-

# install contour
ytt --ignore-unknown-comments -f values.yaml -f overlays/contour > generated/contour-data-values.yaml
tanzu package install contour --package-name contour.tanzu.vmware.com --version 1.17.1+vmware.1-tkg.1 --values-file generated/contour-data-values.yaml --namespace tanzu-std-packages --create-namespace

# install external dns
kubectl create namespace tanzu-system-service-discovery
ytt --ignore-unknown-comments -f values.yaml -f overlays/external-dns/dns-provider-credentials-secret.yaml | kubectl apply -f-
ytt --ignore-unknown-comments -f values.yaml -f overlays/external-dns/external-dns-data-values.yaml > generated/external-dns-data-values.yaml
tanzu package install external-dns --package-name external-dns.tanzu.vmware.com --version 0.8.0+vmware.1-tkg.1 --values-file generated/external-dns-data-values.yaml --namespace tanzu-std-packages

# install secret-reflector and reflect secret to harbor (and eduk8s) namespace
helm repo add emberstack https://emberstack.github.io/helm-charts
helm repo update
kubectl create namespace secret-reflector
helm template emberstack/reflector --name-template reflector -n secret-reflector \
  | kapp deploy -a secret-reflector -n secret-reflector -f- --diff-changes --yes

# install tls cert delegation
ytt --ignore-unknown-comments -f overlays/tls-certificate-delegation/ -f values.yaml | kapp deploy -a tls-certificate-delegation -f- --diff-changes --yes

# install harbor
ytt --ignore-unknown-comments -f values.yaml -f overlays/harbor/harbor-data-values.yaml > generated/harbor-data-values.yaml
tanzu package install harbor --package-name harbor.tanzu.vmware.com --version 2.2.3+vmware.1-tkg.1 --values-file generated/harbor-data-values.yaml --namespace tanzu-std-packages

## change harbor certificate
kubectl create secret generic ingress-secret-name-overlay --from-file=ingress-secret-name-overlay.yaml=overlays/harbor/ingress-overlay.yaml -n tanzu-std-packages
kubectl annotate packageinstalls harbor -n tanzu-std-packages ext.packaging.carvel.dev/ytt-paths-from-secret-name.0=ingress-secret-name-overlay

## https://kb.vmware.com/s/article/85725
kubectl create secret generic harbor-notary-singer-image-overlay --from-file=overlay-notary-signer-image-fix.yaml=overlays/harbor/overlay-notary-signer-image-fix.yaml -n tanzu-std-packages
kubectl annotate packageinstalls harbor -n tanzu-std-packages ext.packaging.carvel.dev/ytt-paths-from-secret-name.1=harbor-notary-singer-image-overlay



