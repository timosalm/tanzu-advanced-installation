#!/bin/bash
TANZU_CMD=${TANZU_CMD:-tanzu }
VALUES_YAML=${1:-values.yaml}


if [ ! -f ~/.tanzu/tkg/config.yaml ]; then
  $TANZU_CMD management-cluster create 2>&1 > /dev/null 
fi

# Generate Management
if [ -f generated/tkg-config-mgmt.yaml ]; then
  echo "Management config exists, skipping generation"
else
  ytt -f $VALUES_YAML -f ~/.tanzu/tkg/config.yaml -f overlays/tkg-config-core.yaml -f overlays/tkg-config-mgmt-cluster.yaml --ignore-unknown-comments > generated/tkg-config-mgmt.yaml
fi

if $TANZU_CMD management-cluster get | grep -q 'mgmt'; then
   echo "Detected management cluster(s) already present"
else
   $TANZU_CMD management-cluster create --file generated/tkg-config-mgmt.yaml
fi

# Generate Demo cluster
if [ -f generated/tkg-config-worker.yaml ]; then
  echo "Worker config exists, skipping generation"
else
  ytt -f $VALUES_YAML -f ~/.tanzu/tkg/config.yaml -f overlays/tkg-config-core.yaml -f overlays/tkg-config-worker-cluster.yaml --ignore-unknown-comments > generated/tkg-config-worker.yaml
fi

if $TANZU_CMD cluster list | grep -q 'demo'; then
   echo "Detected demo cluster(s) already present"
else
   $TANZU_CMD cluster create  demo --file generated/tkg-config-worker.yaml
fi
