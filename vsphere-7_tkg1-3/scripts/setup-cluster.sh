#!/bin/bash
TANZU_CMD=${TANZU_CMD:-tanzu }
WORKLOAD_CLUSTER_NAME=$1

if [ ! -f ~/.tanzu/tkg/config.yaml ]; then
  $TANZU_CMD management-cluster create 2>&1 > /dev/null 
fi

# Generate Management
if [ -f generated/tkg-config-mgmt.yaml ]; then
  echo "Management config exists, skipping generation"
else
  ytt -f $VALUES_YAML -f ~/.tanzu/tkg/config.yaml -f overlays/tkg-config-core.yaml -f overlays/tkg-config-mgmt-cluster.yaml --ignore-unknown-comments > generated/tkg-config-mgmt.yaml
fi

MANAGEMENT_CLUSTER_NAME=$(cat generated/tkg-config-mgmt.yaml | awk '/CLUSTER_NAME:/ {print $2}')
if $TANZU_CMD management-cluster get | grep -q $MANAGEMENT_CLUSTER_NAME; then
   echo "Detected management cluster(s) already present"
else
   $TANZU_CMD management-cluster create --file generated/tkg-config-mgmt.yaml
fi

# Generate Workload cluster
if [ -f generated/tkg-config-worker.yaml ]; then
  echo "Workload config exists, skipping generation"
else
  ytt -f $VALUES_YAML -f ~/.tanzu/tkg/config.yaml -f overlays/tkg-config-core.yaml -f overlays/tkg-config-worker-cluster.yaml --ignore-unknown-comments > generated/tkg-config-worker.yaml
fi

if $TANZU_CMD cluster list | grep -q $WORKLOAD_CLUSTER_NAME; then
   echo "Detected workload cluster(s) already present"
else
   $TANZU_CMD cluster create $WORKLOAD_CLUSTER_NAME --file generated/tkg-config-worker.yaml
fi
