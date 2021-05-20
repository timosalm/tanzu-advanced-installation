# Grafana Extension

## Prerequisites

* Workload cluster deployed.
* ytt installed (<https://github.com/k14s/ytt/releases>)
* kapp installed (<https://github.com/k14s/kapp/releases>)
* Customize storage resource limit on vCenter (only for TKGS)

    1. Login to vCenter and go for Namespaces -> Configure -> Resource Limits

    2. Click on Edit and increase the resource limit for storage to desired value, which needs to be larger than Grafana persistent volume claim size

### Deploy grafana extension

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

4. Create grafana namespace

    ```sh
    kubectl apply -f namespace-role.yaml
    ```

5. Copy `grafana-data-values.yaml.example` to `grafana-data-values.yaml`

   Configure grafana data values in `grafana-data-values.yaml`

   Supported configurations are documented in [grafana-configurations](../../../monitoring/grafana/README.md)

6. Create a secret with data values

    ```sh
    kubectl create secret generic grafana-data-values --from-file=values.yaml=grafana-data-values.yaml -n tanzu-system-monitoring
    ```

7. Deploy grafana extension

    ```sh
    kubectl apply -f grafana-extension.yaml
    ```

8. Retrieve status of an extension

    ```sh
    kubectl get extension grafana -n tanzu-system-monitoring
    kubectl get app grafana -n tanzu-system-monitoring
    ```

   Grafana app status should change to `Reconcile Succeeded` once grafana is deployed successfully

   View detailed status

    ```sh
    kubectl get app grafana -n tanzu-system-monitoring -o yaml
    ```

### Update grafana extension

1. Get grafana data values from secret

    ```sh
    kubectl get secret grafana-data-values -n tanzu-system-monitoring -o 'go-template={{ index .data "values.yaml" }}' | base64 -d > grafana-data-values.yaml
    ```

2. Update grafana data values in grafana-data-values.yaml

3. Update grafana data values secret

    ```sh
    kubectl create secret generic grafana-data-values --from-file=values.yaml=grafana-data-values.yaml -n tanzu-system-monitoring -o yaml --dry-run | kubectl replace -f-
    ```

   Grafana extension will be reconciled again with the above data values

   **NOTE:**
   By default, kapp-controller will sync apps every 5 minutes. So, the update should take effect in <= 5 minutes.
   If you want the update to take effect immediately, change syncPeriod in `grafana-extension.yaml` to a lesser value
   and apply grafana extension `kubectl apply -f grafana-extension.yaml`.

4. Refer to `Retrieve status of an extension` in [deploy grafana extension](#deploy-grafana-extension) to retrieve the status of an extension

### Delete grafana extension

1. Delete grafana extension

    ```sh
    kubectl delete -f grafana-extension.yaml
    kubectl delete app grafana -n tanzu-system-monitoring
    ```

2. Refer to `Retrieve status of an extension` in [deploy grafana extension](#deploy-grafana-extension) to retrieve the status of an extension

   If extension is deleted successfully, then get of both grafana extension and app should return `Not Found`

3. Delete grafana namespace

   **NOTE: Do not delete namespace-role.yaml before app is deleted fully, as it will lead to errors due to service account used by kapp-controller being deleted**

    ```sh
    kubectl delete -f namespace-role.yaml
    ```

### Upgrade grafana deployment to grafana extension

1. Get grafana configmap

    ```sh
    kubectl get configmap grafana -n tanzu-system-monitoring -o 'go-template={{ index .data "grafana.yaml" }}' > grafana-configmap.yaml
    ```

2. Delete existing grafana deployment

    ```sh
    kubectl delete namespace tanzu-system-monitoring
    ```

3. Follow steps in [Deploy grafana extension](#deploy-grafana-extension) to deploy grafana extension

### Test template rendering

1. Test if grafana templates are rendered correctly

    ```sh
    ytt --ignore-unknown-comments -f ../../../common -f ../../../monitoring/grafana -f grafana-data-values.yaml
    ```

### Use your own certificate

* If you have certificates at hand, you don't have to install cert-manager at the beginning.

#### Generate a certificate authority certificate

* In a production environment, you should obtain a certificate from a CA.
* In a test or PoC environment, you can generate your own self signed certificate. To generate a CA certficate, run the following commands.

1. Generate a CA certificate private key.

    ```sh
    openssl genrsa -out ca.key 4096
    ```

2. Generate the CA certificate.

   Update the values in the -subj option per your need.
   If you use an FQDN to connect your Grafana host, you must specify it as the common name (CN) attribute.

    ```sh
    openssl req -x509 -new -nodes -sha512 -days 3650 \
     -subj "/C=US/ST=PA/L=PA/O=example/OU=Personal/CN=grafana.system.tanzu" \
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
   If you use an FQDN to connect your Grafana host, you must specify it as the common name (CN) attribute and use it in the key and CSR filenames.

    ```sh
    openssl req -sha512 -new \
        -subj "/C=US/ST=PA/L=PA/O=example/OU=Personal/CN=grafana.system.tanzu" \
        -key tls.key \
        -out tls.csr
    ```

3. Generate an x509 v3 extension file.

   Create this file so that you can generate a certificate for your Grafana host that complies with the Subject Alternative Name (SAN) and x509 v3 extension requirements.

    ```sh
    cat > v3.ext <<-EOF
    authorityKeyIdentifier=keyid,issuer
    basicConstraints=CA:FALSE
    keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
    extendedKeyUsage = serverAuth
    subjectAltName = @alt_names

    [alt_names]
    DNS.1=grafana.system.tanzu
    EOF
    ```

4. Use the v3.ext file to generate a certificate for your Grafana host.

    ```sh
    openssl x509 -req -sha512 -days 3650 \
    -extfile v3.ext \
    -CA ca.crt -CAkey ca.key -CAcreateserial \
    -in tls.csr \
    -out tls.crt
    ```

5. Copy the content of files ca.crt tls.crt and tls.key into grafana-data-values.yaml as the following format

    ```sh
    ingress:
      tlsCertificate:
        tls.crt: |
            -----BEGIN ...
    ```

6. Deploy Grafana extension, same as this doc starting from step 4.
