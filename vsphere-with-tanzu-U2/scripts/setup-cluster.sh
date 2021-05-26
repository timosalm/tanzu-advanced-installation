#!/bin/bash
VALUES_YAML=values.yaml

ytt --ignore-unknown-comments -f $VALUES_YAML -f tanzu-advanced-cluster.yaml | kubectl apply -f-