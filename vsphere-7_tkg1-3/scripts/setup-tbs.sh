#!/bin/bash

TANZUNET_USERNAME=$(cat $VALUES_YAML | grep tanzunet -A 3 | awk '/username:/ {print $2}')
TANZUNET_PASSWORD=$(cat $VALUES_YAML | grep tanzunet -A 3 | awk '/password:/ {print $2}')
docker login registry.pivotal.io -u $TANZUNET_USERNAME -p $TANZUNET_PASSWORD

CONFIGURED_HARBOR_ADMIN_PASSWORD=$(cat $VALUES_YAML | grep harbor -A 3 | awk '/adminPassword:/ {print $2}')
HARBOR_HOSTNAME="harbor."
HARBOR_HOSTNAME+=$(cat $VALUES_YAML | grep ingress -A 3 | awk '/domain:/ {print $2}')
docker login $HARBOR_HOSTNAME -u admin -p $CONFIGURED_HARBOR_ADMIN_PASSWORD

imgpkg copy -b "registry.pivotal.io/build-service/bundle:1.2.1" --to-repo $HARBOR_HOSTNAME/build-service/build-service
imgpkg pull -b "$HARBOR_HOSTNAME/build-service/build-service:1.2.1" -o /tmp/bundle

ytt -f /tmp/bundle/values.yaml \
    -f /tmp/bundle/config/ \
    -v docker_repository="$HARBOR_HOSTNAME/build-service/build-service" \
    -v docker_username="admin" \
    -v docker_password="$CONFIGURED_HARBOR_ADMIN_PASSWORD" \
    -v tanzunet_username="$TANZUNET_USERNAME" \
    -v tanzunet_password="$TANZUNET_PASSWORD" \
    | kbld -f /tmp/bundle/.imgpkg/images.yml -f- \
    | kapp deploy -a tanzu-build-service -f- -