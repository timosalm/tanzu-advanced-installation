#!/bin/bash
VALUES_YAML=${1:-values.yaml}

ytt -f overlays/tls-certificate-delegation/ -f $VALUES_YAML | kapp deploy -a tls-certificate-delegation -f- --diff-changes --yes