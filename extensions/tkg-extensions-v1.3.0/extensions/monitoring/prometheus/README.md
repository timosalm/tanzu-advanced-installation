# Prometheus Extension

## Prerequisites

* Workload cluster deployed.
* ytt installed (<https://github.com/k14s/ytt/releases>)
* kapp installed (<https://github.com/k14s/kapp/releases>)
* Customize storage resource limit on vCenter (Only for TKGS)

    1. Login to vCenter and go for Namespaces -> Configure -> Resource Limits

    2. Click on Edit and increase the resource limit for Storage to desired value, which needs to be larger than Prometheus persistent volume claim size

### Deploy prometheus extension

1. Install TMC's extension manager

    ```sh
    kubectl apply -f tmc-extension-manager.yaml
    ```

2. Install kapp-controller

   This step is to be performed only for TKGS. For TKGm, kapp-controller is installed on the workload cluster by default.

    ```sh
    kubectl apply -f kapp-controller.yaml
    ```

3. Deploy cert-manager if its not already installed

    ```sh
    kubectl apply -f ../../../cert-manager/
    ```

4. Create prometheus namespace

    ```sh
    kubectl apply -f namespace-role.yaml
    ```

5. Copy `prometheus-data-values.yaml.example` to `prometheus-data-values.yaml`

   Configure prometheus data values in `prometheus-data-values.yaml`

   Supported configurations are documented in [prometheus-configurations](../../../monitoring/prometheus/README.md)

6. Create a secret with data values

    ```sh
    kubectl create secret generic prometheus-data-values --from-file=values.yaml=prometheus-data-values.yaml -n tanzu-system-monitoring
    ```

7. Deploy prometheus extension

    ```sh
    kubectl apply -f prometheus-extension.yaml
    ```

8. Retrieve status of an extension

    ```sh
    kubectl get extension prometheus -n tanzu-system-monitoring
    kubectl get app prometheus -n tanzu-system-monitoring
    ```

   Prometheus app status should change to `Reconcile Succeeded` once prometheus is deployed successfully

   View detailed status

    ```sh
    kubectl get app prometheus -n tanzu-system-monitoring -o yaml
    ```

### Update prometheus extension

1. Get prometheus data values from secret

    ```sh
    kubectl get secret prometheus-data-values -n tanzu-system-monitoring -o 'go-template={{ index .data "values.yaml" }}' | base64 -d > prometheus-data-values.yaml
    ```

2. Update prometheus data values in prometheus-data-values.yaml

3. Update prometheus data values secret

    ```sh
    kubectl create secret generic prometheus-data-values --from-file=values.yaml=prometheus-data-values.yaml -n tanzu-system-monitoring -o yaml --dry-run | kubectl replace -f-
    ```

   Prometheus extension will be reconciled again with the above data values

   **NOTE:**
   By default, kapp-controller will sync apps every 5 minutes. So, the update should take effect in <= 5 minutes.
   If you want the update to take effect immediately, change syncPeriod in `prometheus-extension.yaml` to a lesser value
   and apply prometheus extension `kubectl apply -f prometheus-extension.yaml`.

4. Refer to `Retrieve status of an extension` in [deploy prometheus extension](#deploy-prometheus-extension) to retrieve the status of an extension

### Delete prometheus extension

1. Delete prometheus extension

    ```sh
    kubectl delete -f prometheus-extension.yaml
    kubectl delete app prometheus -n tanzu-system-monitoring
    ```

2. Refer to `Retrieve status of an extension` in [deploy prometheus extension](#deploy-prometheus-extension) to retrieve the status of an extension

   If extension is deleted successfully, then get of both prometheus extension and app should return `Not Found`

3. Delete prometheus namespace

   **NOTE: Do not delete namespace-role.yaml before app is deleted fully, as it will lead to errors due to service account used by kapp-controller being deleted**

    ```sh
    kubectl delete -f namespace-role.yaml
    ```

### Upgrade prometheus deployment to prometheus extension

1. Get prometheus configmap

    ```sh
    kubectl get configmap prometheus -n tanzu-system-monitoring -o 'go-template={{ index .data "prometheus.yaml" }}' > prometheus-configmap.yaml
    ```

2. Delete existing prometheus deployment

    ```sh
    kubectl delete namespace tanzu-system-monitoring
    ```

3. Follow steps in [Deploy prometheus extension](#deploy-prometheus-extension) to deploy prometheus extension

### Test template rendering

1. Test if prometheus templates are rendered correctly

    ```sh
    ytt --ignore-unknown-comments -f ../../../common -f ../../../monitoring/prometheus -f prometheus-data-values.yaml
    ```

### Use your own certificate

* If you have certificates at hand, you don't have to install cert-manager at the beginning.

#### Generate a certificate authority certificate

* In a production environment, you should obtain a certificate from a CA.
* In a test or POC environment, you can generate your own self signed certificate. To generate a CA certficate, run the following commands.

1. Generate a CA certificate private key.

    ```sh
    openssl genrsa -out ca.key 4096
    ```

2. Generate the CA certificate.

   Update the values in the -subj option per your need.
   If you use an FQDN to connect your Prometheus host, you must specify it as the common name (CN) attribute.

    ```sh
    openssl req -x509 -new -nodes -sha512 -days 3650 \
     -subj "/C=US/ST=PA/L=PA/O=example/OU=Personal/CN=prometheus.system.tanzu" \
     -key ca.key \
     -out ca.crt
    ```

#### Generate a server certificate

* The certificate usually contains a .crt file and a .key file, for example, tls.crt and tls.key

1. Generate a private key

    ```sh
    openssl genrsa -out tls.key 4096
    ```

2. Generate a certificate signing request (CSR).

   Update the values in the -subj option per your need.
   If you use an FQDN to connect your Prometheus host, you must specify it as the common name (CN) attribute and use it in the key and CSR filenames.

    ```sh
    openssl req -sha512 -new \
        -subj "/C=US/ST=PA/L=PA/O=example/OU=Personal/CN=prometheus.system.tanzu" \
        -key tls.key \
        -out tls.csr
    ```

3. Generate an x509 v3 extension file.

   Create this file so that you can generate a certificate for your Prometheus host that complies with the Subject Alternative Name (SAN) and x509 v3 extension requirements.

    ```sh
    cat > v3.ext <<-EOF
    authorityKeyIdentifier=keyid,issuer
    basicConstraints=CA:FALSE
    keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
    extendedKeyUsage = serverAuth
    subjectAltName = @alt_names

    [alt_names]
    DNS.1=prometheus.system.tanzu
    EOF
    ```

4. Use the v3.ext file to generate a certificate for your Prometheus host.

    ```sh
    openssl x509 -req -sha512 -days 3650 \
    -extfile v3.ext \
    -CA ca.crt -CAkey ca.key -CAcreateserial \
    -in tls.csr \
    -out tls.crt
    ```

5. Copy the content of files ca.crt tls.crt and tls.key into prometheus-data-values.yaml as the following format

    ```sh
    ingress:
      enabled: true
      virtual_host_fqdn: "prometheus.system.tanzu"
      tlsCertificate:
        tls.crt: |
            -----BEGIN ...
    ```

6. Deploy Prometheus extension, same as this doc starting from step 4.
