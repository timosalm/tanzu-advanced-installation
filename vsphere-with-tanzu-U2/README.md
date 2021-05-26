# Unofficial Tanzu Advanced PoC guide for vSphere with Tanzu U2

It's always recommended to go through the official documentation in addition to this guide!
The scripts and commands in this guide were executed on a Linux jumpbox.
The scripts are based on the amazing work done for TKG 1.1 [here](https://github.com/tanzu-end-to-end/clusters).

The setup requires a DNS zones to be able to create Let's Encrypt certificates and DNS entries to mitigate challenges with e.g. TBS and Harbor. The scripts support Route53 and GCloud DNS, but you can use any provider that is supported by cert-manager, and external-dns. 
If you don't have a domain you can use for it, ask your colleagues. 

## Environment 
The installation was tested with the following environments:
- PEZ TKGs - vSphere with Kubernetes 7.0 U2 (Nested env with 3 virtual ESX hypervisors on one host). We had performance issues with TBS and Harbor, so the **external network zone** for the environment and a **SSD disk** are recommended!

## vSphere with Tanzu U2

### Create and configure a Supervisor namespace
*Documentation: https://docs.vmware.com/en/VMware-vSphere/7.0/vmware-vsphere-with-tanzu/GUID-177C23C4-ED81-4ADD-89A2-61654C18201B.html*
1. Go to Menu > Workload Management > Namespaces > NEW NAMESPACE
2. Name your namespace and select a cluster
3. Assign a Storage Policy to the namespace (e.g. for PEZ pacific-gold-storage-policy)

### Download and install the Kubernetes CLI Tools for vSphere
*Documentation: https://docs.vmware.com/en/VMware-vSphere/7.0/vmware-vsphere-with-kubernetes/GUID-0F6E45C4-3CB1-4562-9370-686668519FCA.html?hWord=N4IghgNiBcINYFcBGBTAxgFygXyA*

*PEZHint: Because you have to download the artifacts via the browser, with a PEZ env you can use the Windows jump box and transfer them via WinSCP to the unix jumpbox.*
```
unzip vsphere-plugin.zip
chmod +x bin/kubectl bin/kubectl-vsphere
sudo mv bin/* /usr/local/bin/
```

### Download and install the carvel tools
*Documentation: https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.3/vmware-tanzu-kubernetes-grid-13/GUID-install-cli.html#download-and-unpack-the-tanzu-cli-and-kubectl-1*, https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.3/vmware-tanzu-kubernetes-grid-13/GUID-extensions-index.html#install-carvel*

The easiest way to get all the carvel tools is to download them bundled with the Tanzu CLI.
```
cd cli
gunzip *.gz
chmod +x imgpkg-linux-amd64-v0.2.0+vmware.1 kapp-linux-amd64-v0.33.0+vmware.1 kbld-linux-amd64-v0.24.0+vmware.1 ytt-linux-amd64-v0.30.0+vmware.1
sudo mv imgpkg-linux-amd64-v0.2.0+vmware.1 /usr/local/bin/imgpkg
sudo mv kapp-linux-amd64-v0.33.0+vmware.1  /usr/local/bin/kapp
sudo mv kbld-linux-amd64-v0.24.0+vmware.1 /usr/local/bin/kbld
sudo mv ytt-linux-amd64-v0.30.0+vmware.1 /usr/local/bin/ytt
```

### Copy values-example.yaml to values.yaml and set configuration values
- The values that are already set as an example are based on a specific PEZ environment - change them for your environment if necessary
- The Storage Policy should be same you assigned in the step "Create and configure a Supervisor namespace"

### Login to supervisor cluster namespace
*Documentation: https://docs.vmware.com/en/VMware-vSphere/7.0/vmware-vsphere-with-tanzu/GUID-F5114388-1838-4B3B-8A8D-4AE17F33526A.html*

```
kubectl vsphere login --server wcp.haas-xxx.pez.vmware.com --insecure-skip-tls-verify -u administrator@vsphere.local
kubectl config use-context <your-supervisor-namespace>
```

### Create workload cluster
*Documentation: https://docs.vmware.com/en/VMware-vSphere/7.0/vmware-vsphere-with-tanzu/GUID-2597788E-2FA4-420E-B9BA-9423F8F7FD9F.html*

It's recommended to have a look at the following script and Kubernetes resource file before you execute the command.
```
./scripts/setup-cluster.sh
wait kubectl get tkc
```
Wait until the cluster phase equals "running".

To debug the installation, you can run the following command. You have to change the suffix of the config file to the auto generated value!
```
kubectl get po,deploy,cluster,kubeadmcontrolplane,machine,machinedeployment -A
```

**Known Issues:** 
- If you select the extra large and/or guaranteed VM classes, there may be issues with resource utilization (on PEZ).

### Get Workload Cluster credentials and set the context
*Documentation: https://docs.vmware.com/en/VMware-vSphere/7.0/vmware-vsphere-with-tanzu/GUID-AA3CA6DC-D4EE-47C3-94D9-53D680E43B60.html*
```
kubectl vsphere login --tanzu-kubernetes-cluster-name <your-workload-cluster-name> --server wcp.haas-xxx.pez.vmware.com --insecure-skip-tls-verify -u administrator@vsphere.local
kubectl config use-context <your-workload-cluster-name>
```

### Download and Unpack the Tanzu Kubernetes Grid Extensions Bundle 1.3
*Documentation: https://docs.vmware.com/en/VMware-vSphere/7.0/vmware-vsphere-with-tanzu/GUID-23D2EADA-199D-4A00-9296-4DA83B399FEC.html*

Unpack the extensions archive in the root of this project(extensions/tkg-extensions-v1.3.0/...).

**Known Issues:** 
- Tanzu Kubernetes Grid (TKG) 1.3.0 extensions do not function on Tanzu Kubernetes Grid Service clusters when attached to Tanzu Mission Control (TMC): https://kb.vmware.com/s/article/83322

### Install cert-manager, contour, and external-dns via TKG extensions
*Documentation: https://docs.vmware.com/en/VMware-vSphere/7.0/vmware-vsphere-with-tanzu/GUID-36C7D7CB-312F-49B6-B542-1D0DBC550198.html, https://docs.vmware.com/en/VMware-vSphere/7.0/vmware-vsphere-with-tanzu/GUID-F5A2E647-A45F-4C63-BFD4-74F61C141BFE.html*

The setup requires a DNS zones to be able to create Let's Encrypt certificates and DNS entries to mitigate challenges with e.g. TBS and Harbor. The scripts support Route53 and GCloud DNS, but you can use any provider that is supported by cert-manager, and external-dns. 
If you don't have a domain you can use for it, ask your colleagues. 

It's recommended to have a look at the following script and overlays before you run it (and maybe run every of the commands manually). The *-data-values.yaml files in the overlays sub folders are modified copies of the templates in the tkg extensions bundle.
```
./scripts/setup-ingress-and-service-discovery.sh
```
**Known Issues:** 
- *Fixed via ytt overlay* Due to some Contour issues related to HTTP2 with Safari, HTTP2 is disabled via the overlays/contour/contour-data-values.yaml configuration. https://projectcontour.io/resources/faq/#q-when-i-load-my-site-in-safari-it-shows-me-an-empty-page-developer-tools-show-that-the-http-response-was-421-why-does-this-happen

*Documentation for the deletion of extension if something goes wrong during the installation and you want to retry: https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.3/vmware-tanzu-kubernetes-grid-13/GUID-extensions-delete-extensions.html*

### Configure TLS Certificate Delegation
```
./scripts/setup-tls-certificate-delegation.sh
```

**Known Issues:** 
- TLSCertificateDelegation does not work with networking.k8s.io/v1 Ingress, use networking.k8s.io/v1beta1 instead. https://github.com/projectcontour/contour/issues/3544

### Install Harbor
It's recommended to have a look at the following script and overlays before you run it (and maybe run every of the commands manually).

#### Via TKG extension which may not be supported
The setup script will run a script that is part of the TKG extensions to generate required passwords. The generate password script requires jq version <=3. Install it e.g. with `snap install yq --channel=v3/stable`.

```
./scripts/setup-harbor.sh
```

#### Via Helm chart
```
./scripts/setup-harbor-helm.sh
```

**Known Issues:** 
Due to the large size of the TBS container images:
- *Fixed via ytt overlay* The default value for the Ingress and HTTPProxs response timeout is 15 secs. This causes issues with the large buildpack images of TBS. In our setup it will be set to 60s via an overlay.
- There might be performance issues if for example the environment is using spinning disks instead of SSDs due to the size of the container images for the buildpacks (503 Service Unavailable). 
- *Fixed via cluster configuration* Ensure that all worker nodes have at least 50 GB of ephemeral storage allocated to them. To do this on TKGs, mount a 50GB volume at /var/lib to the worker nodes in the TanzuKubernetesCluster resource that corresponds to your TKGs cluster. [These](https://docs.vmware.com/en/VMware-vSphere/7.0/vmware-vsphere-with-tanzu/GUID-4E68C7F2-C948-489A-A909-C7A1F3DC545F.html) instructions show how to configure storage on worker nodes.

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
- *Fixed via TKG 1.3* There is a bug in containerd 1.4.1(TKGm 1.2.1) that makes it incompatible with TBS.
- *Fixed via scripts* `forbidden: PodSecurityPolicy: unable to admit pod: []`. In this case we just assign the privilged psp role to anything that is authenticated.

### (Otional) Install GitLab
```
./scripts/setup-gitlab.sh
```

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