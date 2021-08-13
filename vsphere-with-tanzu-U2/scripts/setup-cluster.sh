#!/bin/bash

ytt --ignore-unknown-comments -f $VALUES_YAML -f tanzu-advanced-cluster.yaml | kubectl apply -f-