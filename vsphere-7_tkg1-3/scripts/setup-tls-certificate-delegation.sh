#!/bin/bash
while getopts v flag
do
    case "${flag}" in
        v) VALUES_YAML=${OPTARG:-values.yaml};;
    esac
done

ytt -f overlays/tls-certificate-delegation/ -f $VALUES_YAML | kapp deploy -a tls-certificate-delegation -f- --diff-changes --yes