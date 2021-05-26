#!/bin/bash
VALUES_YAML=values.yaml

kubectl apply -f extensions/tkg-extensions-v1.3.0/extensions/registry/harbor/namespace-role.yaml

if [ -f generated/harbor-data-values.yaml ]; then
  echo "Harbor config exists, skipping generation"
else
  cp extensions/tkg-extensions-v1.3.0/extensions/registry/harbor/harbor-data-values.yaml.example generated/harbor-data-values.yaml
  ./extensions/tkg-extensions-v1.3.0/extensions/registry/harbor/generate-passwords.sh generated/harbor-data-values.yaml
fi

# Configure ingress domain
CONFIGURED_INGRESS_DOMAIN="harbor."
CONFIGURED_INGRESS_DOMAIN+=$(cat $VALUES_YAML | grep ingress -A 3 | awk '/domain:/ {print $2}')
HARBOR_DATAVALUES=$(cat generated/harbor-data-values.yaml | sed "s/core.harbor.domain/$CONFIGURED_INGRESS_DOMAIN/")
# Set placeholder Ingress certificate configuration for the overlay
HARBOR_DATAVALUES=$(echo $HARBOR_DATAVALUES | sed "s/tls.crt:/tls.crt: IRRELEVANT/" | sed "s/tls.key:/tls.key: IRRELEVANT/")
CONFIGURED_HARBOR_ADMIN_PASSWORD=$(cat $VALUES_YAML | grep harbor -A 3 | awk '/adminPassword:/ {print $2}')
# Set admin password
HARBOR_DATAVALUES=$(echo $HARBOR_DATAVALUES | sed "s/harborAdminPassword:/harborAdminPassword: $CONFIGURED_HARBOR_ADMIN_PASSWORD/")
# Increase registry disk size
CONFIGURED_HARBOR_DISK_SIZE=$(cat $VALUES_YAML | grep harbor -A 3 | awk '/diskSize:/ {print $2}')
HARBOR_DATAVALUES=$(echo $HARBOR_DATAVALUES | sed "s/size: 10Gi/size: $CONFIGURED_HARBOR_DISK_SIZE/")

kubectl create secret generic harbor-data-values --from-literal=values.yaml=$HARBOR_DATAVALUES -n tanzu-system-registry

kubectl create configmap ingress-secret-name-overlay --from-file=ingress-secret-name-overlay.yaml=overlays/harbor/ingress-overlay.yaml -n tanzu-system-registry
cat extensions/tkg-extensions-v1.3.0/extensions/registry/harbor/harbor-extension.yaml | sed "s/name: harbor-data-values/name: harbor-data-values\n                - configMapRef:\n                    name: ingress-secret-name-overlay/"  | kubectl apply -f-
