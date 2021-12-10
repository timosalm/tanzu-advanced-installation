# Unofficial Tanzu Advanced PoC guide for TKG 1.4 on AWS using Packages

It's always recommended to go through the [official documentation](https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.4/vmware-tanzu-kubernetes-grid-14/GUID-index.html) in addition to this guide! The scripts and commands in this guide were executed on a Linux jumpbox.

The setup requires a DNS zones to be able to create Let's Encrypt certificates and DNS entries to mitigate challenges with e.g. TBS, CNR and Harbor. The scripts support Route53, but you can use any provider that is supported by cert-manager, and external-dns. If you don't have a domain you can use for it, ask your colleagues.

## Prepare to deploy the management clusters to AWS
See documentation [here](https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.4/vmware-tanzu-kubernetes-grid-14/GUID-mgmt-clusters-aws.html)
If you choose a different EC2 Key Pair name that `cluster-api`, you have to change the `AWS_SSH_KEY_NAME` in the [mgmt-cluster.yaml](mgmt-cluster.yaml) and [wkld-cluster/cluster.yaml](wkld-cluster/cluster.yaml) files accordingly.

## Copy values-example.yaml to values.yaml and set configuration values
```
cp values-example.yaml values.yaml
```

## Deploy the management cluster from a configuration file
See documentation [here](https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.4/vmware-tanzu-kubernetes-grid-14/GUID-mgmt-clusters-deploy-cli.html)
After you followed the steps in the documentation, you can deploy the management cluster with the following command:
```
tanzu management-cluster create --file mgmt-cluster.yaml
```

## Deploy the workload cluster
See documentation [here](https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.4/vmware-tanzu-kubernetes-grid-14/GUID-tanzu-k8s-clusters-aws.html)

After you followed the steps in the documentation, you can deploy the workload cluster with the following command:
```
AWS_REGION=eu-central-1 tanzu cluster create wkld-cluster --file wkld-cluster/cluster.yaml
```

## Installation of TKG packages and other tools on the workload cluster

Prerequisites:
- Docker
- Carvel tool
- Pivnet CLI 
- kp CLI

```
pivnet login --api-token='xxx'
cd wkld-cluster
./scripts/install-tanzu-std-packages.sh
```

Then create the following projects in Harbor:
- build-service (private)
- concourse (public)
- dockerhub (public, DockerHub Proxy)

```
./scripts/install-other-components.sh
```

### TLS certificate replication
To replicate our tls certificate to namespaces with the new Ingress object that doesn't support referencing certificates in other namespaces, we use https://github.com/emberstack/kubernetes-reflector

Starting with cert-manager 1.5 it supports setting required annotations for the replication on the Certificate via "secretTemplate". As long as with Tanzu packages cert-manager 1.5 is not available, we have to set it manually on the secret:
```
kubectl annotate secret contour-tls-delegation-cert -n tanzu-system-ingress reflector.v1.k8s.emberstack.com/reflection-allowed="true" reflector.v1.k8s.emberstack.com/reflection-auto-namespaces="eduk8s,tanzu-system-registry,concourse,kubeapps" reflector.v1.k8s.emberstack.com/reflection-auto-enabled="true"
```

### Configuration of Cloud Native Runtimes for VMware Tanzu
After you installed CNR, you have to edit the following Kubernetes objects.
```bash
kubectl edit cm config-domain -n knative-serving
# data:
#  cnr.<your-ingress-domain>: ""
kubectl edit cm config-certmanager -n knative-serving
# data:
#  issuerRef: |
#   kind: ClusterIssuer
#   name: letsencrypt-contour-cluster-issuer
kubectl edit configmap config-network --namespace knative-serving
# data:
#   domainTemplate: "{{.Name}}-{{.Namespace}}.{{.Domain}}"
kubectl edit cm config-contour -n knative-serving
# data:
#   default-tls-secret: tanzu-system-ingress/cnr-contour-tls-delegation-cert
```

### Admin password for ArgoCD
The initial admin password is auto generated and available from a secret named `argocd-initial-admin-secret`. The `argocd.adminPassword` in the values.yaml has to be changed accordingly. 

## Notes
- For the mngmt and wkld cluster in different VPCs, I had to increase the quota:
  ```
  aws service-quotas request-service-quota-increase --region eu-central-1 --service-code ec2 --quota-code L-0263D0A3 --desired-value 20
  ```
