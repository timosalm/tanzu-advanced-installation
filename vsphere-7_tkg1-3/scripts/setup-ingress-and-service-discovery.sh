#!/bin/bash

# Default Storage class
APPLIED_DEFAULT_STORAGE_POLICY_NAME=$(kubectl get sc default -o jsonpath='{.parameters.storagepolicyname}')

(cat values.yaml | grep gcp -A 3 | awk '/project:/ {print $2}')
CONFIGURED_DEFAULT_STORAGE_POLICY_NAME=$(cat values.yaml | awk '/storage_policy_name:/ {print $2}')
if [[ $APPLIED_DEFAULT_STORAGE_POLICY_NAME != $CONFIGURED_DEFAULT_STORAGE_POLICY_NAME ]]; then
 kubectl delete sc default
 kubectl apply -f <(ytt -f $VALUES_YAML -f overlays/default-storage-class.yaml)
fi

# Tanzu Mission Control extension manager. The Tanzu Kubernetes Grid extensions and Tanzu Mission Control both use the same extension-manager service. You must install the extension manager even if you do not intend to use Tanzu Mission Control.
EXTENSION_MANAGER_EXISTS=$(kubectl get deployment extension-manager -n vmware-system-tmc --ignore-not-found | grep -c extension-manager)
if [ $EXTENSION_MANAGER_EXISTS -eq 0 ]; then
 kubectl apply -f extensions/$TKG_EXTENSIONS_FOLDER_NAME/extensions/tmc-extension-manager.yaml
fi

# CertManager
kapp deploy -a cert-manager -f extensions/$TKG_EXTENSIONS_FOLDER_NAME/cert-manager/ -f <(ytt --ignore-unknown-comments -f $VALUES_YAML -f overlays/cert-manager)

# Contour
kubectl apply -f extensions/$TKG_EXTENSIONS_FOLDER_NAME/extensions/ingress/contour/namespace-role.yaml

CONTOUR_SECRET_EXISTS=$(kubectl get secret contour-data-values -n tanzu-system-ingress --ignore-not-found | grep -c contour-data-values)
if [ $CONTOUR_SECRET_EXISTS -eq 0 ]; then
 kubectl delete secret contour-data-values -n tanzu-system-ingress
fi
kubectl create secret generic contour-data-values --from-file=values.yaml=overlays/contour/contour-data-values.yaml -n tanzu-system-ingress

CONFIGURED_INGRESS_DOMAIN=$(cat $VALUES_YAML | grep ingress -A 3 | awk '/domain:/ {print $2}')
sed -i"" -e "s/INGRESS_DOMAIN/$CONFIGURED_INGRESS_DOMAIN/" generated/external-dns-hostname-overlay.yaml
kubectl create configmap external-dns-hostname-overlay --from-file=external-dns-hostname-overlay.yaml=generated/external-dns-hostname-overlay.yaml -n tanzu-system-ingress
cat extensions/$TKG_EXTENSIONS_FOLDER_NAME/extensions/ingress/contour/contour-extension.yaml | sed "s/name: contour-data-values/name: contour-data-values\n            - configMapRef:\n                name: external-dns-hostname-overlay/" | kubectl apply -f-

# External DNS
kubectl apply -f extensions/$TKG_EXTENSIONS_FOLDER_NAME/extensions/service-discovery/external-dns/namespace-role.yaml

ytt --ignore-unknown-comments -f $VALUES_YAML -f overlays/external-dns/dns-provider-credentials-secret.yaml | kubectl apply -f-

EXTERNALDNS_SECRET_EXISTS=$(kubectl get secret external-dns-data-values -n tanzu-system-service-discovery --ignore-not-found | grep -c external-dns-data-values)
if [ $EXTERNALDNS_SECRET_EXISTS -eq 0 ]; then
 kubectl delete secret external-dns-data-values -n tanzu-system-service-discovery
fi

## Configure external dns provider. ytt doesn't support referencing data values from data values at this point!
CONFIGURED_GCP_PROJECT_NAME=$(cat values.yaml | grep gcp -A 3 | awk '/project:/ {print $2}')
if [ -n "$CONFIGURED_GCP_PROJECT_NAME" ]; then
    cat overlays/external-dns/external-dns-data-values-gcp.yaml | sed "s/REPLACE_WITH_GCP_PROJECT/$CONFIGURED_GCP_PROJECT_NAME/" | sed "s/REPLACE_WITH_INGRESS_DOMAIN/$CONFIGURED_INGRESS_DOMAIN/" | tee generated/external-dns-data-values.yaml
else
    cat overlays/external-dns/external-dns-data-values-aws.yaml | sed "s/REPLACE_WITH_INGRESS_DOMAIN/$CONFIGURED_INGRESS_DOMAIN/" | tee generated/external-dns-data-values.yaml
fi 

kubectl create secret generic external-dns-data-values --from-file=values.yaml=generated/external-dns-data-values.yaml -n tanzu-system-service-discovery
kubectl apply -f extensions/$TKG_EXTENSIONS_FOLDER_NAME/extensions/service-discovery/external-dns/external-dns-extension.yaml
