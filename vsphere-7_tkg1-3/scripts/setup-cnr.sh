#!/bin/bash

cd cloud-native-runtimes
cnr_ingress__reuse_crds=true cnr_ingress__external__namespace==tanzu-system-ingress ./bin/install.sh
cd ..
