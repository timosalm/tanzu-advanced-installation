#!/bin/bash
TANZU_CMD=${TANZU_CMD:-tanzu}
VALUES_YAML=${1:-values.yaml}

# Default Storage class
APPLIED_DEFAULT_STORAGE_POLICY_NAME=$(kubectl get sc default -o jsonpath='{.parameters.storagepolicyname}')
CONFIGURED_DEFAULT_STORAGE_POLICY_NAME=$(cat values.yaml | grep storage_policy_name | awk '{ print $NF }')
if [[ $APPLIED_DEFAULT_STORAGE_POLICY_NAME != $CONFIGURED_DEFAULT_STORAGE_POLICY_NAME ]]; then
 kubectl delete sc default
 kubectl apply -f <(ytt -f $VALUES_YAML -f overlays/default-storage-class.yaml)
fi

# Tanzu Mission Control extension manager. The Tanzu Kubernetes Grid extensions and Tanzu Mission Control both use the same extension-manager service. You must install the extension manager even if you do not intend to use Tanzu Mission Control.
EXTENSION_MANAGER_EXISTS=$(kubectl get deployment extension-manager -n vmware-system-tmc --ignore-not-found | grep -c extension-manager)
if [ $EXTENSION_MANAGER_EXISTS -eq 0 ]; then
 kubectl apply -f extensions/tkg-extensions-v1.3.0/extensions/tmc-extension-manager.yaml
fi

# CertManager
kapp deploy -a cert-manager -f extensions/tkg-extensions-v1.3.0/cert-manager/ -f <(ytt -f values.yaml -f overlays/cert-manager)

# Contour
kubectl apply -f extensions/tkg-extensions-v1.3.0/extensions/ingress/contour/namespace-role.yaml

## TODO check if available
kubectl delete secret contour-data-values -n tanzu-system-ingress
kubectl create secret generic contour-data-values --from-file=values.yaml=overlays/contour/contour-data-values.yaml -n tanzu-system-ingress
kubectl apply -f extensions/tkg-extensions-v1.3.0/extensions/ingress/contour/contour-extension.yaml

# External DNS
kubectl apply -f extensions/tkg-extensions-v1.3.0/extensions/service-discovery/external-dns/namespace-role.yaml

ytt --ignore-unknown-comments -f $VALUES_YAML -f overlays/external-dns/gcp-credentials-secret.yaml | kubectl apply -f-

kubectl delete secret external-dns-data-values -n tanzu-system-service-discovery
kubectl create secret generic external-dns-data-values --from-file=values.yaml=overlays/external-dns/external-dns-data-values.yaml -n tanzu-system-service-discovery
kubectl apply -f extensions/tkg-extensions-v1.3.0/extensions/service-discovery/external-dns/external-dns-extension.yaml

# Service not found?!
kubectl annotate service envoy external-dns.alpha.kubernetes.io/hostname='*.demo.tanzu.space' -n tanzu-system-ingress --overwrite