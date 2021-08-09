#!/bin/bash

kubectl apply -f extensions/$TKG_EXTENSIONS_FOLDER_NAME/extensions/kapp-controller-config.yaml
kubectl apply -f extensions/$TKG_EXTENSIONS_FOLDER_NAME/extensions/kapp-controller.yaml
