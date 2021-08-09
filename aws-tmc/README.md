# Unofficial Tanzu Advanced PoC guide for TKG 1.3.1 on AWS

It's always recommended to go through the official documentation in addition to this guide!
The scripts and commands in this guide were executed on a Linux jumpbox.
The scripts are based on the amazing work done for TKG 1.1 [here](https://github.com/tanzu-end-to-end/clusters).

The setup requires a DNS zones to be able to create Let's Encrypt certificates and DNS entries to mitigate challenges with e.g. TBS, CNR and Harbor. The scripts support Route53 and GCloud DNS, but you can use any provider that is supported by cert-manager, and external-dns. 
If you don't have a domain you can use for it, ask your colleagues. 

## Provision a cluster with TMC on AWS
1. Connect an AWS account for cluster lifecycle management in your aws-hosted management cluster. *Documentation: https://docs.vmware.com/en/VMware-Tanzu-Mission-Control/services/tanzumc-using/GUID-FADEC8C7-5DA0-4BEE-AE16-F4C7C7433123.html*
2. Provision a cluster in your aws-hosted management cluster. My recommendation ist to start with a HA setup(3 control plane nodes, m5.xlarge) and 5 worker nodes(m5.2xlarge) *Documentation: https://docs.vmware.com/en/VMware-Tanzu-Mission-Control/services/tanzumc-using/GUID-03F4C9E1-34BB-4365-8BC6-52BE797CFF7E.html*

## Install the Carvel tools
*Documentation: https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.3/vmware-tanzu-kubernetes-grid-13/GUID-install-cli.html#install-carvel*

```
wget https://github.com/vmware-tanzu/carvel-ytt/releases/download/v0.35.1/ytt-linux-amd64
wget https://github.com/vmware-tanzu/carvel-kbld/releases/download/v0.30.0/kbld-linux-amd64
wget https://github.com/vmware-tanzu/carvel-imgpkg/releases/download/v0.17.0/imgpkg-linux-amd64
wget https://github.com/vmware-tanzu/carvel-kapp/releases/download/v0.37.0/kapp-linux-amd64

chmod +x imgpkg-linux-amd64 kapp-linux-amd64 kbld-linux-amd64 ytt-linux-amd64
sudo mv imgpkg-linux-amd64 /usr/local/bin/imgpkg
sudo mv kapp-linux-amd64  /usr/local/bin/kapp
sudo mv kbld-linux-amd64 /usr/local/bin/kbld
sudo mv ytt-linux-amd64 /usr/local/bin/ytt
```
## Copy values-example.yaml to values.yaml, set configuration values and set env variable
```
cp values-example.yaml values.yaml
export VALUES_YAML=values.yaml
```
## Get cluster credentials and set the context
Connect to te provisioned cluster with kubectl. *Documentation: https://docs.vmware.com/en/VMware-Tanzu-Mission-Control/services/tanzumc-using/GUID-B4038ACB-2DCF-437F-87B6-1628DF253C82.html*

```
export KUBECONFIG=<path-to-downloaded-kubeconfig>
kubectl config use-context <cluster-context-name>
```

If you have (krew)[https://github.com/kubernetes-sigs/krew] installed, you can import the kubeconfig into your default with the (konfig)[https://github.com/corneliusweig/konfig] plugin.
```
kubectl krew install konfig
kubectl konfig import -s <path-to-downloaded-kubeconfig>
kubectl config use-context <cluster-context-name>
```
## Install TKG Extensions 
### Download and Unpack the Tanzu Kubernetes Grid Extensions Bundle 1.3.1
*Documentation: https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.3/vmware-tanzu-kubernetes-grid-13/GUID-extensions-index.html#download-and-unpack-the-tanzu-kubernetes-grid-extensions-bundle-2*

Unpack the extensions archive in the root of this project(e.g. extensions/tkg-extensions-v1.3.1+vmware.1/...).

Set the folowing env variable to this directory for the scripts.
```
export TKG_EXTENSIONS_FOLDER_NAME=tkg-extensions-v1.3.1+vmware.1
```

### Install kapp-controller
The Tanzu Kubernetes Grid extensions use kapp-controller to configure and install these packages on a Kubernetes cluster. On a TMC provisioned cluster on AWS kapp-controller is not preinstalled.
```
./scripts/setup-kapp-controller.sh
```

### Install cert-manager, contour, and external-dns via TKG extensions
*Documentation: https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.3/vmware-tanzu-kubernetes-grid-13/GUID-extensions-index.html#install-cert-manager-on-workload-clusters-3, https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.3/vmware-tanzu-kubernetes-grid-13/GUID-extensions-ingress-contour.html, https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.3/vmware-tanzu-kubernetes-grid-13/GUID-extensions-external-dns.html*

The setup requires a DNS zones to be able to create Let's Encrypt certificates and DNS entries to mitigate challenges with e.g. TBS and Harbor. The scripts support Route53 and GCloud DNS, but you can use any provider that is supported by cert-manager, and external-dns. 
If you don't have a domain you can use for it, ask your colleagues. 

It's recommended to have a look at the following script and overlays before you run it (and maybe run every of the commands manually). The *-data-values.yaml files in the overlays sub folders are modified copies of the templates in the tkg extensions bundle.
```
./scripts/setup-ingress-and-service-discovery.sh
watch kubectl get apps -A
```
Wait until the descriptions equal "Reconcile succeeded".

**Known Issues:** 
- Due to some Contour issues related to HTTP2 with Safari, HTTP2 is disabled via the overlays/contour/contour-data-values.yaml configuration. https://projectcontour.io/resources/faq/#q-when-i-load-my-site-in-safari-it-shows-me-an-empty-page-developer-tools-show-that-the-http-response-was-421-why-does-this-happen

*Documentation for the deletion of extension if something goes wrong during the installation and you want to retry: https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.3/vmware-tanzu-kubernetes-grid-13/GUID-extensions-delete-extensions.html*

### Configure TLS Certificate Delegation
The script configures TLS certificate delegation ("\*.cnr.<your-ingress-domain>") and all other installed products("\*.<your-ingress-domain>") and requests the wildcard certs for them. 
```
./scripts/setup-tls-certificate-delegation.sh
```

**Known Issues:** 
- TLSCertificateDelegation does not work with networking.k8s.io/v1 Ingress, use networking.k8s.io/v1beta1 instead. https://github.com/projectcontour/contour/issues/3544

### Install Harbor via TKG extension
*Documentation: https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.3/vmware-tanzu-kubernetes-grid-13/GUID-extensions-harbor-registry.html*

It's recommended to have a look at the following script and overlays before you run it (and maybe run every of the commands manually).
The setup script will run a script that is part of the TKG extensions to generate required passwords. The generate password script requires jq. Install it e.g. with `snap install yq`.

```
./scripts/setup-harbor.sh
watch kubectl get apps -A
```
Wait until the description equals "Reconcile succeeded".

**Known Issues:** 
Due to the large size of the TBS container images:
- The default value for the Ingress and HTTPProxs response timeout is 15 secs. This causes issues with the large buildpack images of TBS. In our setup it will be set to 60s via an overlay.
- There might be performance issues if for example the environment is using spinning disks instead of SSDs due to the size of the container images for the buildpacks (503 Service Unavailable). 
- Ensure that all worker nodes have at least 50 GB of ephemeral storage allocated to them.

### Install Tanzu Build Service 1.2
*Documentation: https://docs.pivotal.io/build-service/1-2/installing.html*

Ensure that all worker nodes have at least 50 GB of ephemeral storage allocated to them.

### Download the kp CLI from the [Tanzu Build Service page](https://network.tanzu.vmware.com/products/build-service/) of Tanzu Network.

As an alternative to the download via browser, you can download the files via the [pivnet cli](https://github.com/pivotal-cf/pivnet-cli/releases).
```
wget https://github.com/pivotal-cf/pivnet-cli/releases/download/v3.0.1/pivnet-linux-amd64-3.0.1
chmod +x pivnet-linux-amd64-3.0.1
sudo mv pivnet-linux-amd64-3.0.1 /usr/local/bin/pivnet
pivnet login --api-token='<my-api-token>'
```
The api token you need for the login can be fetched from the ["Edit Profile page"](https://network.tanzu.vmware.com/users/dashboard/edit-profile) of the Tanzu Network after you logged in.

To see the command to download a resource from Tanzu Network click on the info icon.
```
pivnet download-product-files --product-slug='build-service' --release-version='1.2.2' --product-file-id=1000629
chmod +x kp-linux-0.3.1
sudo mv kp-linux-0.3.1 /usr/local/bin/kp
```
### Installation

There is a known issue with TBS 1.2 if docker is installed with snap: https://docs.pivotal.io/build-service/1-2/faq.html#faq-17
```
sudo cp snap/docker/796/.docker/config.json ~/.docker/config.json
sudo chown "$USER":"$USER" /home/"$USER"/.docker -R
sudo chmod g+rwx "/home/$USER/.docker" -R
```
It's recommended to have a look at the following script and overlays before you run it (and maybe run every of the commands manually).
```
./scripts/setup-tbs.sh
```
**Known Issues:** 
- See "Known Issues" for Harbor

## Install Cloud Native Runtimes for VMware Tanzu
*Documentation: https://docs.vmware.com/en/Cloud-Native-Runtimes-for-VMware-Tanzu/1.0/tanzu-cloud-native-runtimes-1-0/GUID-cnr-overview.html* 
Download the CNR from the [CNR page](https://network.tanzu.vmware.com/products/serverless/) of Tanzu Network.
As an alternative to the download via browser, you can download the files via the [pivnet cli](https://github.com/pivotal-cf/pivnet-cli/releases).

To see the command to download the resource from Tanzu Network click on the info icon.
```
pivnet download-product-files --product-slug='serverless' --release-version='1.0.1+build.58' --product-file-id=1007924
```

Unpack the archive.
```
tar -xvf cloud-native-runtimes-1.0.1.tgz
```

Run the script for the installation.
```
./scripts/setup-cnr.sh
```

See "Configure TLS Certificate Delegation" for the CNR configured TLS certificate delegation and certificate request.

After you installed CNR, you have to edit the following Kubernetes objects.
```
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

## Configure Tanzu Observability by Wavefront and Tanzu Service Mesh via TMC Integrations
*Documentation: https://docs.vmware.com/en/VMware-Tanzu-Mission-Control/services/tanzumc-using/GUID-0AAC9FB2-AC45-4E38-AA1C-FB99A9960FAF.html, https://docs.vmware.com/en/VMware-Tanzu-Mission-Control/services/tanzumc-using/GUID-5B1445AB-EFEB-41BD-B9B3-6DD38E69991F.html*

## Misc

### Inject imagePullSecrets for Docker Hub rate limiting.
```
kubectl create secret docker-registry docker-hub-creds \
  --docker-server=docker.io \
  --docker-username=$DOCKER_HUB_USER \
  --docker-password=$DOCKER_HUB_PASSWORD \
  --docker-email=$DOCKER_HUB_EMAIL \
  -n <namespace>
kubectl get sa -n <namespace>
kubectl patch serviceaccount <service-account> -p '{"imagePullSecrets": [{"name": "docker-hub-creds"}]}' -n <namespace>
```

### Debug commands
```
kubectl run -it --rm --restart=Never busybox --image=harbor-repo.vmware.com/dockerhub-proxy-cache/library/busybox sh
kubectl get pods -A | grep -v Completed | grep -v Running
```