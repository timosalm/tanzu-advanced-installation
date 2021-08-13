#!/bin/bash
kubectl apply -f extensions/$TKG_EXTENSIONS_FOLDER_NAME/extensions/registry/harbor/namespace-role.yaml

cp extensions/$TKG_EXTENSIONS_FOLDER_NAME/extensions/registry/harbor/harbor-data-values.yaml.example generated/harbor-data-values.yaml
./extensions/$TKG_EXTENSIONS_FOLDER_NAME/extensions/registry/harbor/generate-passwords.sh generated/harbor-data-values.yaml

# Configure ingress domain
HARBOR_HOSTNAME="harbor."
HARBOR_HOSTNAME+=$(cat $VALUES_YAML | grep ingress -A 3 | awk '/domain:/ {print $2}')
sed -i"" -e "s/core.harbor.domain/$HARBOR_HOSTNAME/" generated/harbor-data-values.yaml
# Use Ingress instead of HTTPProxy
sed -i"" -e "s/enableContourHttpProxy: true/enableContourHttpProxy: false/" generated/harbor-data-values.yaml
# Set placeholder Ingress certificate configuration for the overlay
sed -i"" -e "s/tls.crt:/tls.crt: IRRELEVANT/" generated/harbor-data-values.yaml
sed -i"" -e "s/tls.key:/tls.key: IRRELEVANT/" generated/harbor-data-values.yaml
CONFIGURED_HARBOR_ADMIN_PASSWORD=$(cat $VALUES_YAML | grep harbor -A 3 | awk '/adminPassword:/ {print $2}')
# Set admin password
GENERATED_HARBOR_ADMIN_PASSWORD=$(cat generated/harbor-data-values.yaml | grep harborAdminPassword | awk '/harborAdminPassword:/ {print $2}')
sed -i"" -e "s/$GENERATED_HARBOR_ADMIN_PASSWORD/$CONFIGURED_HARBOR_ADMIN_PASSWORD/" generated/harbor-data-values.yaml
# Increase registry disk size
CONFIGURED_HARBOR_DISK_SIZE=$(cat $VALUES_YAML | grep harbor -A 3 | awk '/diskSize:/ {print $2}')
sed -i"" -e "s/size: 10Gi/size: $CONFIGURED_HARBOR_DISK_SIZE/" generated/harbor-data-values.yaml

kubectl create secret generic harbor-data-values --from-file=values.yaml=generated/harbor-data-values.yaml -n tanzu-system-registry

kubectl create configmap ingress-secret-name-overlay --from-file=ingress-secret-name-overlay.yaml=overlays/harbor/ingress-overlay.yaml -n tanzu-system-registry
cat extensions/$TKG_EXTENSIONS_FOLDER_NAME/extensions/registry/harbor/harbor-extension.yaml | sed "s/name: harbor-data-values/name: harbor-data-values\n            - configMapRef:\n                name: ingress-secret-name-overlay/"  | kubectl apply -f-
