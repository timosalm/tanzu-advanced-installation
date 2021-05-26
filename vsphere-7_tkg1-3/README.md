# Unofficial Tanzu Advanced PoC guide for TKG 1.3 on vSphere 7

It's always recommended to go through the official documentation in addition to this guide!
The scripts and commands in this guide were executed on a Linux jumpbox.
The scripts are based on the amazing work done for TKG 1.1 [here](https://github.com/tanzu-end-to-end/clusters).

The setup requires a DNS zones to be able to create Let's Encrypt certificates and DNS entries to mitigate challenges with e.g. TBS and Harbor. The scripts support Route53 and GCloud DNS, but you can use any provider that is supported by cert-manager, and external-dns. 
If you don't have a domain you can use for it, ask your colleagues. 

## Environment 
The installation was tested with the following environments:
- PEZ IaaS Only - vSphere (7.0 U2)

## TKG-m 1.3 on vSphere 7

### Download and install the Tanzu CLI and kubectl
*Documentation: https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.3/vmware-tanzu-kubernetes-grid-13/GUID-install-cli.html#download-and-unpack-the-tanzu-cli-and-kubectl-1*

*PEZHint: Because you have to download the artifacts via the browser, with a PEZ env you can use the Windows jump box and transfer them via WinSCP to the unix jumpbox.*

#### Upack and install the tools
```
tar -xvf tanzu-cli-bundle-linux-amd64.tar
gunzip kubectl-linux-v1.20.4-vmware.1.gz
cd cli
sudo install core/v1.3.0/tanzu-core-linux_amd64 /usr/local/bin/tanzu
cd ..
tanzu plugin install --local cli all
tanzu plugin list
mv kubectl-linux-v1.20.4-vmware.1 kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl
```
*Documentation: https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.3/vmware-tanzu-kubernetes-grid-13/GUID-extensions-index.html#install-carvel*
```
cd cli
gunzip *.gz
chmod +x imgpkg-linux-amd64-v0.2.0+vmware.1 kapp-linux-amd64-v0.33.0+vmware.1 kbld-linux-amd64-v0.24.0+vmware.1 ytt-linux-amd64-v0.30.0+vmware.1
sudo mv imgpkg-linux-amd64-v0.2.0+vmware.1 /usr/local/bin/imgpkg
sudo mv kapp-linux-amd64-v0.33.0+vmware.1  /usr/local/bin/kapp
sudo mv kbld-linux-amd64-v0.24.0+vmware.1 /usr/local/bin/kbld
sudo mv ytt-linux-amd64-v0.30.0+vmware.1 /usr/local/bin/ytt
```
### Prerequisites
####  Required Permissions for the vSphere Account
*Documentation: https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.3/vmware-tanzu-kubernetes-grid-13/GUID-mgmt-clusters-vsphere.html#vsphere-permissions*

#### Import the Base Image Template into vSphere
*Documentation: https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.3/vmware-tanzu-kubernetes-grid-13/GUID-mgmt-clusters-vsphere.html#import-base*
*PEZHint: Because you have to download the artifacts via the browser, with a PEZ env you can use the Windows jump box and transfer them via WinSCP to the unix jumpbox.*

**Known Issues:** 
- There is a bug with Photon v3 Kubernetes v1.20.4 OVA image(photon-3-kube-v1.20.4-vmware.1-tkg.0-2326554155028348692.ova) and kube-vip, use the Ubuntu image instead! 

#### Create an SSH Key Pair to be able to connect to the node VMs
*Documentation: https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.3/vmware-tanzu-kubernetes-grid-13/GUID-mgmt-clusters-vsphere.html#create-an-ssh-key-pair-6*
```
ssh-keygen -t rsa -b 4096 -C "emea-end-to-end@vmware.com"
```
Path e.g. ~/tkg/ssh-keys/id_rsa

#### Create Persistent Volumes with Storage Classes
*Documentation: https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.3/vmware-tanzu-kubernetes-grid-13/GUID-tanzu-k8s-clusters-storage.html#create-policy*
*PEZHint: Go through the steps for Local VMFS Storage*

#### Install VMware NSX Advanced Load Balancer on a vSphere Distributed Switch
*Documentation: https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.3/vmware-tanzu-kubernetes-grid-13/GUID-mgmt-clusters-install-nsx-adv-lb.html*
- Use DHCP Network (e.g. Extra on PEZ) if available
- Configure default cloud and use ip instead of dns name for vcenter if hostname doesn't work (e.g. nslookup vcsa-01.haas-421.pez.vmware.com)
- Set the DNS if you are e.g. on PEZ so the hostname can be resolved
- Set VIPs for your Subnet

Troubleshoot service type LoadBalancer via incoming traffic on Kubernets nodes:
```
tcpdump -i eth0 port 30038 # see incoming requests
iptables -L
ip addr
ss -ltmp # see ports listening
ss -ltm
``` 

#### Copy values-example.yaml to values.yaml and set configuration values
- The values that are already set as an example are based on a specific PEZ environment - change them for your environment if necessary
- Select a static ip for the control planes enpoints that are not in the DHCP Range.
- To register your managment cluster with TMC follow the instructions [here](https://docs.vmware.com/en/VMware-Tanzu-Mission-Control/services/tanzumc-using/GUID-EB507AAF-5F4F-400F-9623-BA611233E0BD.html) and configure the URL provided on the register page in the values.yaml
### Create Management Cluster and Workload Cluster
*Documentation: https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.3/vmware-tanzu-kubernetes-grid-13/GUID-mgmt-clusters-deploy-cli.html, https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.3/vmware-tanzu-kubernetes-grid-13/GUID-tanzu-k8s-clusters-vsphere.html*

It's recommended to have a look at the following script before you run it (and maybe run every of the commands manually)
```
./scripts/pre-reqs.sh
```
If you change something in the configuration, after you ran the script, dont't forget to delete the relevant file in the "generated" 
folder!

To debug the installation, you can run the following command. You have to change the suffix of the config file to the auto generated value!
```
kubectl get po,deploy,cluster,kubeadmcontrolplane,machine,machinedeployment -A --kubeconfig /home/ubuntu/.kube-tkg/tmp/config_xxx
```

### Get Workload Cluster credentials and set the context
*Documentation: https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.3/vmware-tanzu-kubernetes-grid-13/GUID-cluster-lifecycle-connect.html#retrieve-tanzu-kubernetes-cluster-kubeconfig-2*
```
tanzu cluster kubeconfig get <workload-cluster-name> --admin
kubectl config use-context <workload-cluster-name>-admin@<workload-cluster-name>
```

### Download and Unpack the Tanzu Kubernetes Grid Extensions Bundle 1.3
*Documentation: https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.3/vmware-tanzu-kubernetes-grid-13/GUID-extensions-index.html?hWord=N4IghgNiBcIMYFMBOAXAtAWzAOzAc2RAF8g#download-and-unpack-the-tanzu-kubernetes-grid-extensions-bundle-2*

Unpack the extensions archive in the root of this project(extensions/tkg-extensions-v1.3.0/...).

### Install cert-manager, contour, and external-dns via TKG extensions
*Documentation: https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.3/vmware-tanzu-kubernetes-grid-13/GUID-extensions-index.html?hWord=N4IghgNiBcIMYFMBOAXAtAWzAOzAc2RAF8g#installing-extension-prerequisite-components-to-a-cluster-4, https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.3/vmware-tanzu-kubernetes-grid-13/GUID-extensions-ingress-contour.html, https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.3/vmware-tanzu-kubernetes-grid-13/GUID-extensions-external-dns.html*

The setup requires a DNS zones to be able to create Let's Encrypt certificates and DNS entries to mitigate challenges with e.g. TBS and Harbor. The scripts support Route53 and GCloud DNS, but you can use any provider that is supported by cert-manager, and external-dns. 
If you don't have a domain you can use for it, ask your colleagues. 

It's recommended to have a look at the following script and overlays before you run it (and maybe run every of the commands manually). The *-data-values.yaml files in the overlays sub folders are modified copies of the templates in the tkg extensions bundle.
```
./scripts/setup-ingress-and-service-discovery.sh
```
**Known Issues:** 
- Due to some Contour issues related to HTTP2 with Safari, HTTP2 is disabled via the overlays/contour/contour-data-values.yaml configuration. https://projectcontour.io/resources/faq/#q-when-i-load-my-site-in-safari-it-shows-me-an-empty-page-developer-tools-show-that-the-http-response-was-421-why-does-this-happen

*Documentation for the deletion of extension if something goes wrong during the installation and you want to retry: https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.3/vmware-tanzu-kubernetes-grid-13/GUID-extensions-delete-extensions.html*

### Configure TLS Certificate Delegation
```
./scripts/setup-tls-certificate-delegation.sh
```

**Known Issues:** 
- TLSCertificateDelegation does not work with networking.k8s.io/v1 Ingress, use networking.k8s.io/v1beta1 instead. https://github.com/projectcontour/contour/issues/3544

### Install Harbor via TKG extension
It's recommended to have a look at the following script and overlays before you run it (and maybe run every of the commands manually).
The setup script will run a script that is part of the TKG extensions to generate required passwords. The generate password script requires jq version <=3. Install it e.g. with `snap install yq --channel=v3/stable`.

```
./scripts/setup-harbor.sh
```

**Known Issues:** 
Due to the large size of the TBS container images:
- The default value for the Ingress and HTTPProxs response timeout is 15 secs. This causes issues with the large buildpack images of TBS. In our setup it will be set to 60s via an overlay.
- There might be performance issues if for example the environment is using spinning disks instead of SSDs due to the size of the container images for the buildpacks (503 Service Unavailable). 
- Ensure that all worker nodes have at least 50 GB of ephemeral storage allocated to them.

### Install Tanzu Build Service 1.1
*Documentation: https://docs.pivotal.io/build-service/1-1/installing.html*

Ensure that all worker nodes have at least 50 GB of ephemeral storage allocated to them.

Download the Build Service Bundle and kp CLI from the [Tanzu Build Service page](https://network.tanzu.vmware.com/products/build-service/) and the descriptor-<version>.yaml file from the [Tanzu Build Service Dependencies](https://network.tanzu.vmware.com/products/tbs-dependencies/) of Tanzu Network.

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
# kp cli
pivnet download-product-files --product-slug='build-service' --release-version='1.1.4' --product-file-id=883031
chmod +x kp-linux-0.2.0
sudo mv kp-linux-0.2.0 /usr/local/bin/kp

# TBS bundle
pivnet download-product-files --product-slug='build-service' --release-version='1.1.4' --product-file-id=904252 --download-dir=tbs/

# descriptor-100.0.103.yaml
pivnet download-product-files --product-slug='tbs-dependencies' --release-version='100.0.103' --product-file-id=954775 --download-dir=tbs/
```

It's recommended to have a look at the following script and overlays before you run it (and maybe run every of the commands manually).
```
docker login registry.pivotal.io
./scripts/setup-tbs.sh tbs/build-service-1.1.4.tar tbs/descriptor-100.0.102.yaml
```
**Known Issues:** 
- See "Known Issues" for Harbor
- There is a bug in containerd 1.4.1(TKGm 1.2.1) that makes it incompatible with TBS.

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