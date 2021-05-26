#!/bin/bash
VALUES_YAML=values.yaml
BS_BUNDLE_FILE=$1
DEPENDENCY_DESCRIPTOR_FILE=$2

tar xvf $BS_BUNDLE_FILE -C /tmp

CONFIGURED_HARBOR_ADMIN_PASSWORD=$(cat $VALUES_YAML | grep harbor -A 3 | awk '/adminPassword:/ {print $2}')
CONFIGURED_INGRESS_DOMAIN="harbor."
CONFIGURED_INGRESS_DOMAIN+=$(cat $VALUES_YAML | grep ingress -A 3 | awk '/domain:/ {print $2}')
docker login $CONFIGURED_INGRESS_DOMAIN -u admin -p $CONFIGURED_HARBOR_ADMIN_PASSWORD
kbld relocate -f /tmp/images.lock --lock-output /tmp/images-relocated.lock --repository $CONFIGURED_INGRESS_DOMAIN/build-service/build-service

ytt -f /tmp/values.yaml \
    -f /tmp/manifests/ \
    -v docker_repository="$CONFIGURED_INGRESS_DOMAIN/build-service/build-service" \
    -v docker_username="admin" \
    -v docker_password="$CONFIGURED_HARBOR_ADMIN_PASSWORD" \
    | kbld -f /tmp/images-relocated.lock -f- \
    | kapp deploy -a tanzu-build-service -f- -y
kp import -f $DEPENDENCY_DESCRIPTOR_FILE
