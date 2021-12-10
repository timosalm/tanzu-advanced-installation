#!/bin/bash

# install tbs
TANZUNET_USERNAME=$(cat values.yaml | grep tanzunet -A 3 | awk '/username:/ {print $2}')
TANZUNET_PASSWORD=$(cat values.yaml  | grep tanzunet -A 3 | awk '/password:/ {print $2}')
docker login registry.pivotal.io -u $TANZUNET_USERNAME -p $TANZUNET_PASSWORD

CONFIGURED_HARBOR_ADMIN_PASSWORD=$(cat values.yaml | grep harbor -A 3 | awk '/adminPassword:/ {print $2}')
HARBOR_HOSTNAME="harbor."
HARBOR_HOSTNAME+=$(cat values.yaml | grep ingress -A 3 | awk '/domain:/ {print $2}')
docker login $HARBOR_HOSTNAME -u admin -p $CONFIGURED_HARBOR_ADMIN_PASSWORD

imgpkg copy -b "registry.pivotal.io/build-service/bundle:1.3.4" --to-repo $HARBOR_HOSTNAME/build-service/build-service
imgpkg pull -b "$HARBOR_HOSTNAME/build-service/build-service:1.3.4" -o /tmp/bundle

ytt -f /tmp/bundle/values.yaml \
    -f /tmp/bundle/config/ \
  -v kp_default_repository="$HARBOR_HOSTNAME/build-service/build-service" \
  -v kp_default_repository_username="admin" \
  -v kp_default_repository_password="$CONFIGURED_HARBOR_ADMIN_PASSWORD" \
  -v pull_from_kp_default_repo=true \
  -v tanzunet_username="$TANZUNET_USERNAME" \
  -v tanzunet_password="$TANZUNET_PASSWORD" \
  | kbld -f /tmp/bundle/.imgpkg/images.yml -f- \
  | kapp deploy -a tanzu-build-service -f- -y

# install cnr

pivnet download-product-files --product-slug='serverless' --release-version='1.0.3+build.112' --product-file-id=1068818 --download-dir=/tmp/
tar -xvf /tmp/cloud-native-runtimes-1.0.3.tgz -C /tmp
CURRENT_DIR=$PWD
cd /tmp/cloud-native-runtimes
cnr_ingress__reuse_crds=true cnr_ingress__external__namespace==tanzu-system-ingress ./bin/install.sh
cd $CURRENT_DIR

# install kubeapps

helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
kubectl create namespace kubeapps
ytt -f overlays/kubeapps/kubeapps-helm-values.yaml -f values.yaml \
  | helm template bitnami/kubeapps --version 4.0.4 --namespace kubeapps --name-template kubeapps -f- \
  | ytt -f- -f overlays/kubeapps/kubeapps-dependencies.yaml -f values.yaml \
  | kapp deploy -a kubeapps -n kubeapps -f- --diff-changes --yes

# install educates

kubectl apply -k "github.com/eduk8s/eduk8s?ref=master"
INGRESS_DOMAIN=$(cat values.yaml | grep ingress -A 3 | awk '/domain:/ {print $2}')
TLS_DELEGATION_CERT_NAME=$(cat values.yaml | grep ingress -A 3 | awk '/contour_tls_secret:/ {print $2}')
kubectl set env deployment/eduk8s-operator -n eduk8s INGRESS_DOMAIN=$INGRESS_DOMAIN
kubectl set env deployment/eduk8s-operator -n eduk8s INGRESS_SECRET=$TLS_DELEGATION_CERT_NAME

# install concourse

docker pull harbor-repo.vmware.com/tsl-end2end/concourse/concourse-helper
docker tag harbor-repo.vmware.com/tsl-end2end/concourse/concourse-helper $HARBOR_HOSTNAME/concourse/concourse-helper
docker push $HARBOR_HOSTNAME/concourse/concourse-helper

helm repo add concourse https://concourse-charts.storage.googleapis.com/
helm repo update

WORKER_NODE_1=$(kubectl get node --selector='!node-role.kubernetes.io/master' -o jsonpath='{.items[0].metadata.name}')
kubectl taint node $WORKER_NODE_1 type=concourse:PreferNoSchedule
kubectl label node $WORKER_NODE_1 type=concourse

WORKER_NODE_2=$(kubectl get node --selector='!node-role.kubernetes.io/master' -o jsonpath='{.items[1].metadata.name}')
kubectl taint node $WORKER_NODE_2 type=concourse:PreferNoSchedule
kubectl label node $WORKER_NODE_2 type=concourse

kubectl create namespace concourse
ytt -f overlays/concourse/concourse-helm-values.yaml -f values.yaml \
  | helm template concourse/concourse --name-template concourse -n concourse -f- \
  | ytt -f- -f overlays/concourse/concourse-dependencies.yaml -f overlays/concourse/storage-class.yaml -f values.yaml --ignore-unknown-comments \
  | kapp deploy -a concourse -n concourse -f- --diff-changes --yes

# install argocd

kubectl create ns argocd
ytt -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml -f overlays/argocd/integrate-contour-overlay.yaml --file-mark 'install.yaml:type=yaml-plain' -f overlays/argocd/argocd-dependencies.yaml -f values.yaml | kapp deploy -n argocd -a argocd -f- --diff-changes --yes

# install gitea

kubectl create ns gitea
helm repo add gitea-charts https://dl.gitea.io/charts/
helm repo update
ytt -f overlays/gitea/gitea-helm-values.yaml -f values.yaml \
  | helm template gitea-charts/gitea --name-template gitea -n gitea -f- \
  | ytt -f- -f overlays/gitea/gitea-dependencies.yaml -f values.yaml --ignore-unknown-comments \
  | kapp deploy -a gitea -n gitea -f- --diff-changes --yes

# install artifactory

kubectl create ns artifactory-oss
helm repo add jfrog https://charts.jfrog.io
helm repo update
ytt -f overlays/artifactory/artifactory-helm-values.yaml -f values.yaml \
  | helm template jfrog/artifactory --name-template artifactory-oss -n artifactory-oss -f- \
  | ytt -f- -f overlays/artifactory/bootstrap-config.yaml  \
  | kapp deploy -a artifactory -n artifactory-oss -f- --diff-changes --yes
