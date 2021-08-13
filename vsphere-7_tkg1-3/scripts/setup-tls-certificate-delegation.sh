#!/bin/bash

ytt --ignore-unknown-comments -f overlays/tls-certificate-delegation/ -f $VALUES_YAML | kapp deploy -a tls-certificate-delegation -f- --diff-changes --yes